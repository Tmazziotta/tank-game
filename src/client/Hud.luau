--!strict
-- Tank HUD: a cursor crosshair, a marker for where the barrel actually points, a reload
-- bar, a health bar, hit markers and a damage flash. Pure view: other modules push state
-- into it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Hud = {}

local READY_COLOR = Color3.fromRGB(120, 230, 140)
local RELOAD_COLOR = Color3.fromRGB(255, 170, 60)
local HEALTH_HIGH = Color3.fromRGB(120, 230, 140)
local HEALTH_LOW = Color3.fromRGB(255, 80, 80)

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

local function bar(name: string, position: UDim2, height: number): (Frame, TextLabel, Frame)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = position
	holder.Size = UDim2.fromOffset(280, height + 26)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.new(1, 0, 0, 20)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.FredokaOne
	caption.TextSize = 20
	caption.TextColor3 = Color3.new(1, 1, 1)
	caption.TextStrokeTransparency = 0.5
	caption.Parent = holder

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 26)
	back.Size = UDim2.new(1, 0, 0, height)
	back.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Parent = holder
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0.5, 0)
	backCorner.Parent = back

	local filled = Instance.new("Frame")
	filled.Size = UDim2.fromScale(1, 1)
	filled.BorderSizePixel = 0
	filled.Parent = back
	local filledCorner = Instance.new("UICorner")
	filledCorner.CornerRadius = UDim.new(0.5, 0)
	filledCorner.Parent = filled
	return holder, caption, filled
end

local _, healthLabel, healthFill = bar("Health", UDim2.new(0.5, 0, 1, -96), 18)

local hitMarker = Instance.new("TextLabel")
hitMarker.Name = "HitMarker"
hitMarker.AnchorPoint = Vector2.new(0.5, 1)
hitMarker.Size = UDim2.fromOffset(240, 28)
hitMarker.BackgroundTransparency = 1
hitMarker.Font = Enum.Font.FredokaOne
hitMarker.TextSize = 26
hitMarker.TextTransparency = 1
hitMarker.TextStrokeTransparency = 1
hitMarker.Parent = gui

local damageFlash = Instance.new("Frame")
damageFlash.Name = "DamageFlash"
damageFlash.Size = UDim2.fromScale(1, 1)
damageFlash.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
damageFlash.BackgroundTransparency = 1
damageFlash.BorderSizePixel = 0
damageFlash.ZIndex = 0
damageFlash.Parent = gui

local hitMarkerTween: Tween? = nil

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

function Hud.setHealth(health: number, maxHealth: number)
	local fraction = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
	healthFill.Size = UDim2.fromScale(fraction, 1)
	healthFill.BackgroundColor3 = HEALTH_LOW:Lerp(HEALTH_HIGH, fraction)
	healthLabel.Text = `HP {math.ceil(health)}`
end

-- Floating text above the crosshair, e.g. "-24 SIDE" or "RICOCHET".
function Hud.showHitMarker(text: string, color: Color3)
	if hitMarkerTween then
		hitMarkerTween:Cancel()
	end
	hitMarker.Text = text
	hitMarker.TextColor3 = color
	hitMarker.TextTransparency = 0
	hitMarker.TextStrokeTransparency = 0.3
	local tween = TweenService:Create(
		hitMarker,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	hitMarkerTween = tween
	tween:Play()
end

-- Red screen pulse when your tank takes damage (stronger for bigger hits).
function Hud.flashDamage(fraction: number)
	damageFlash.BackgroundTransparency = 1 - math.clamp(0.15 + fraction, 0.15, 0.5)
	TweenService:Create(damageFlash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
end

-- Called every frame with viewport positions (nil hides the barrel marker).
function Hud.update(barrelScreenPoint: Vector2?)
	local mouse = UserInputService:GetMouseLocation()
	crosshair.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	hitMarker.Position = UDim2.fromOffset(mouse.X, mouse.Y - 22)
	if barrelScreenPoint then
		barrelMarker.Visible = true
		barrelMarker.Position = UDim2.fromOffset(barrelScreenPoint.X, barrelScreenPoint.Y)
	else
		barrelMarker.Visible = false
	end
end

return Hud
