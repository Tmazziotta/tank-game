--!strict
-- Breaks building chunks around a blast point: destroys their welds, throws them outward,
-- lets under-supported chunks sag and fall, and releases anything left disconnected from
-- a foundation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingGenerator = require(script.Parent.BuildingGenerator)
local Config = require(ReplicatedStorage.Shared.Config)
local DebrisService = require(script.Parent.DebrisService)

local Destruction = {}

local function isChunk(part: BasePart): boolean
	return part:GetAttribute(BuildingGenerator.CHUNK_ATTRIBUTE) == true
end

local function release(part: BasePart)
	if part:CanSetNetworkOwnership() then
		-- Server simulates debris so impulses applied here take effect.
		part:SetNetworkOwner(nil)
	end
	DebrisService.add(part)
end

local function throw(part: BasePart, center: Vector3, radius: number, rng: Random)
	local offset = part.Position - center
	local distance = offset.Magnitude
	local direction = if distance > 1e-3 then offset.Unit else Vector3.yAxis
	direction = (direction + Vector3.yAxis * Config.Weapon.BlastUpwardBias).Unit
	local falloff = 1 - 0.5 * math.clamp(distance / radius, 0, 1)
	local speed = Config.Weapon.BlastImpulse * falloff
	local mass = part.AssemblyMass
	part:ApplyImpulse(direction * speed * mass)
	local spin = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 4
	part:ApplyAngularImpulse(spin * mass)
end

local function breakWelds(part: BasePart)
	for _, joint in part:GetJoints() do
		if joint:IsA("WeldConstraint") then
			joint:Destroy()
		end
	end
end

-- A chunk is supported if something is welded beneath it, or if enough neighbours still
-- hold it. Buildings are only ever yawed, so world Y is the building's vertical.
local function isSupported(part: BasePart): boolean
	local welds = 0
	local floor = part.Position.Y - 0.25 * part.Size.Y
	for _, joint in part:GetJoints() do
		if joint:IsA("WeldConstraint") then
			local other = if joint.Part0 == part then joint.Part1 else joint.Part0
			if other then
				if other.Position.Y < floor then
					return true
				end
				welds += 1
			end
		end
	end
	return welds >= Config.Destruction.MinWeldsWhenUnsupported
end

-- Repeatedly drop chunks that lost their support, so overhangs sag after a hit.
local function collapse(buildings: { [Instance]: boolean })
	for _ = 1, Config.Destruction.CollapsePasses do
		local falling: { BasePart } = {}
		for building in buildings do
			for _, child in building:GetChildren() do
				if child:IsA("BasePart") and isChunk(child) and not isSupported(child) then
					table.insert(falling, child)
				end
			end
		end
		if #falling == 0 then
			return
		end
		for _, part in falling do
			breakWelds(part)
			release(part)
		end
	end
end

-- `roots` are the containers whose chunks the blast may affect (buildings and debris).
function Destruction.blast(center: Vector3, radius: number, roots: { Instance })
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = roots
	local parts = workspace:GetPartBoundsInRadius(center, radius, params)

	local rng = Random.new()
	local touchedBuildings: { [Instance]: boolean } = {}
	local broken: { BasePart } = {}

	for _, part in parts do
		if not isChunk(part) then
			continue
		end
		local building = part.Parent
		if building and building ~= DebrisService.getFolder() then
			touchedBuildings[building] = true
		end
		breakWelds(part)
		table.insert(broken, part)
	end

	for _, part in broken do
		release(part)
		throw(part, center, radius, rng)
	end

	collapse(touchedBuildings)

	-- Anything no longer connected to an anchored foundation falls as well.
	for building in touchedBuildings do
		for _, child in building:GetChildren() do
			if child:IsA("BasePart") and isChunk(child) and not child:IsGrounded() then
				release(child)
			end
		end
	end
end

return Destruction
