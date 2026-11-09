--!strict
-- Breaks crushable props. Several times a second, every live tank's footprint is checked
-- against the props folder; a prop it overlaps is knocked loose and thrown along the
-- tank's motion. Blasts break props in their radius too. Broken pieces become ordinary
-- short-lived debris (DebrisService). Crates split into smaller blocks; trees topple whole.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DebrisService = require(script.Parent.DebrisService)
local MapSchema = require(ReplicatedStorage.Shared.MapSchema)
local MapService = require(script.Parent.MapService)
local TankService = require(script.Parent.TankService)

local PropCrusher = {}

-- Tank footprint (Medium, scale 1) used for overlap checks; scaled per tank.
local FOOTPRINT = Vector3.new(10, 6, 12)

local rng = Random.new()

local function loosen(part: BasePart)
	part.Anchored = false
	part.CanCollide = true
	part.CustomPhysicalProperties = PhysicalProperties.new(Config.Props.Density, 0.5, 0.2)
	DebrisService.add(part)
	if part:CanSetNetworkOwnership() then
		part:SetNetworkOwner(nil)
	end
end

local function fling(part: BasePart, velocity: Vector3, spin: number)
	local mass = part.AssemblyMass
	part:ApplyImpulse(velocity * mass)
	part:ApplyAngularImpulse(Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * spin * mass)
end

-- Replace a crate with 8 half-size blocks.
local function shatter(box: BasePart, velocity: Vector3)
	local half = box.Size / 2
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local piece = Instance.new("Part")
				piece.Name = "Splinter"
				piece.Size = half
				piece.CFrame = box.CFrame * CFrame.new(x * half.X / 2, y * half.Y / 2, z * half.Z / 2)
				piece.Color = box.Color
				piece.Material = box.Material
				piece.TopSurface = Enum.SurfaceType.Smooth
				piece.BottomSurface = Enum.SurfaceType.Smooth
				piece.Parent = workspace
				loosen(piece)
				local outward = (piece.Position - box.Position).Unit * 6
				fling(piece, velocity + outward, 6)
			end
		end
	end
	box:Destroy()
end

-- Break one prop. `push` is the world velocity to throw it with.
function PropCrusher.crush(model: Model, push: Vector3)
	if not model.Parent or model:GetAttribute(MapSchema.CrushableAttribute) ~= true then
		return
	end
	model:SetAttribute(MapSchema.CrushableAttribute, false) -- never twice
	local parts: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	if model.Name == "Tree" then
		-- Topple as one piece: weld canopy to trunk, push the top over.
		local trunk = model:FindFirstChild("Trunk") :: BasePart?
		local canopy = model:FindFirstChild("Canopy") :: BasePart?
		if trunk and canopy then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = trunk
			weld.Part1 = canopy
			weld.Parent = trunk
			canopy.Massless = true
			loosen(trunk)
			loosen(canopy)
			trunk:ApplyImpulseAtPosition(push * 0.6 * trunk.AssemblyMass, canopy.Position)
		end
	else
		for _, part in parts do
			if part.Name == "Crate" then
				shatter(part, push)
			else
				loosen(part)
				fling(part, push + Vector3.yAxis * 6, 4)
			end
		end
	end
	model:Destroy() -- loose pieces were reparented to the debris folder
end

-- Props a box overlaps (each Model once).
local function overlapping(cframe: CFrame, size: Vector3, props: Folder): { Model }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { props }
	local found: { [Model]: boolean } = {}
	local list: { Model } = {}
	for _, part in workspace:GetPartBoundsInBox(cframe, size, params) do
		local model = part.Parent
		if model and model:IsA("Model") and not found[model] then
			found[model] = true
			table.insert(list, model)
		end
	end
	return list
end

-- Break props within `radius` of a blast, throwing them away from it.
function PropCrusher.blast(center: Vector3, radius: number)
	local props = MapService.getPropsFolder()
	if not props then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { props }
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInRadius(center, radius, params) do
		local model = part.Parent
		if model and model:IsA("Model") and not seen[model] then
			seen[model] = true
			local away = part.Position - center
			local dir = if away.Magnitude > 1e-3 then away.Unit else Vector3.yAxis
			PropCrusher.crush(model, (dir + Vector3.yAxis * 0.6).Unit * Config.Weapon.BlastImpulse * 0.5)
		end
	end
end

local function crushUnderTanks()
	local props = MapService.getPropsFolder()
	if not props then
		return
	end
	for _, entry in TankService.liveTanks() do
		local hull = entry.tank.hull
		if hull.Parent then
			local size = FOOTPRINT * entry.tank.spec.Scale
			local velocity = hull.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			for _, model in overlapping(hull.CFrame * CFrame.new(0, 1, 0), size, props) do
				local speed = math.max(velocity.Magnitude * Config.Props.CrushPushFactor, Config.Props.CrushMinPush)
				local dir = if velocity.Magnitude > 1 then velocity.Unit else hull.CFrame.LookVector
				PropCrusher.crush(model, dir * speed + Vector3.yAxis * speed * 0.3)
			end
		end
	end
end

function PropCrusher.start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= Config.Props.CrushInterval then
			elapsed = 0
			crushUnderTanks()
		end
	end)
end

return PropCrusher
