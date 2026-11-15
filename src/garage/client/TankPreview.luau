--!strict
-- A ViewportFrame showing a still, three-quarter render of a tank (loadout cards).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TankBuilder = require(ReplicatedStorage.Shared.TankBuilder)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)

export type Preview = { frame: ViewportFrame, show: (tankId: string, mods: { string }?) -> () }

local TankPreview = {}

function TankPreview.new(parent: Instance, position: UDim2, size: UDim2): Preview
	local frame = Instance.new("ViewportFrame")
	frame.Position = position
	frame.Size = size
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(170, 160, 150)
	frame.LightColor = Color3.fromRGB(255, 245, 230)
	frame.LightDirection = Vector3.new(-1, -2, -1)
	frame.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = frame
	frame.CurrentCamera = camera

	local shownKey = ""
	local model: Model? = nil

	local function show(tankId: string, mods: { string }?)
		local key = `{tankId}:{TankCatalog.encodeMods(mods or {})}`
		if key == shownKey then
			return
		end
		shownKey = key
		if model then
			model:Destroy()
		end
		-- Facing the camera's left, three-quarter on.
		local tank = TankBuilder.build(CFrame.Angles(0, math.rad(-35), 0), nil, TankCatalog.normalize(tankId), mods)
		for _, d in tank.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		tank.model.Parent = frame
		model = tank.model
		local cf, extents = tank.model:GetBoundingBox()
		local radius = extents.Magnitude / 2
		local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
		local focus = cf.Position
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0.45, 1).Unit * distance, focus)
	end

	return { frame = frame, show = show }
end

return TankPreview
