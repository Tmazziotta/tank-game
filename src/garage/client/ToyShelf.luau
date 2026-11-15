--!strict
-- Toy Shelf (tech tree): one shelf per toy line, tanks as boxed toys laid out as the line's
-- tree (tier 1 on top, branching to the tier 2 light / medium / heavy, each leading down to
-- its tier 3). The detail panel shows the highlighted tank in 3D with its stats and what it
-- takes to get it; buying plays the box-opening animation. Rules live in Progression; the
-- server (Hangar) validates everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Requests = require(script.Parent.Requests)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankClass = require(ReplicatedStorage.Shared.TankClass)
local TankPreview = require(script.Parent.TankPreview)
local TankStats = require(script.Parent.TankStats)
local Toy = require(script.Parent.Toy)
local UnboxFx = require(script.Parent.UnboxFx)

type Data = PlayerDataTypes.Data

local ToyShelf = {}

local NATURAL = Vector2.new(960, 430)
local TREE_TOP = 66
local BOX_W, BOX_H = 170, 86
local COL_X = { 10, 195, 380 } -- left edge of the Light / Medium / Heavy columns
local ROW_Y = { 0, 130, 254 } -- top of tier 1 / 2 / 3 boxes (inside the tree)
local LINE_T = 5 -- connector thickness
local DETAIL_X, DETAIL_W = 586, 374

type Box = { button: Toy.Button, lid: Frame, name: TextLabel, status: TextLabel }

type Detail = {
	name: TextLabel,
	lineChip: Frame,
	classChip: Frame,
	tierChip: Frame,
	preview: TankPreview.Preview,
	pips: { { Frame } },
	status: TextLabel,
	action: Toy.Button,
	mods: Toy.Button,
}

local root: Frame? = nil
local unboxHost: Instance? = nil
local detail: Detail? = nil
local boxes: { [string]: Box } = {}
local lineTabs: { [string]: Toy.Button } = {}
local trees: { [string]: Frame } = {}
local shownLine = TankCatalog.lineOrder[1]
local focused = Config.DefaultTank
local openToolbox: (tankId: string) -> () = function(_tankId: string) end

local function chipLabel(chip: Frame): TextLabel
	return chip:FindFirstChild("Label") :: TextLabel
end

-- Status line on a box, and whether it reads as available.
local function boxStatus(data: Data, id: string): (string, boolean)
	if data.SelectedTank == id then
		return "DRIVING", true
	end
	if data.OwnedTanks[id] then
		return if Progression.isElite(data, id) then "★ Elite" else "Owned", true
	end
	local canBuy, reason = Progression.canBuy(data, id)
	if canBuy or reason == "Not enough coins" then
		return `{Progression.tankCost(id)} coins`, true
	end
	return "🔒 Locked", false
end

local function renderBoxes(data: Data)
	for line, tab in lineTabs do
		local on = line == shownLine
		tab.face.BackgroundColor3 = if on then TankCatalog.line(line).Color else Toy.Cream
		tab.label.TextColor3 = if on then Color3.new(1, 1, 1) else Toy.Brown
	end
	for line, tree in trees do
		tree.Visible = line == shownLine
	end
	for id, box in boxes do
		local text, available = boxStatus(data, id)
		box.status.Text = text
		box.status.TextColor3 = if data.SelectedTank == id then Toy.Green elseif available then Toy.Brown else Toy.BrownSoft
		box.name.TextColor3 = if available then Toy.Brown else Toy.BrownSoft
		box.lid.BackgroundColor3 = if available then TankCatalog.line(TankCatalog.get(id).Line).Color else Toy.Grey
		box.button.face.BackgroundColor3 = if available then Toy.Cream else Toy.CreamDark
		box.button.stroke.Color = if id == focused then Toy.Yellow else Toy.Brown
		box.button.stroke.Thickness = if id == focused then 6 else Toy.Outline
	end
end

local function renderDetail(data: Data)
	local d = detail
	if not d then
		return
	end
	local id = focused
	local def = TankCatalog.get(id)
	local line = TankCatalog.line(def.Line)
	local owned = data.OwnedTanks[id] == true
	local equipped = if owned then Progression.equipped(data, id) else {}
	d.name.Text = def.DisplayName
	chipLabel(d.lineChip).Text = line.DisplayName
	d.lineChip.BackgroundColor3 = line.Color
	chipLabel(d.classChip).Text = TankClass.get(def.Class).DisplayName
	chipLabel(d.tierChip).Text = `Tier {Toy.tier(def.Tier)}`
	d.preview.show(id, equipped)
	for index, lit in TankStats.pips(id, equipped) do
		Toy.setPips(d.pips[index], lit)
	end

	d.mods.holder.Visible = owned
	d.action.holder.Size = UDim2.new(1, if owned then -62 else 0, 0, 52 + Toy.Shadow)
	if data.SelectedTank == id then
		d.status.Text = if Progression.isElite(data, id)
			then "★ Elite: its next tanks are unlocked."
			else `{Progression.tankXP(data, id)} tank XP · mod rows {Progression.rowsDone(data, id)} / {Config.Mods.Rows}`
		d.action.label.Text = "Driving"
		d.action.face.BackgroundColor3 = Toy.Grey
	elseif owned then
		d.status.Text = `{Progression.tankXP(data, id)} tank XP · mod rows {Progression.rowsDone(data, id)} / {Config.Mods.Rows}`
		d.action.label.Text = "Drive"
		d.action.face.BackgroundColor3 = Toy.Yellow
	else
		local canBuy, reason = Progression.canBuy(data, id)
		local cost = Progression.tankCost(id)
		d.status.Text = if canBuy then "Ready to unbox!" else reason or "Locked"
		d.action.label.Text = if canBuy or reason == "Not enough coins" then `Buy · {cost} coins` else "🔒 Locked"
		d.action.face.BackgroundColor3 = if canBuy then Toy.Yellow else Toy.Grey
	end
end

local function render()
	local data = ProfileClient.get()
	if data and root then
		renderBoxes(data)
		renderDetail(data)
	end
end

local function focus(id: string)
	focused = id
	shownLine = TankCatalog.get(id).Line
	render()
end

local function onAction()
	local data = ProfileClient.get()
	if not data then
		return
	end
	local id = focused
	if data.OwnedTanks[id] then
		if data.SelectedTank ~= id then
			Requests.send("Select", id)
		end
	elseif Requests.send("Buy", id) and unboxHost then
		UnboxFx.play(unboxHost, id)
	end
end

-- Build ------------------------------------------------------------------------------

local function connector(parent: Instance, x: number, y: number, w: number, h: number)
	local bar = Toy.frame(parent, UDim2.fromOffset(x, y), UDim2.fromOffset(w, h), Toy.BrownSoft)
	Toy.corner(bar, 2)
end

local function buildTree(parent: Instance, line: string): Frame
	local tree = Toy.frame(parent, UDim2.fromOffset(0, TREE_TOP), UDim2.fromOffset(DETAIL_X - 16, NATURAL.Y - TREE_TOP))
	tree.Name = `Tree{line}`
	local function center(col: number): number
		return COL_X[col] + BOX_W / 2
	end
	-- Connectors: tier 1 down to a bar spanning the classes, down into each tier 2, and
	-- each tier 2 down to its tier 3.
	local barY = ROW_Y[1] + BOX_H + (ROW_Y[2] - ROW_Y[1] - BOX_H) / 2
	connector(tree, center(2) - LINE_T / 2, ROW_Y[1] + BOX_H, LINE_T, barY - ROW_Y[1] - BOX_H)
	connector(tree, center(1), barY, center(3) - center(1), LINE_T)
	for col = 1, 3 do
		connector(tree, center(col) - LINE_T / 2, barY, LINE_T, ROW_Y[2] - barY)
		connector(tree, center(col) - LINE_T / 2, ROW_Y[2] + BOX_H, LINE_T, ROW_Y[3] - ROW_Y[2] - BOX_H)
	end

	for _, id in TankCatalog.ofLine(line) do
		local def = TankCatalog.get(id)
		-- The starter sits centered over the branches.
		local col = if def.Parent then table.find(TankClass.order, def.Class) or 1 else 2
		local b = Toy.button(tree, "", 18, UDim2.fromOffset(COL_X[col], ROW_Y[def.Tier] or 0), UDim2.fromOffset(BOX_W, BOX_H + Toy.Shadow), Toy.Cream, 12)
		b.holder.Name = id
		local lid = Toy.frame(b.face, UDim2.new(), UDim2.new(1, 0, 0, 16), Toy.Grey)
		Toy.corner(lid, 12)
		lid.ZIndex = 3
		local name = Toy.text(b.face, def.DisplayName, 22, UDim2.fromOffset(10, 20), UDim2.new(1, -50, 0, 30))
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.ZIndex = 3
		local status = Toy.text(b.face, "", 16, UDim2.fromOffset(10, 52), UDim2.new(1, -20, 0, 22))
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.ZIndex = 3
		local tier = Toy.text(b.face, Toy.tier(def.Tier), 16, UDim2.new(1, -38, 0, 22), UDim2.fromOffset(30, 24))
		tier.BackgroundColor3 = Toy.YellowLight
		tier.BackgroundTransparency = 0
		tier.ZIndex = 3
		Toy.corner(tier, 8)
		Toy.outline(tier, 2)
		boxes[id] = { button = b, lid = lid, name = name, status = status }
		b.button.Activated:Connect(function()
			focus(id)
		end)
	end
	return tree
end

local function buildDetail(parent: Instance): Detail
	local panel = Toy.panel(parent, UDim2.fromOffset(DETAIL_X, 0), UDim2.fromOffset(DETAIL_W, NATURAL.Y))
	panel.holder.Name = "Detail"
	local face = panel.face
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = face

	local name = Toy.text(face, "", 30, UDim2.new(), UDim2.new(1, 0, 0, 34))
	name.TextXAlignment = Enum.TextXAlignment.Left
	local chips = Toy.frame(face, UDim2.fromOffset(0, 40), UDim2.new(1, 0, 0, 30))
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = chips
	local lineChip = Toy.chip(chips, "", Toy.Grey, Color3.new(1, 1, 1))
	lineChip.LayoutOrder = 1
	local classChip = Toy.chip(chips, "", Toy.CreamDark)
	classChip.LayoutOrder = 2
	local tierChip = Toy.chip(chips, "", Toy.Yellow)
	tierChip.LayoutOrder = 3

	local stage = Toy.frame(face, UDim2.fromOffset(0, 78), UDim2.new(1, 0, 0, 136), Toy.CreamDark)
	Toy.corner(stage, 12)
	local preview = TankPreview.new(stage, UDim2.fromOffset(6, 4), UDim2.new(1, -12, 1, -8))

	local pips = {}
	for index, stat in TankStats.list do
		local y = 224 + (index - 1) * 26
		local label = Toy.text(face, stat.label, 17, UDim2.fromOffset(0, y), UDim2.fromOffset(110, 18))
		label.TextXAlignment = Enum.TextXAlignment.Left
		pips[index] = Toy.pips(face, UDim2.fromOffset(116, y), Config.Garage.StatPips, 26, 18, 6)
	end

	local status = Toy.text(face, "", 16, UDim2.fromOffset(0, 302), UDim2.new(1, 0, 0, 40), Toy.BrownSoft)
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left

	local action = Toy.button(face, "", 22, UDim2.new(0, 0, 1, -74), UDim2.new(1, 0, 0, 52 + Toy.Shadow), Toy.Yellow, 14)
	action.holder.Name = "Action"
	action.button.Activated:Connect(onAction)
	local mods = Toy.button(face, "🧰", 26, UDim2.new(1, -52, 1, -74), UDim2.fromOffset(52, 52 + Toy.Shadow), Toy.YellowLight, 14)
	mods.holder.Name = "Mods"
	mods.button.Activated:Connect(function()
		openToolbox(focused)
	end)

	return {
		name = name,
		lineChip = lineChip,
		classChip = classChip,
		tierChip = tierChip,
		preview = preview,
		pips = pips,
		status = status,
		action = action,
		mods = mods,
	}
end

-- Build the shelf inside `parent` (the Toy Shelf tab). `toToolbox` opens a tank's mods;
-- the unbox animation plays over `overlay`.
function ToyShelf.mount(parent: GuiObject, overlay: Instance, toToolbox: (tankId: string) -> ())
	openToolbox = toToolbox
	unboxHost = overlay
	local frame = Toy.frame(parent, UDim2.fromScale(0.5, 0), UDim2.fromOffset(NATURAL.X, NATURAL.Y))
	frame.Name = "ToyShelf"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	root = frame

	for index, line in TankCatalog.lineOrder do
		local tab = Toy.button(frame, TankCatalog.line(line).DisplayName, 20, UDim2.fromOffset(10 + (index - 1) * 186, 0), UDim2.fromOffset(176, 50), Toy.Cream, 14)
		tab.holder.Name = `Line{line}`
		lineTabs[line] = tab
		tab.button.Activated:Connect(function()
			local data = ProfileClient.get()
			shownLine = line
			focused = if data and data.OwnedTanks[data.SelectedTank] and TankCatalog.get(data.SelectedTank).Line == line
				then data.SelectedTank
				else TankCatalog.starterOf(line)
			render()
		end)
		trees[line] = buildTree(frame, line)
	end
	detail = buildDetail(frame)
	Toy.fit(frame)

	ProfileClient.changed:Connect(function(_data: Data)
		render()
	end)
	render()
end

-- Opening the tab: focus the tank you're driving.
function ToyShelf.show()
	local data = ProfileClient.get()
	if data and data.SelectedTank ~= "" then
		focus(data.SelectedTank)
	end
end

return ToyShelf
