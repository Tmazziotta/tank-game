--!strict
-- While the player is in the Garage, the camera holds a fixed shot of the turntable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local GarageCamera = {}

local BIND_NAME = "GarageCamera"
local bound = false

function GarageCamera.setActive(on: boolean, center: CFrame)
	if on == bound then
		return
	end
	bound = on
	if on then
		local focus = center.Position + Vector3.new(0, Config.Garage.CameraLookHeight, 0)
		local shot = CFrame.lookAt(center.Position + Config.Garage.CameraOffset, focus)
		RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
			local camera = workspace.CurrentCamera
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = shot
			camera.FieldOfView = Config.Garage.FieldOfView
		end)
	else
		RunService:UnbindFromRenderStep(BIND_NAME)
		workspace.CurrentCamera.FieldOfView = Config.Camera.FieldOfView
	end
end

return GarageCamera
