--!strict
-- The Garage's toy-box UI style: cream panels with thick dark-brown outlines and a solid
-- drop shadow, a yellow accent, chunky rounded type. Every lobby widget builds from these.

local TweenService = game:GetService("TweenService")

local Toy = {}

Toy.Font = Enum.Font.FredokaOne
Toy.Cream = Color3.fromHex("#FFFDF6")
Toy.CreamDark = Color3.fromHex("#F1E9D6")
Toy.Brown = Color3.fromHex("#3B2414")
Toy.BrownSoft = Color3.fromHex("#8A6A52")
Toy.Yellow = Color3.fromHex("#F2B90C")
Toy.YellowLight = Color3.fromHex("#FFE27A")
Toy.Grey = Color3.fromHex("#C9C2B4")
Toy.Green = Color3.fromHex("#5DBB63")
Toy.Blue = Color3.fromHex("#4C9BE8")
Toy.Red = Color3.fromHex("#E8574C")

Toy.Outline = 4
Toy.Shadow = 6
Toy.Radius = 16

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
function Toy.tier(tier: number): string
	return ROMAN[tier] or tostring(tier)
end

function Toy.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Toy.Radius)
	c.Parent = parent
end

function Toy.outline(parent: Instance, thickness: number?, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = thickness or Toy.Outline
	s.Color = color or Toy.Brown
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

function Toy.frame(parent: Instance, position: UDim2, size: UDim2, color: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = color or Toy.Cream
	f.BackgroundTransparency = if color then transparency or 0 else 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function Toy.text(parent: Instance, text: string, size: number, position: UDim2, dims: UDim2, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Toy.Font
	l.TextSize = size
	l.TextColor3 = color or Toy.Brown
	l.Position = position
	l.Size = dims
	l.Text = text
	l.Parent = parent
	return l
end

export type Panel = {
	holder: Frame, -- positioned/sized by the caller; holds shadow + face
	face: Frame, -- put content here
	shadow: Frame,
	stroke: UIStroke,
}

-- A cream panel with an outline and a solid shadow under it. `position`/`size` place the
-- whole thing (the shadow sits inside the bottom Toy.Shadow pixels).
function Toy.panel(parent: Instance, position: UDim2, size: UDim2, color: Color3?, radius: number?): Panel
	local holder = Toy.frame(parent, position, size)
	local shadow = Toy.frame(holder, UDim2.fromOffset(0, Toy.Shadow), UDim2.new(1, 0, 1, -Toy.Shadow), Toy.Brown)
	shadow.Name = "Shadow"
	Toy.corner(shadow, radius)
	local face = Toy.frame(holder, UDim2.new(), UDim2.new(1, 0, 1, -Toy.Shadow), color or Toy.Cream)
	face.Name = "Face"
	face.ZIndex = 2
	Toy.corner(face, radius)
	local stroke = Toy.outline(face)
	return { holder = holder, face = face, shadow = shadow, stroke = stroke }
end

export type Button = Panel & {
	button: TextButton, -- covers the face; listen to .Activated
	label: TextLabel,
}

-- A chunky toy button: presses down onto its shadow while held.
function Toy.button(parent: Instance, text: string, textSize: number, position: UDim2, size: UDim2, color: Color3?, radius: number?): Button
	local panel = Toy.panel(parent, position, size, color, radius)
	local label = Toy.text(panel.face, text, textSize, UDim2.new(), UDim2.fromScale(1, 1))
	label.ZIndex = 3
	local button = Instance.new("TextButton")
	button.Text = ""
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 4
	button.Parent = panel.face
	local up = panel.face.Position
	local down = UDim2.fromOffset(0, Toy.Shadow - 2)
	local info = TweenInfo.new(0.06)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(panel.face, info, { Position = down }):Play()
	end)
	local function release()
		TweenService:Create(panel.face, info, { Position = up }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	return {
		holder = panel.holder,
		face = panel.face,
		shadow = panel.shadow,
		stroke = panel.stroke,
		button = button,
		label = label,
	}
end

-- A small rounded chip (e.g. "Heavy", "Tier II").
function Toy.chip(parent: Instance, text: string, color: Color3, textColor: Color3?): Frame
	local chip = Toy.frame(parent, UDim2.new(), UDim2.fromOffset(0, 30), color)
	chip.AutomaticSize = Enum.AutomaticSize.X
	Toy.corner(chip, 15)
	Toy.outline(chip, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = chip
	local label = Toy.text(chip, text, 17, UDim2.new(), UDim2.fromScale(0, 1), textColor or Toy.Brown)
	label.Name = "Label"
	label.AutomaticSize = Enum.AutomaticSize.X
	return chip
end

-- A drawn coin (the coin emoji doesn't render in Roblox).
function Toy.coin(parent: Instance, position: UDim2, size: number): Frame
	local coin = Toy.frame(parent, position, UDim2.fromOffset(size, size), Toy.Yellow)
	Toy.corner(coin, size)
	Toy.outline(coin, 3)
	local inner = Toy.frame(coin, UDim2.fromScale(0.22, 0.22), UDim2.fromScale(0.56, 0.56), Toy.YellowLight)
	Toy.corner(inner, size)
	return coin
end

-- A red "NEW" badge pinned to the top-right corner of `parent`.
function Toy.newBadge(parent: Instance): Frame
	local badge = Toy.frame(parent, UDim2.new(1, -30, 0, -10), UDim2.fromOffset(46, 24), Toy.Red)
	badge.ZIndex = 10
	Toy.corner(badge, 12)
	Toy.outline(badge, 3)
	local label = Toy.text(badge, "NEW", 15, UDim2.new(), UDim2.fromScale(1, 1), Color3.new(1, 1, 1))
	label.ZIndex = 11
	return badge
end

-- Bump every GuiObject under `root` (and root) by `delta` ZIndex levels.
function Toy.raise(root: GuiObject, delta: number)
	root.ZIndex += delta
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += delta
		end
	end
end

return Toy
