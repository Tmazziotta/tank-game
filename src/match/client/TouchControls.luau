--!strict
-- On-screen controls for phones and tablets (no keyboard):
--   * Left side: a floating joystick (appears where the thumb lands) drives the tank.
--   * Right side: drag anywhere to look/aim (the screen-center crosshair is the aim point).
--   * FIRE (hold to keep firing as the gun reloads), SCOPE toggle, GARAGE open/close, and
--     NEXT to cycle spectated teammates when out of the round.
-- Writes drive/look into TouchInput; buttons call the same actions as the keys.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MatchGate = require(script.Parent.MatchGate)
local GarageMenu = require(script.Parent.GarageMenu)
local MouseLock = require(script.Parent.MouseLock)
local Scope = require(script.Parent.Scope)
local Spectator = require(script.Parent.Spectator)
local TankCamera = require(script.Parent.TankCamera)
local TankController = require(script.Parent.TankController)
local TouchInput = require(script.Parent.TouchInput)
local WeaponClient = require(script.Parent.WeaponClient)

local TouchControls = {}


local STICK_RADIUS = 60 -- thumb travel, pixels
local STICK_DEADZONE = 0.15
local JOYSTICK_ZONE = 0.4 -- left fraction of the screen that starts the joystick

local DARK = Color3.fromRGB(30, 32, 44)
local LIGHT = Color3.fromRGB(240, 240, 245)
local FIRE_COLOR = Color3.fromRGB(235, 80, 70)
local FIRE_DIM = Color3.fromRGB(120, 70, 70)

local gui = Instance.new("ScreenGui")
gui.Name = "TouchControls"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20 -- above the garage, so the GARAGE button can close it
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Enabled = false

local function round(parent: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = parent
end

local function stroke(parent: GuiObject)
	local s = Instance.new("UIStroke")
	s.Color = LIGHT
	s.Transparency = 0.5
	s.Thickness = 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function button(name: string, text: string, size: UDim2, position: UDim2, anchor: Vector2, color: Color3, textSize: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = position
	b.AnchorPoint = anchor
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.25
	b.TextColor3 = LIGHT
	b.Font = Enum.Font.FredokaOne
	b.TextSize = textSize
	b.AutoButtonColor = true
	b.Parent = gui
	round(b)
	stroke(b)
	return b
end

local fireButton = button("Fire", "FIRE", UDim2.fromOffset(120, 120), UDim2.new(1, -36, 1, -44), Vector2.new(1, 1), FIRE_COLOR, 26)
local scopeButton = button("Scope", "SCOPE", UDim2.fromOffset(76, 76), UDim2.new(1, -176, 1, -50), Vector2.new(1, 1), DARK, 16)
local garageButton = button("Garage", "GARAGE", UDim2.fromOffset(104, 44), UDim2.new(1, -16, 0.42, 0), Vector2.new(1, 0.5), DARK, 18)
local nextButton = button("Next", "NEXT", UDim2.fromOffset(110, 56), UDim2.new(1, -36, 1, -60), Vector2.new(1, 1), DARK, 20)

-- Reload fill inside the fire button.
local reloadFill = Instance.new("Frame")
reloadFill.Name = "Reload"
reloadFill.AnchorPoint = Vector2.new(0.5, 1)
reloadFill.Position = UDim2.fromScale(0.5, 1)
reloadFill.Size = UDim2.fromScale(1, 0)
reloadFill.BackgroundColor3 = LIGHT
reloadFill.BackgroundTransparency = 0.75
reloadFill.ZIndex = 0
reloadFill.Parent = fireButton
round(reloadFill)

-- Joystick: a ghost at rest in the bottom-left, moves to wherever the thumb lands.
local stickBase = Instance.new("Frame")
stickBase.Name = "StickBase"
stickBase.AnchorPoint = Vector2.new(0.5, 0.5)
stickBase.Size = UDim2.fromOffset(STICK_RADIUS * 2 + 20, STICK_RADIUS * 2 + 20)
stickBase.BackgroundColor3 = DARK
stickBase.BackgroundTransparency = 0.6
stickBase.Parent = gui
round(stickBase)
stroke(stickBase)

local stickThumb = Instance.new("Frame")
stickThumb.Name = "Thumb"
stickThumb.AnchorPoint = Vector2.new(0.5, 0.5)
stickThumb.Position = UDim2.fromScale(0.5, 0.5)
stickThumb.Size = UDim2.fromOffset(56, 56)
stickThumb.BackgroundColor3 = LIGHT
stickThumb.BackgroundTransparency = 0.3
stickThumb.Parent = stickBase
round(stickThumb)

local REST_POSITION = UDim2.new(0, 40 + STICK_RADIUS + 10, 1, -(40 + STICK_RADIUS + 10))

local stickTouch: InputObject? = nil
local stickOrigin = Vector2.zero
local lookTouch: InputObject? = nil
local lookLast = Vector2.zero
local fireHeld = false

local function resetStick()
	stickTouch = nil
	TouchInput.setDrive(0, 0)
	stickBase.Position = REST_POSITION
	stickBase.BackgroundTransparency = 0.6
	stickThumb.Position = UDim2.fromScale(0.5, 0.5)
end

-- Screen position of a touch inside this GUI's coordinate space.
local function toGui(position: Vector3): Vector2
	return Vector2.new(position.X, position.Y) - gui.AbsolutePosition
end

local function driving(): boolean
	return TankController.getTank() ~= nil and not MouseLock.isReleased()
end

local function onTouchStarted(touch: InputObject, processed: boolean)
	if processed or not gui.Enabled or not driving() then
		return
	end
	local viewport = workspace.CurrentCamera.ViewportSize
	if touch.Position.X < viewport.X * JOYSTICK_ZONE then
		if not stickTouch then
			stickTouch = touch
			stickOrigin = Vector2.new(touch.Position.X, touch.Position.Y)
			local at = toGui(touch.Position)
			stickBase.Position = UDim2.fromOffset(at.X, at.Y)
			stickBase.BackgroundTransparency = 0.35
		end
	elseif not lookTouch then
		lookTouch = touch
		lookLast = Vector2.new(touch.Position.X, touch.Position.Y)
	end
end

local function onTouchMoved(touch: InputObject, _processed: boolean)
	local position = Vector2.new(touch.Position.X, touch.Position.Y)
	if touch == stickTouch then
		local offset = position - stickOrigin
		if offset.Magnitude > STICK_RADIUS then
			offset = offset.Unit * STICK_RADIUS
		end
		stickThumb.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		local v = offset / STICK_RADIUS
		local function dead(x: number): number
			return if math.abs(x) < STICK_DEADZONE then 0 else (x - math.sign(x) * STICK_DEADZONE) / (1 - STICK_DEADZONE)
		end
		-- Up = forward, sideways = turn.
		TouchInput.setDrive(dead(-v.Y), dead(v.X))
	elseif touch == lookTouch then
		TouchInput.addLook(position - lookLast)
		lookLast = position
	end
end

local function onTouchEnded(touch: InputObject, _processed: boolean)
	if touch == stickTouch then
		resetStick()
	elseif touch == lookTouch then
		lookTouch = nil
	end
end

local function update()
	local touchDevice = TouchInput.isTouchDevice()
	gui.Enabled = touchDevice
	if not touchDevice then
		return
	end
	local drivingNow = driving()
	local spectating = TankController.getTank() == nil and Spectator.isWatching()
	fireButton.Visible = drivingNow
	scopeButton.Visible = drivingNow
	stickBase.Visible = drivingNow
	nextButton.Visible = spectating and not GarageMenu.isOpen()
	garageButton.Text = if GarageMenu.isOpen() then "CLOSE" else "GARAGE"
	scopeButton.Text = if TankCamera.isScoped() then "UNSCOPE" else "SCOPE"
	scopeButton.TextSize = if TankCamera.isScoped() then 13 else 16
	if not drivingNow then
		if stickTouch then
			resetStick()
		end
		lookTouch = nil
		fireHeld = false
	end

	local progress = WeaponClient.reloadProgress()
	reloadFill.Size = UDim2.fromScale(1, if progress < 1 then progress else 0)
	fireButton.BackgroundColor3 = if progress >= 1 then FIRE_COLOR else FIRE_DIM
	if fireHeld then
		WeaponClient.fire()
	end
end

function TouchControls.start()
	resetStick()
	MatchGate.mount(gui)

	fireButton.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			fireHeld = true
			WeaponClient.fire()
		end
	end)
	fireButton.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			fireHeld = false
		end
	end)
	scopeButton.Activated:Connect(Scope.toggle)
	garageButton.Activated:Connect(GarageMenu.toggle)
	nextButton.Activated:Connect(Spectator.next)

	UserInputService.TouchStarted:Connect(onTouchStarted)
	UserInputService.TouchMoved:Connect(onTouchMoved)
	UserInputService.TouchEnded:Connect(onTouchEnded)
	RunService.RenderStepped:Connect(update)
end

return TouchControls
