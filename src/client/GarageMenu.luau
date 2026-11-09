--!strict
-- Garage: a 3x3 grid of tanks (columns = class, rows = tier) and a detail panel for the
-- highlighted tank with its stats, upgrades and a Select / Buy button. Opens on join and
-- when your tank is destroyed; C toggles it. The server validates every purchase and
-- decides whether a switch happens now or at your next respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local MouseLock = require(script.Parent.MouseLock)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(script.Parent.ProfileClient)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankClass = require(ReplicatedStorage.Shared.TankClass)
local TankController = require(script.Parent.TankController)

type Data = PlayerDataTypes.Data

local GarageMenu = {}

local TILE_W, TILE_H, GAP = 150, 74, 10
local GRID_W = TILE_W * 3 + GAP * 2
local PANEL_W = 340
local BODY_H = 340
local GOLD = Color3.fromRGB(255, 215, 90)
local PANEL_COLOR = Color3.fromRGB(28, 30, 42)
local MUTED = Color3.fromRGB(150, 155, 175)
local BAR_COLOR = Color3.fromRGB(120, 200, 255)
local UPGRADE_COLOR = Color3.fromRGB(130, 230, 140)
local BUTTON_COLOR = Color3.fromRGB(70, 150, 255)
local DISABLED_COLOR = Color3.fromRGB(70, 74, 96)

local localPlayer = Players.LocalPlayer

type Stat = { label: string, value: (TankClass.Spec) -> number }

local STATS: { Stat } = {
	{
		label = "Armor",
		value = function(spec)
			return spec.MaxHealth / spec.FrontArmor -- effective front HP
		end,
	},
	{
		label = "Speed",
		value = function(spec)
			return spec.MaxForwardSpeed
		end,
	},
	{
		label = "Damage",
		value = function(spec)
			return spec.Damage
		end,
	},
	{
		label = "Reload",
		value = function(spec)
			return 1 / spec.Cooldown
		end,
	},
}

-- Bars scale against the best fully-upgraded tank, so upgrades visibly grow them.
local statBest: { number } = {}
do
	local maxed: PlayerDataTypes.UpgradeLevels = { Gun = Config.Upgrades.MaxLevel, Armor = Config.Upgrades.MaxLevel, Engine = Config.Upgrades.MaxLevel }
	for row, stat in STATS do
		local best = 0
		for _, id in TankCatalog.order do
			best = math.max(best, stat.value(TankCatalog.spec(id, maxed)))
		end
		statBest[row] = best
	end
end

-- UI construction --------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Garage"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Enabled = false

local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.64) -- below the round/death banners
root.Size = UDim2.fromOffset(GRID_W + GAP * 2 + PANEL_W, BODY_H + 80)
root.BackgroundTransparency = 1
root.Parent = gui

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, value: string, size: number, position: UDim2, dims: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Position = position
	label.Size = dims
	label.Text = value
	label.Parent = parent
	return label
end

local function button(parent: Instance, position: UDim2, dims: UDim2, textSize: number): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Font = Enum.Font.FredokaOne
	b.TextSize = textSize
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = BUTTON_COLOR
	b.Position = position
	b.Size = dims
	b.Parent = parent
	corner(b, 8)
	return b
end

local title = text(root, "GARAGE", 32, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 36))
local status = text(root, "", 18, UDim2.new(0, 0, 1, -26), UDim2.new(1, 0, 0, 24))

-- Grid
local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Position = UDim2.fromOffset(0, 46)
grid.Size = UDim2.fromOffset(GRID_W, BODY_H)
grid.Parent = root

for col, className in TankClass.order do
	local header = text(grid, string.upper(TankClass.get(className).DisplayName), 18, UDim2.fromOffset((col - 1) * (TILE_W + GAP), 0), UDim2.fromOffset(TILE_W, 22))
	header.TextColor3 = MUTED
end

type Tile = { button: TextButton, stroke: UIStroke, name: TextLabel, info: TextLabel }
local tiles: { [string]: Tile } = {}

for _, id in TankCatalog.order do
	local def = TankCatalog.get(id)
	local col = table.find(TankClass.order, def.Class) or 1
	local tile = Instance.new("TextButton")
	tile.Name = id
	tile.AutoButtonColor = false
	tile.Text = ""
	tile.BackgroundColor3 = PANEL_COLOR
	tile.BackgroundTransparency = 0.1
	tile.Position = UDim2.fromOffset((col - 1) * (TILE_W + GAP), 28 + (def.Tier - 1) * (TILE_H + GAP))
	tile.Size = UDim2.fromOffset(TILE_W, TILE_H)
	tile.Parent = grid
	corner(tile, 10)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = tile
	local name = text(tile, def.DisplayName, 22, UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 26))
	local info = text(tile, "", 15, UDim2.fromOffset(0, 40), UDim2.new(1, 0, 0, 22))
	tiles[id] = { button = tile, stroke = stroke, name = name, info = info }
end

-- Detail panel
local panel = Instance.new("Frame")
panel.BackgroundColor3 = PANEL_COLOR
panel.BackgroundTransparency = 0.1
panel.Position = UDim2.fromOffset(GRID_W + GAP * 2, 46)
panel.Size = UDim2.fromOffset(PANEL_W, BODY_H)
panel.Parent = root
corner(panel, 12)

local detailName = text(panel, "", 26, UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 30))
local detailRole = text(panel, "", 14, UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 20))
detailRole.TextColor3 = MUTED

type Bar = { base: Frame, upgraded: Frame }
local bars: { Bar } = {}
for row, stat in STATS do
	local y = 66 + (row - 1) * 30
	local label = text(panel, stat.label, 15, UDim2.fromOffset(14, y), UDim2.fromOffset(70, 16))
	label.TextXAlignment = Enum.TextXAlignment.Left
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(84, y + 4)
	track.Size = UDim2.new(1, -98, 0, 9)
	track.BackgroundColor3 = Color3.fromRGB(55, 58, 76)
	track.BorderSizePixel = 0
	track.Parent = panel
	corner(track, 5)
	-- The upgraded bar sits under the base bar, so the upgrade gain shows in green.
	local upgraded = Instance.new("Frame")
	upgraded.BackgroundColor3 = UPGRADE_COLOR
	upgraded.BorderSizePixel = 0
	upgraded.Parent = track
	corner(upgraded, 5)
	local base = Instance.new("Frame")
	base.BackgroundColor3 = BAR_COLOR
	base.BorderSizePixel = 0
	base.ZIndex = 2
	base.Parent = track
	corner(base, 5)
	bars[row] = { base = base, upgraded = upgraded }
end

type UpgradeRow = { label: TextLabel, buy: TextButton }
local upgradeRows: { [string]: UpgradeRow } = {}
for index, track in TankCatalog.trackOrder do
	local y = 186 + (index - 1) * 34
	local label = text(panel, "", 16, UDim2.fromOffset(14, y), UDim2.fromOffset(190, 28))
	label.TextXAlignment = Enum.TextXAlignment.Left
	local buy = button(panel, UDim2.new(1, -124, 0, y), UDim2.fromOffset(110, 28), 15)
	upgradeRows[track] = { label = label, buy = buy }
end

local mainButton = button(panel, UDim2.new(0, 14, 1, -42), UDim2.new(1, -28, 0, 32), 20)

-- State and rendering -----------------------------------------------------------

local focused: string = Config.DefaultTank -- tank shown in the detail panel
local autoOpened = false
local lastTank: TankController.TankRefs? = nil
local busy = false

local function pips(level: number): string
	return string.rep("●", level) .. string.rep("○", Config.Upgrades.MaxLevel - level)
end

local function hint(): string
	local phase = ReplicatedStorage:GetAttribute(RoundSchema.PhaseAttribute)
	return if phase == "Active"
		then "Changes apply now if your tank hasn't fired or been hit; otherwise on respawn.   [C] close"
		else "Changes apply now (not in a round).   [C] close"
end

local function render()
	local data = ProfileClient.get()
	if not data then
		status.Text = "Loading your garage..."
		return
	end
	if not busy and not status.Text:find("^Can't") then
		status.Text = hint()
	end
	local level = Progression.levelForXP(data.XP)
	title.Text = `GARAGE    Level {level}  ·  {data.Coins} coins`

	for id, tile in tiles do
		local def = TankCatalog.get(id)
		local owned = data.OwnedTanks[id] == true
		local unlockLevel = Progression.levelForTier(def.Tier)
		local selected = data.SelectedTank == id
		if selected then
			tile.info.Text = "DRIVING"
			tile.info.TextColor3 = GOLD
		elseif owned then
			tile.info.Text = "Owned"
			tile.info.TextColor3 = UPGRADE_COLOR
		elseif level < unlockLevel then
			tile.info.Text = `Level {unlockLevel}`
			tile.info.TextColor3 = MUTED
		else
			tile.info.Text = `{def.Cost} coins`
			tile.info.TextColor3 = if data.Coins >= def.Cost then GOLD else MUTED
		end
		tile.name.TextTransparency = if owned or level >= unlockLevel then 0 else 0.4
		tile.stroke.Color = if id == focused then Color3.new(1, 1, 1) elseif selected then GOLD else DISABLED_COLOR
		tile.stroke.Thickness = if id == focused then 4 else 2
	end

	local def = TankCatalog.get(focused)
	local owned = data.OwnedTanks[focused] == true
	local levels = TankCatalog.noUpgrades()
	local saved = data.Upgrades[focused]
	if saved then
		for _, track in TankCatalog.trackOrder do
			(levels :: any)[track] = (saved :: any)[track] or 0
		end
	end
	local base = TankCatalog.spec(focused, nil)
	local current = TankCatalog.spec(focused, levels)
	detailName.Text = `{string.upper(def.DisplayName)}  {string.rep("★", def.Tier)}`
	detailRole.Text = `{TankClass.get(def.Class).DisplayName} · {base.Role}`
	for row, stat in STATS do
		bars[row].base.Size = UDim2.fromScale(math.min(stat.value(base) / statBest[row], 1), 1)
		bars[row].upgraded.Size = UDim2.fromScale(math.min(stat.value(current) / statBest[row], 1), 1)
	end

	for _, track in TankCatalog.trackOrder do
		local row = upgradeRows[track]
		local trackLevel = (levels :: any)[track] :: number
		local cost = Progression.upgradeCost(focused, trackLevel)
		row.label.Text = `{TankCatalog.trackName(track)}  {pips(trackLevel)}`
		if not owned then
			row.buy.Text = "—"
			row.buy.BackgroundColor3 = DISABLED_COLOR
		elseif cost then
			row.buy.Text = `{cost} coins`
			row.buy.BackgroundColor3 = if data.Coins >= cost then BUTTON_COLOR else DISABLED_COLOR
		else
			row.buy.Text = "MAX"
			row.buy.BackgroundColor3 = DISABLED_COLOR
		end
	end

	local unlockLevel = Progression.levelForTier(def.Tier)
	if data.SelectedTank == focused then
		mainButton.Text = "Driving"
		mainButton.BackgroundColor3 = DISABLED_COLOR
	elseif owned then
		mainButton.Text = "Drive this tank"
		mainButton.BackgroundColor3 = BUTTON_COLOR
	elseif level < unlockLevel then
		mainButton.Text = `Unlocks at level {unlockLevel}`
		mainButton.BackgroundColor3 = DISABLED_COLOR
	else
		mainButton.Text = `Buy for {def.Cost} coins`
		mainButton.BackgroundColor3 = if data.Coins >= def.Cost then GOLD else DISABLED_COLOR
	end
end

local function open(auto: boolean)
	autoOpened = auto
	local data = ProfileClient.get()
	if data then
		focused = data.SelectedTank
	end
	gui.Enabled = true
	MouseLock.setReleased(true)
	status.Text = hint()
	render()
end

local function close()
	autoOpened = false
	gui.Enabled = false
	MouseLock.setReleased(false)
end

local function request(action: string, track: string?)
	if busy then
		return
	end
	busy = true
	local ok, message = Remotes.GarageRequest:InvokeServer(action, focused, track)
	busy = false
	status.Text = if ok then hint() else `Can't do that: {message or "unknown error"}`
	-- Picking a tank while alive sends you back to the fight.
	if ok and action == "Select" and TankController.getTank() then
		close()
	end
end

for id, tile in tiles do
	tile.button.Activated:Connect(function()
		focused = id
		render()
	end)
end
for track, row in upgradeRows do
	row.buy.Activated:Connect(function()
		request("Upgrade", track)
	end)
end
mainButton.Activated:Connect(function()
	local data = ProfileClient.get()
	if not data then
		return
	end
	if data.OwnedTanks[focused] then
		if data.SelectedTank ~= focused then
			request("Select")
		end
	else
		request("Buy")
	end
end)

-- Open when the tank is lost; close an auto-opened garage when a new tank arrives.
local function watchTank()
	local tank = TankController.getTank()
	if tank == lastTank then
		return
	end
	lastTank = tank
	if tank then
		if autoOpened then
			close()
		end
	elseif not gui.Enabled then
		open(true)
	end
end

function GarageMenu.start()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local firstSync = true
	ProfileClient.changed:Connect(function(data: Data)
		if firstSync then
			firstSync = false
			focused = data.SelectedTank
			status.Text = hint()
		end
		if gui.Enabled then
			render()
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			if gui.Enabled then
				close()
			else
				open(false)
			end
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(RoundSchema.PhaseAttribute):Connect(function()
		if gui.Enabled then
			status.Text = hint()
		end
	end)
	RunService.RenderStepped:Connect(watchTank)
	-- First join: open the garage (manual open, so it stays until you choose or press C).
	open(false)
end

return GarageMenu
