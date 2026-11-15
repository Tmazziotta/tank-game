--!strict
-- Small helpers and palette for the lobby UI, so every garage widget looks the same.

local UiKit = {}

UiKit.Font = Enum.Font.FredokaOne
UiKit.Panel = Color3.fromRGB(28, 30, 42)
UiKit.PanelLight = Color3.fromRGB(44, 47, 64)
UiKit.Muted = Color3.fromRGB(150, 155, 175)
UiKit.Gold = Color3.fromRGB(255, 205, 70)
UiKit.Blue = Color3.fromRGB(70, 150, 255)
UiKit.Green = Color3.fromRGB(130, 230, 140)
UiKit.Disabled = Color3.fromRGB(70, 74, 96)
UiKit.XP = Color3.fromRGB(120, 200, 255)

function UiKit.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function UiKit.stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end

function UiKit.frame(parent: Instance, position: UDim2, size: UDim2, color: Color3, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function UiKit.label(parent: Instance, text: string, textSize: number, position: UDim2, size: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = UiKit.Font
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.6
	l.Position = position
	l.Size = size
	l.Text = text
	l.Parent = parent
	return l
end

function UiKit.button(parent: Instance, text: string, textSize: number, position: UDim2, size: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Font = UiKit.Font
	b.TextSize = textSize
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0.6
	b.BackgroundColor3 = color
	b.Position = position
	b.Size = size
	b.Text = text
	b.Parent = parent
	UiKit.corner(b, 12)
	return b
end

-- Roman numerals for tiers (I-X).
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
function UiKit.tier(tier: number): string
	return ROMAN[tier] or tostring(tier)
end

return UiKit
