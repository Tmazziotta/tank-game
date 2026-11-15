--!strict
-- Counter-pick menu: a 3x3 grid of tanks (columns = class, rows = tier) and a detail panel
-- for the highlighted tank with its stats. In a match you can only swap between your
-- loadout tanks of the match tier (buying and upgrading happen in the Garage). Opens by
-- itself for each pre-round countdown and closes when the round starts; C toggles it any
-- time. The server (Hangar) validates the swap and decides whether it happens now or at
-- your next respawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MatchGate = require(script.Parent.MatchGate)
local Config = require(ReplicatedStorage.Shared.Config)
local MouseLock = require(script.Parent.MouseLock)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local TouchInput = require(script.Parent.TouchInput)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankClass = require(ReplicatedStorage.Shared.TankClass)

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

local title = text(root, "SWAP TANK", 32, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 36))
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
local busy = false

local function pips(level: number): string
	return string.rep("●", level) .. string.rep("○", Config.Upgrades.MaxLevel - level)
end

local function closeHint(): string
	return if TouchInput.isTouchDevice() then "Tap SWAP to close" else "[C] close"
end

local function hint(): string
	local phase = ReplicatedStorage:GetAttribute(RoundSchema.PhaseAttribute)
	return if phase == "PreRound" or phase == "Waiting"
		then `Changes apply now.   {closeHint()}`
		else `Changes apply next round.   {closeHint()}`
end

local function matchTier(): number
	local value = ReplicatedStorage:GetAttribute(RoundSchema.MatchTierAttribute)
	return if type(value) == "number" then value else 0
end

-- Loadout tanks of the match tier can be swapped in.
local function swappable(data: Data, id: string): boolean
	local tier = matchTier()
	return table.find(data.Loadout, id) ~= nil and (tier == 0 or TankCatalog.get(id).Tier == tier)
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
	local tier = matchTier()
	title.Text = if tier > 0 then `SWAP TANK    Tier {tier} match` else "SWAP TANK"

	for id, tile in tiles do
		local def = TankCatalog.get(id)
		local selected = data.SelectedTank == id
		local inLoadout = table.find(data.Loadout, id) ~= nil
		local usable = swappable(data, id)
		if selected then
			tile.info.Text = "DRIVING"
			tile.info.TextColor3 = GOLD
		elseif usable then
			tile.info.Text = "Swap in"
			tile.info.TextColor3 = UPGRADE_COLOR
		elseif inLoadout then
			tile.info.Text = `Tier {def.Tier}`
			tile.info.TextColor3 = MUTED
		else
			tile.info.Text = "Not in loadout"
			tile.info.TextColor3 = MUTED
		end
		tile.name.TextTransparency = if selected or usable then 0 else 0.5
		tile.stroke.Color = if id == focused then Color3.new(1, 1, 1) elseif selected then GOLD else DISABLED_COLOR
		tile.stroke.Thickness = if id == focused then 4 else 2
	end

	local def = TankCatalog.get(focused)
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
		row.label.Text = `{TankCatalog.trackName(track)}  {pips(trackLevel)}`
		row.buy.Visible = false -- upgrades are bought in the Garage
	end

	if data.SelectedTank == focused then
		mainButton.Text = "Driving"
		mainButton.BackgroundColor3 = DISABLED_COLOR
	elseif swappable(data, focused) then
		mainButton.Text = "Drive this tank"
		mainButton.BackgroundColor3 = BUTTON_COLOR
	elseif table.find(data.Loadout, focused) then
		mainButton.Text = `Not this match's tier`
		mainButton.BackgroundColor3 = DISABLED_COLOR
	else
		mainButton.Text = "Not in your loadout"
		mainButton.BackgroundColor3 = DISABLED_COLOR
	end
end

local function open(auto: boolean)
	if not MatchGate.inMatch() then
		return
	end
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

end

for id, tile in tiles do
	tile.button.Activated:Connect(function()
		focused = id
		render()
	end)
end
mainButton.Activated:Connect(function()
	local data = ProfileClient.get()
	if data and data.SelectedTank ~= focused and swappable(data, focused) then
		request("Select")
	end
end)

-- Auto-open for the pre-round countdown; close (if we opened it) when the round starts.
local function onPhase()
	local phase = ReplicatedStorage:GetAttribute(RoundSchema.PhaseAttribute)
	if phase == "PreRound" then
		if not gui.Enabled then
			open(true)
		end
	elseif autoOpened then
		close()
	end
	if gui.Enabled then
		status.Text = hint()
	end
end

-- Open or close the swap menu (C key, or the touch SWAP button).
function GarageMenu.toggle()
	if gui.Enabled then
		close()
	else
		open(false)
	end
end

function GarageMenu.isOpen(): boolean
	return gui.Enabled
end

function GarageMenu.start()
	MatchGate.mount(gui)
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
			GarageMenu.toggle()
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(RoundSchema.PhaseAttribute):Connect(onPhase)
	MatchGate.changed:Connect(function(inMatch: boolean)
		if inMatch then
			onPhase()
		elseif gui.Enabled then
			close()
		end
	end)
	onPhase()
end

return GarageMenu
