--!strict
-- Right-side card for the selected tank: name, line / class / tier chips, 5-pip stat bars
-- (firepower, armor, speed), mod-tree progress toward "elite" and an Open Toolbox button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Progression = require(ReplicatedStorage.Shared.Progression)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankStats = require(script.Parent.TankStats)
local Toy = require(script.Parent.Toy)

local TankInfoCard = {}

TankInfoCard.Width = 300
TankInfoCard.Height = 290
TankInfoCard.CompactHeight = 228 -- no Open Toolbox button (the rail has the tab)
TankInfoCard.Top = 84

local PIP_W, PIP_H, PIP_GAP = 26, 18, 6

local card: Frame? = nil
local toolboxButton: Frame? = nil

function TankInfoCard.mount(parent: Instance, openToolbox: () -> ()): Frame
	local panel = Toy.panel(
		parent,
		UDim2.new(1, -16, 0, TankInfoCard.Top),
		UDim2.fromOffset(TankInfoCard.Width, TankInfoCard.Height)
	)
	panel.holder.Name = "TankInfo"
	panel.holder.AnchorPoint = Vector2.new(1, 0)
	local face = panel.face
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = face

	local name = Toy.text(face, "", 28, UDim2.new(), UDim2.new(1, 0, 0, 32))
	name.TextXAlignment = Enum.TextXAlignment.Left

	local chips = Toy.frame(face, UDim2.fromOffset(0, 38), UDim2.new(1, 0, 0, 30))
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Padding = UDim.new(0, 6)
	chipLayout.Parent = chips
	local lineChip = Toy.chip(chips, "", Toy.Grey, Color3.new(1, 1, 1))
	lineChip.LayoutOrder = 1
	local lineLabel = lineChip:FindFirstChild("Label") :: TextLabel
	local classChip = Toy.chip(chips, "", Toy.CreamDark)
	classChip.LayoutOrder = 2
	local tierChip = Toy.chip(chips, "", Toy.Yellow)
	tierChip.LayoutOrder = 3
	local classLabel = classChip:FindFirstChild("Label") :: TextLabel
	local tierLabel = tierChip:FindFirstChild("Label") :: TextLabel

	-- Stat rows.
	local pipFrames: { { Frame } } = {}
	for index, stat in TankStats.list do
		local y = 80 + (index - 1) * 28
		local label = Toy.text(face, stat.label, 18, UDim2.fromOffset(0, y), UDim2.fromOffset(100, PIP_H))
		label.TextXAlignment = Enum.TextXAlignment.Left
		local row = {}
		for p = 1, Config.Garage.StatPips do
			local pip = Toy.frame(face, UDim2.fromOffset(108 + (p - 1) * (PIP_W + PIP_GAP), y), UDim2.fromOffset(PIP_W, PIP_H), Toy.Grey)
			Toy.corner(pip, 6)
			Toy.outline(pip, 2)
			row[p] = pip
		end
		pipFrames[index] = row
	end

	-- Elite progress.
	local eliteLabel = Toy.text(face, "", 16, UDim2.fromOffset(0, 168), UDim2.new(1, 0, 0, 20), Toy.BrownSoft)
	eliteLabel.TextXAlignment = Enum.TextXAlignment.Left
	local track = Toy.frame(face, UDim2.fromOffset(0, 192), UDim2.new(1, 0, 0, 16), Toy.CreamDark)
	Toy.corner(track, 8)
	Toy.outline(track, 2)
	local fill = Toy.frame(track, UDim2.new(), UDim2.fromScale(0, 1), Toy.Green)
	Toy.corner(fill, 8)

	local toolbox = Toy.button(face, "🧰 Open Toolbox", 20, UDim2.new(0, 0, 1, -54), UDim2.new(1, 0, 0, 46), Toy.YellowLight, 12)
	toolbox.holder.Name = "OpenToolbox"
	card = panel.holder
	toolboxButton = toolbox.holder
	toolbox.button.Activated:Connect(openToolbox)

	local rows = Config.Mods.Rows
	local function render(data: PlayerDataTypes.Data)
		local id = data.SelectedTank
		local def = TankCatalog.get(id)
		local line = TankCatalog.line(def.Line)
		name.Text = def.DisplayName
		lineLabel.Text = line.DisplayName
		lineChip.BackgroundColor3 = line.Color
		classLabel.Text = def.Class
		tierLabel.Text = `Tier {Toy.tier(def.Tier)}`
		for index, count in TankStats.pips(id, Progression.equipped(data, id)) do
			for p, pip in pipFrames[index] do
				pip.BackgroundColor3 = if p <= count then Toy.Yellow else Toy.Grey
			end
		end
		local done = Progression.rowsDone(data, id)
		eliteLabel.Text = if done >= rows then "★ ELITE" else `Mod rows to Elite: {done} / {rows}`
		fill.Size = UDim2.fromScale(done / rows, 1)
		fill.Visible = done > 0
	end
	ProfileClient.changed:Connect(render)
	local data = ProfileClient.get()
	if data then
		render(data)
	end
	return panel.holder
end

function TankInfoCard.setCompact(on: boolean)
	local holder, toolbox = card, toolboxButton
	if holder and toolbox then
		holder.Size = UDim2.fromOffset(TankInfoCard.Width, if on then TankInfoCard.CompactHeight else TankInfoCard.Height)
		toolbox.Visible = not on
	end
end

return TankInfoCard
