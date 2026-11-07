--!strict
-- Third-person camera that trails the hull's yaw with exponential smoothing.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TankCamera = {}

local BIND_NAME = "TankCamera"
local bound = false
local smoothedPos: Vector3? = nil
local smoothedFocus: Vector3? = nil

local function flatForward(cf: CFrame): Vector3
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
end

function TankCamera.bind(hull: BasePart)
	TankCamera.unbind()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.Camera.FieldOfView
	smoothedPos = nil
	smoothedFocus = nil
	bound = true

	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if not hull.Parent then
			return
		end
		local cfg = Config.Camera
		local base = hull.Position
		local forward = flatForward(hull.CFrame)
		local targetPos = base - forward * cfg.Distance + Vector3.yAxis * cfg.Height
		local targetFocus = base + forward * cfg.LookAhead + Vector3.yAxis * cfg.LookHeight

		local alpha = 1 - math.exp(-cfg.Smoothing * dt)
		local pos = if smoothedPos then smoothedPos:Lerp(targetPos, alpha) else targetPos
		local focus = if smoothedFocus then smoothedFocus:Lerp(targetFocus, alpha) else targetFocus
		smoothedPos = pos
		smoothedFocus = focus
		camera.CFrame = CFrame.lookAt(pos, focus)
	end)
end

function TankCamera.unbind()
	if bound then
		RunService:UnbindFromRenderStep(BIND_NAME)
		bound = false
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
end

return TankCamera
