--!strict
-- Tank HUD: a cursor crosshair, a marker for where the barrel actually points, and a
-- reload bar. Pure view: other modules push state into it.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Hud = {}

local READY_COLOR = Color3.fromRGB(120, 230, 140)
local RELOAD_COLOR = Color3.fromRGB(255, 170, 60)

local gui = Instance.new("ScreenGui")
gui.Name = "TankHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- viewport coordinates map 1:1 to GUI offsets
gui.Enabled = false

local function ring(name: string, size: number, color: Color3, thickness: number): (Frame, UIStroke)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = frame
	frame.Parent = gui
	return frame, stroke
end

local crosshair = ring("Crosshair", 26, Color3.new(1, 1, 1), 2)
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(4, 4)
dot.BackgroundColor3 = Color3.new(1, 1, 1)
dot.BorderSizePixel = 0
dot.Parent = crosshair

local barrelMarker, barrelStroke = ring("BarrelMarker", 14, READY_COLOR, 3)

local panel = Instance.new("Frame")
panel.Name = "Reload"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -40)
panel.Size = UDim2.fromOffset(280, 46)
panel.BackgroundTransparency = 1
panel.Parent = gui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 20)
label.BackgroundTransparency = 1
label.Font = Enum.Font.FredokaOne
label.TextSize = 20
label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeTransparency = 0.5
label.Text = "READY"
label.Parent = panel

local track = Instance.new("Frame")
track.Position = UDim2.fromOffset(0, 26)
track.Size = UDim2.new(1, 0, 0, 14)
track.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
track.BackgroundTransparency = 0.25
track.BorderSizePixel = 0
track.Parent = panel
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0.5, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = READY_COLOR
fill.BorderSizePixel = 0
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0.5, 0)
fillCorner.Parent = fill

function Hud.mount()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function Hud.setVisible(visible: boolean)
	if gui.Enabled ~= visible then
		gui.Enabled = visible
		UserInputService.MouseIconEnabled = not visible
	end
end

-- progress: 0 = just fired, 1 = loaded.
function Hud.setReload(progress: number)
	local ready = progress >= 1
	fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	fill.BackgroundColor3 = if ready then READY_COLOR else RELOAD_COLOR
	barrelStroke.Color = fill.BackgroundColor3
	label.Text = if ready then "READY - CLICK TO FIRE" else "RELOADING"
end

-- Called every frame with viewport positions (nil hides the barrel marker).
function Hud.update(barrelScreenPoint: Vector2?)
	local mouse = UserInputService:GetMouseLocation()
	crosshair.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	if barrelScreenPoint then
		barrelMarker.Visible = true
		barrelMarker.Position = UDim2.fromOffset(barrelScreenPoint.X, barrelScreenPoint.Y)
	else
		barrelMarker.Visible = false
	end
end

return Hud
