--!strict
-- World point under the screen center (the mouse-look crosshair). Falls back to a
-- horizontal plane at the given height when the center points at the sky.

local AimTarget = {}

local MAX_DISTANCE = 1000

function AimTarget.getPoint(ignore: { Instance }, fallbackHeight: number): Vector3
	local camera = workspace.CurrentCamera
	local center = camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(center.X, center.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_DISTANCE, params)
	if result then
		return result.Position
	end

	if ray.Direction.Y < -1e-3 then
		local t = (fallbackHeight - ray.Origin.Y) / ray.Direction.Y
		return ray.Origin + ray.Direction * t
	end
	return ray.Origin + ray.Direction * MAX_DISTANCE
end

return AimTarget
