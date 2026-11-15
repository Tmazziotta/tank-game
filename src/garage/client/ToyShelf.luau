--!strict
-- Toy Shelf (interim, until the toy-line tech tree in M10): a 3x3 grid of tanks (columns =
-- class, rows = tier) and a detail panel for the highlighted tank with its stats, upgrades
-- and a Drive / Buy button. Driving a tank outside your loadout swaps it into the selected
-- slot. Lives inside the lobby HUD's Toy Shelf tab; the server (Hangar) validates
-- everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankClass = require(ReplicatedStorage.Shared.TankClass)

type Data = PlayerDataTypes.Data

local ToyShelf = {}

local TILE_W, TILE_H, GAP = 150, 74, 10
local GRID_W = TILE_W * 3 + GAP * 2
local PANEL_W = 360
local BODY_H = 372
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

-- Bars scale against the best tank with every stat mod on, so mods visibly grow them.
local statBest: { number } = {}
do
	local maxed: { string } = {}
	for _, row in Config.Mods.CommonRows do
		for _, modId in row do
			table.insert(maxed, modId)
		end
	end
	for row, stat in STATS do
		local best = 0
		for _, id in TankCatalog.order do
			best = math.max(best, stat.value(TankCatalog.spec(id, maxed)))
		end
		statBest[row] = best
	end
end

-- UI construction --------------------------------------------------------------

local root = Instance.new("Frame")
root.Name = "ToyShelf"
root.AnchorPoint = Vector2.new(0.5, 0)
root.Position = UDim2.fromScale(0.5, 0)
root.Size = UDim2.fromOffset(GRID_W + GAP * 2 + PANEL_W, BODY_H + 74)
root.BackgroundTransparency = 1
local fitScale = Instance.new("UIScale") -- shrinks the shelf to fit short (phone) screens
fitScale.Parent = root

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

-- Labels drawn straight on the lobby's cream sheet use its dark-brown ink.
local INK = Color3.fromHex("#3B2414")
local INK_SOFT = Color3.fromHex("#8A6A52")
local function ink(label: TextLabel, color: Color3)
	label.TextColor3 = color
	label.TextStrokeTransparency = 1
end
ink(text(root, "TOY SHELF", 32, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 36)), INK)
local status = text(root, "", 18, UDim2.new(0, 0, 1, -26), UDim2.new(1, 0, 0, 24))
ink(status, INK_SOFT)

-- Line tabs: which toy line's tanks the grid shows.
local lineTabs: { [string]: TextButton } = {}
for index, line in TankCatalog.lineOrder do
	local tab = button(root, UDim2.fromOffset((index - 1) * (TILE_W + GAP), 40), UDim2.fromOffset(TILE_W, 26), 15)
	tab.Name = `Line{line}`
	tab.Text = TankCatalog.line(line).DisplayName
	lineTabs[line] = tab
end

-- Grid: the shown line's tree (columns = class, rows = tier).
local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Position = UDim2.fromOffset(0, 72)
grid.Size = UDim2.fromOffset(GRID_W, BODY_H)
grid.Parent = root

for col, className in TankClass.order do
	local header = text(grid, string.upper(TankClass.get(className).DisplayName), 18, UDim2.fromOffset((col - 1) * (TILE_W + GAP), 0), UDim2.fromOffset(TILE_W, 22))
	ink(header, INK_SOFT)
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
panel.Position = UDim2.fromOffset(GRID_W + GAP * 2, 40)
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

-- Mod tree: one row per tree row, two mods each. Tap a locked mod to unlock it (tank XP),
-- an unlocked one to equip it.
type ModButton = { button: TextButton, modId: string }
local modButtons: { { ModButton } } = {}
for row = 1, Config.Mods.Rows do
	local y = 186 + (row - 1) * 36
	local pair = {}
	for slot = 1, 2 do
		local b = button(panel, UDim2.new(0, 14 + (slot - 1) * 170, 0, y), UDim2.fromOffset(162, 30), 13)
		b.TextWrapped = true
		pair[slot] = { button = b, modId = "" }
	end
	modButtons[row] = pair
end

local mainButton = button(panel, UDim2.new(0, 14, 1, -42), UDim2.new(1, -28, 0, 32), 20)

-- State and rendering -----------------------------------------------------------

local focused: string = Config.DefaultTank -- tank shown in the detail panel
local busy = false

local shownLine: string = TankCatalog.lineOrder[1]

local function hint(): string
	return "Tap a mod to unlock or equip it. Driving a tank puts it in your loadout."
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
	for line, tab in lineTabs do
		tab.BackgroundColor3 = if line == shownLine then TankCatalog.line(line).Color else DISABLED_COLOR
	end
	for id, tile in tiles do
		local def = TankCatalog.get(id)
		tile.button.Visible = def.Line == shownLine
		local owned = data.OwnedTanks[id] == true
		local canBuy, reason = Progression.canBuy(data, id)
		local selected = data.SelectedTank == id
		if selected then
			tile.info.Text = "DRIVING"
			tile.info.TextColor3 = GOLD
		elseif owned and Progression.isElite(data, id) then
			tile.info.Text = "★ Elite"
			tile.info.TextColor3 = GOLD
		elseif owned and table.find(data.Loadout, id) then
			tile.info.Text = "In loadout"
			tile.info.TextColor3 = UPGRADE_COLOR
		elseif owned then
			tile.info.Text = "Owned"
			tile.info.TextColor3 = Color3.new(1, 1, 1)
		elseif canBuy or reason == "Not enough coins" then
			tile.info.Text = `{Progression.tankCost(id)} coins`
			tile.info.TextColor3 = if canBuy then GOLD else MUTED
		else
			tile.info.Text = "Locked"
			tile.info.TextColor3 = MUTED
		end
		tile.name.TextTransparency = if owned or canBuy then 0 else 0.4
		tile.stroke.Color = if id == focused then Color3.new(1, 1, 1) elseif selected then GOLD else DISABLED_COLOR
		tile.stroke.Thickness = if id == focused then 4 else 2
	end

	local def = TankCatalog.get(focused)
	local owned = data.OwnedTanks[focused] == true
	local equipped = Progression.equipped(data, focused)
	local base = TankCatalog.spec(focused, nil)
	local current = TankCatalog.spec(focused, equipped)
	detailName.Text = `{string.upper(def.DisplayName)}  {string.rep("★", def.Tier)}`
	detailRole.Text = if owned
		then `{TankClass.get(def.Class).DisplayName} · {Progression.tankXP(data, focused)} tank XP`
		else `{TankClass.get(def.Class).DisplayName} · {TankCatalog.line(def.Line).DisplayName}`
	for row, stat in STATS do
		bars[row].base.Size = UDim2.fromScale(math.min(stat.value(base) / statBest[row], 1), 1)
		bars[row].upgraded.Size = UDim2.fromScale(math.min(stat.value(current) / statBest[row], 1), 1)
	end

	for row, entry in TankCatalog.modRows(focused) do
		for slot, modId in entry do
			local mb = modButtons[row][slot]
			mb.modId = modId
			local name = TankCatalog.mod(modId).DisplayName
			local canUnlock, _, cost = Progression.canUnlockMod(data, focused, modId)
			if table.find(equipped, modId) then
				mb.button.Text = `✔ {name}`
				mb.button.BackgroundColor3 = GOLD
			elseif Progression.isUnlocked(data, focused, modId) then
				mb.button.Text = name
				mb.button.BackgroundColor3 = BUTTON_COLOR
			else
				mb.button.Text = `{name} · {cost} XP`
				mb.button.BackgroundColor3 = if canUnlock then UPGRADE_COLOR else DISABLED_COLOR
			end
		end
	end

	if data.SelectedTank == focused then
		mainButton.Text = "Driving"
		mainButton.BackgroundColor3 = DISABLED_COLOR
	elseif owned then
		mainButton.Text = "Drive this tank"
		mainButton.BackgroundColor3 = BUTTON_COLOR
	else
		local canBuy, reason = Progression.canBuy(data, focused)
		mainButton.Text = if canBuy or reason == "Not enough coins" then `Buy for {Progression.tankCost(focused)} coins` else reason or "Locked"
		mainButton.BackgroundColor3 = if canBuy then GOLD else DISABLED_COLOR
	end
end

local function request(action: string, extra: string?)
	if busy then
		return
	end
	busy = true
	local ok, message = Remotes.GarageRequest:InvokeServer(action, focused, extra)
	busy = false
	status.Text = if ok then hint() else `Can't do that: {message or "unknown error"}`
	render()

end

for id, tile in tiles do
	tile.button.Activated:Connect(function()
		focused = id
		render()
	end)
end
for line, tab in lineTabs do
	tab.Activated:Connect(function()
		shownLine = line
		local data = ProfileClient.get()
		focused = if data and data.OwnedTanks[data.SelectedTank] and TankCatalog.get(data.SelectedTank).Line == line
			then data.SelectedTank
			else TankCatalog.starterOf(line)
		render()
	end)
end
for _, pair in modButtons do
	for _, mb in pair do
		mb.button.Activated:Connect(function()
			local data = ProfileClient.get()
			if not data or mb.modId == "" then
				return
			end
			local mod = TankCatalog.mod(mb.modId)
			status.Text = `{mod.DisplayName}: {mod.Blurb}`
			if Progression.isUnlocked(data, focused, mb.modId) then
				request("EquipMod", mb.modId)
			else
				request("UnlockMod", mb.modId)
			end
		end)
	end
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

-- Show the shelf inside `parent` (the Toy Shelf tab), focused on the driven tank.
-- Shrink (never grow) the shelf so it fits inside its parent.
local function fit()
	local parent = root.Parent
	if not parent or not parent:IsA("GuiObject") or fitScale.Scale <= 0 then
		return
	end
	local natural = root.AbsoluteSize / fitScale.Scale
	if natural.X > 0 and natural.Y > 0 then
		fitScale.Scale = math.min(1, parent.AbsoluteSize.X / natural.X, parent.AbsoluteSize.Y / natural.Y)
	end
end
local fitConnection: RBXScriptConnection? = nil

function ToyShelf.mount(parent: GuiObject)
	if root.Parent ~= parent then
		if fitConnection then
			fitConnection:Disconnect()
		end
		fitConnection = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	end
	local data = ProfileClient.get()
	if data and data.SelectedTank ~= "" then
		focused = data.SelectedTank
		shownLine = TankCatalog.get(focused).Line
	end
	root.Parent = parent
	status.Text = hint()
	render()
	task.defer(fit) -- after the layout updates
end

function ToyShelf.start()
	ProfileClient.changed:Connect(function(_data: Data)
		if root.Parent then
			render()
		end
	end)
end

return ToyShelf
