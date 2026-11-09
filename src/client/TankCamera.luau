--!strict
-- Mouse-look tank camera. The mouse is locked to the screen center and orbits the camera
-- around the tank (yaw + pitch), independent of the hull, so you drive with WASD and aim
-- with the mouse. The screen center is the aim point; the turret follows it. The camera
-- follows the hull's position smoothly, pulls back with speed, and pulls in to avoid walls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local MouseLock = require(script.Parent.MouseLock)
local TankDrive = require(ReplicatedStorage.Shared.TankDrive)

local TankCamera = {}

local BIND_NAME = "TankCamera"
local WALL_MARGIN = 1.5 -- keep this far in front of a wall between camera and tank

local bound = false
local yaw = 0 -- world yaw, radians (0 = looking toward -Z)
local pitch = 0
local smoothedFocus: Vector3? = nil
local smoothedDistance: number? = nil

local function flatYaw(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- Raycast params ignoring the tank, the local character and client-only effects.
local function cameraParams(tankModel: Instance): RaycastParams
	local ignore: { Instance } = { tankModel }
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	for _, name in { "ClientEffects", "TankOverlays", "Debris" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

function TankCamera.bind(tank: TankDrive.Refs)
	TankCamera.unbind()
	local hull = tank.hull
	local spec = tank.spec
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.Camera.FieldOfView
	yaw = flatYaw(hull.CFrame)
	pitch = Config.Camera.DefaultPitch
	smoothedFocus = nil
	smoothedDistance = nil
	bound = true

	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if not hull.Parent then
			return
		end
		local cfg = Config.Camera

		-- Mouse look. Re-assert the lock every frame (focus changes can release it), unless a
		-- menu has the cursor.
		MouseLock.apply(true)
		if not MouseLock.isReleased() then
			local delta = UserInputService:GetMouseDelta()
			yaw -= delta.X * cfg.MouseSensitivity
			pitch = math.clamp(pitch - delta.Y * cfg.MouseSensitivity, cfg.MinPitch, cfg.MaxPitch)
		end

		-- Pull back with speed so you can see further ahead when moving fast.
		local velocity = hull.AssemblyLinearVelocity
		local planarSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local speedFraction = math.clamp(planarSpeed / spec.MaxForwardSpeed, 0, 1)
		local alpha = 1 - math.exp(-cfg.Smoothing * dt)
		-- Pull back partly with tank size: a Heavy still looks big on screen, a Light small.
		local sizeFactor = 1 + (spec.Scale - 1) * cfg.SizeFollow
		local targetDistance = cfg.Distance * sizeFactor + cfg.SpeedPullback * speedFraction
		local distance = if smoothedDistance then smoothedDistance + (targetDistance - smoothedDistance) * alpha else targetDistance
		smoothedDistance = distance

		-- Rotation follows the mouse instantly; only the position is smoothed.
		local targetFocus = hull.Position + Vector3.yAxis * cfg.FocusHeight * sizeFactor
		local focus = if smoothedFocus then smoothedFocus:Lerp(targetFocus, alpha) else targetFocus
		smoothedFocus = focus

		local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		local desired = focus + rotation:VectorToWorldSpace(Vector3.new(0, 0, distance)) + Vector3.yAxis * cfg.Lift

		-- Don't let walls come between the camera and the tank.
		local offset = desired - focus
		local hit = workspace:Raycast(focus, offset, cameraParams(hull.Parent :: Instance))
		local position = if hit then focus + offset.Unit * math.max(hit.Distance - WALL_MARGIN, 2) else desired

		camera.CFrame = CFrame.new(position) * rotation
	end)
end

function TankCamera.unbind()
	if bound then
		RunService:UnbindFromRenderStep(BIND_NAME)
		bound = false
		MouseLock.apply(false)
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
end

return TankCamera
