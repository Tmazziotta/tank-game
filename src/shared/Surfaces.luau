--!strict
-- What a tank is standing on and how that changes driving. A map part's Surface attribute
-- wins; otherwise its material decides (smooth terrain included). Shared: whoever
-- simulates a tank's physics (the driver's client, or the server for bots) applies it, and
-- the server uses the same probe for hazards like deep water.

local Config = require(script.Parent.Config)
local MapSchema = require(script.Parent.MapSchema)

export type Modifiers = { Speed: number, Accel: number, Brake: number?, Grip: number, Turn: number }

local Surfaces = {}

Surfaces.Attribute = "Surface" -- on ground patches: a Config.Surfaces.Kinds key
Surfaces.HazardAttribute = "Hazard" -- on hazard zones: "DeepWater" | "Mines"

local kinds: { [string]: Modifiers } = Config.Surfaces.Kinds :: any
local byMaterial: { [Enum.Material]: string } = Config.Surfaces.Materials :: any

-- Ground query: the arena folder and terrain only (not tanks, characters or effects).
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local filteredMap: Instance? = nil
local initialized = false

local function refreshParams()
	local map = workspace:FindFirstChild(MapSchema.MapFolder)
	if map ~= filteredMap or not initialized then
		initialized = true
		filteredMap = map
		params.FilterDescendantsInstances = if map then { map, workspace.Terrain } else { workspace.Terrain }
	end
end

-- The ground directly below `position` (within `depth` studs).
function Surfaces.ground(position: Vector3, depth: number): RaycastResult?
	refreshParams()
	return workspace:Raycast(position, Vector3.new(0, -depth, 0), params)
end

local function kindOf(result: RaycastResult?): string
	if not result then
		return "Normal"
	end
	local attribute = result.Instance:GetAttribute(Surfaces.Attribute)
	if type(attribute) == "string" and kinds[attribute] then
		return attribute
	end
	return byMaterial[result.Material] or "Normal"
end

-- Surface kind under a point (e.g. a hull center).
function Surfaces.kindAt(position: Vector3): string
	return kindOf(Surfaces.ground(position, Config.Surfaces.ProbeDepth))
end

function Surfaces.modifiers(kind: string): Modifiers
	return kinds[kind] or kinds.Normal
end

-- Hazard zone under a point, looking from well above it down to just below the ground.
-- Used for "is that spot ahead dangerous?" checks.
function Surfaces.hazardAt(position: Vector3): string?
	local result = Surfaces.ground(Vector3.new(position.X, position.Y + 20, position.Z), 30)
	if not result then
		return nil
	end
	local hazard = result.Instance:GetAttribute(Surfaces.HazardAttribute)
	return if type(hazard) == "string" then hazard else nil
end

return Surfaces
