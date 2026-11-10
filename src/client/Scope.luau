--!strict
-- Shift toggles a zoomed gunner's view while you're driving: TankCamera moves onto the
-- turret and narrows the field of view. The overlay darkens the edges, draws range ticks
-- and shows the distance to whatever is under the crosshair. Drops out automatically when
-- your tank is lost or a menu takes the mouse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AimTarget = require(script.Parent.AimTarget)
local Config = require(ReplicatedStorage.Shared.Config)
local MouseLock = require(script.Parent.MouseLock)
local TankCamera = require(script.Parent.TankCamera)
local TankController = require(script.Parent.TankController)

local Scope = {}

local localPlayer = Players.LocalPlayer
local EDGE = Color3.fromRGB(8, 10, 14)
local LINE = Color3.fromRGB(20, 22, 28)

local gui = Instance.new("ScreenGui")
gui.Name = "Scope"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1 -- under the HUD, so health/reload stay readable
gui.Enabled = false

local function frame(position: UDim2, size: UDim2, color: Color3, transparency: number, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = anchor or Vector2.zero
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = gui
	return f
end

-- Dark side panels frame a square-ish viewport; a soft top/bottom band finishes the look.
frame(UDim2.fromScale(0, 0), UDim2.fromScale(0.18, 1), EDGE, 0.05)
frame(UDim2.fromScale(1, 0), UDim2.fromScale(0.18, 1), EDGE, 0.05, Vector2.new(1, 0))
frame(UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.06), EDGE, 0.35)
frame(UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.06), EDGE, 0.35, Vector2.new(0, 1))

-- Fine crosshair lines with a gap in the middle (the HUD draws the center reticle).
local GAP = 28
frame(UDim2.new(0.18, 0, 0.5, 0), UDim2.new(0.32, -GAP, 0, 2), LINE, 0.2, Vector2.new(0, 0.5))
frame(UDim2.new(0.82, 0, 0.5, 0), UDim2.new(0.32, -GAP, 0, 2), LINE, 0.2, Vector2.new(1, 0.5))
frame(UDim2.new(0.5, 0, 1, 0), UDim2.new(0, 2, 0.5, -GAP), LINE, 0.2, Vector2.new(0.5, 1))
-- Drop ticks below the center (holdover marks for leading).
for i = 1, 4 do
	frame(UDim2.new(0.5, 0, 0.5, GAP + i * 22), UDim2.fromOffset(i % 2 == 0 and 40 or 24, 2), LINE, 0.2, Vector2.new(0.5, 0.5))
end

local range = Instance.new("TextLabel")
range.AnchorPoint = Vector2.new(0.5, 0)
range.Position = UDim2.new(0.5, 60, 0.5, 8)
range.Size = UDim2.fromOffset(120, 22)
range.BackgroundTransparency = 1
range.Font = Enum.Font.FredokaOne
range.TextSize = 18
range.TextColor3 = Color3.fromRGB(255, 240, 180)
range.TextStrokeTransparency = 0.4
range.TextXAlignment = Enum.TextXAlignment.Left
range.Parent = gui

local zoom = range:Clone()
zoom.Position = UDim2.new(0.82, -12, 0.06, 10)
zoom.AnchorPoint = Vector2.new(1, 0)
zoom.TextXAlignment = Enum.TextXAlignment.Right
zoom.Text = `x{Config.Camera.ScopeZoom}`
zoom.Parent = gui

local function set(on: boolean)
	TankCamera.setScoped(on)
	gui.Enabled = TankCamera.isScoped()
end

local function update()
	local tank = TankController.getTank()
	if TankCamera.isScoped() and (not tank or MouseLock.isReleased()) then
		set(false)
	end
	gui.Enabled = TankCamera.isScoped()
	if gui.Enabled and tank then
		local ignore: { Instance } = { tank.model }
		if localPlayer.Character then
			table.insert(ignore, localPlayer.Character :: Model)
		end
		local point = AimTarget.getPoint(ignore, tank.muzzle.WorldPosition.Y)
		range.Text = `{math.round((point - tank.muzzle.WorldPosition).Magnitude)} studs`
	end
end

function Scope.start()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			if TankController.getTank() and not MouseLock.isReleased() then
				set(not TankCamera.isScoped())
			end
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return Scope
