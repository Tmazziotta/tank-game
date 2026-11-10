--!strict
-- Builds the current arena (destructible buildings and walls, indestructible cover and
-- boundary, crushable props) and rebuilds it from scratch on RoundReset. Maps rotate in
-- Config.Maps.Rotation order via `advance`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingGenerator = require(script.Parent.BuildingGenerator)
local Config = require(ReplicatedStorage.Shared.Config)
local DebrisService = require(script.Parent.DebrisService)
local MapKit = require(script.Parent.MapKit)
local MapSchema = require(ReplicatedStorage.Shared.MapSchema)
local Maps = require(script.Parent.Maps)
local PropBuilder = require(script.Parent.PropBuilder)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)

local MapService = {}

local rotationIndex = 1
local current: MapKit.MapDef = Maps[Config.Maps.Rotation[1]]

local function findMap(): Folder?
	local map = workspace:FindFirstChild(MapSchema.MapFolder)
	return if map and map:IsA("Folder") then map else nil
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: MapKit.Shape?)
	local part: BasePart = if shape == "Wedge"
		then Instance.new("WedgePart")
		elseif shape == "CornerWedge" then Instance.new("CornerWedgePart")
		else Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part:SetAttribute(MapSchema.IndestructibleAttribute, true)
	part.Parent = parent
end

local function buildCover(placement: MapKit.Cover, parent: Instance)
	block(
		parent,
		"CoverBlock",
		placement.size,
		placement.origin * CFrame.new(0, placement.size.Y / 2, 0),
		placement.color or Config.Maps.CoverColor,
		placement.material or Enum.Material.SmoothPlastic,
		placement.shape
	)
end

-- Four walls whose inner faces sit at the map's half-size.
local function buildBoundary(def: MapKit.MapDef, parent: Instance)
	local h, t = Config.Maps.BoundaryHeight, Config.Maps.BoundaryThickness
	local hx, hz = def.halfSize.X, def.halfSize.Y
	local c = def.center
	local y = h / 2
	for _, side in { -1, 1 } do
		block(parent, "Boundary", Vector3.new(t, h, 2 * (hz + t)), CFrame.new(c.X + side * (hx + t / 2), y, c.Z), def.boundaryColor, Enum.Material.SmoothPlastic)
		block(parent, "Boundary", Vector3.new(2 * hx, h, t), CFrame.new(c.X, y, c.Z + side * (hz + t / 2)), def.boundaryColor, Enum.Material.SmoothPlastic)
	end
end

local function build(def: MapKit.MapDef)
	local old = findMap()
	if old then
		old:Destroy()
	end
	DebrisService.clear()

	local map = Instance.new("Folder")
	map.Name = MapSchema.MapFolder

	local buildings = folder(map, MapSchema.BuildingsFolder)
	for i, placement in def.buildings do
		BuildingGenerator.build(placement.spec, placement.origin, i).Parent = buildings
	end

	local cover = folder(map, MapSchema.CoverFolder)
	for _, placement in def.cover do
		buildCover(placement, cover)
	end
	buildBoundary(def, cover)

	local props = folder(map, MapSchema.PropsFolder)
	local rng = Random.new(#def.props)
	for _, prop in def.props do
		PropBuilder.build(prop.kind, prop.origin, rng, prop.length).Parent = props
	end

	-- The ground: sized to the map plus a margin, so no map runs off the edge of the world.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		local margin = Config.Maps.GroundMargin
		baseplate.Color = def.groundColor
		baseplate.Size = Vector3.new(2 * (def.halfSize.X + margin), 20, 2 * (def.halfSize.Y + margin))
		baseplate.CFrame = CFrame.new(def.center.X, -10, def.center.Z)
	end

	map.Parent = workspace
	ReplicatedStorage:SetAttribute(RoundSchema.MapAttribute, def.displayName)
end

function MapService.current(): MapKit.MapDef
	return current
end

-- Folder holding destructible buildings, for blast queries.
function MapService.getBuildingsFolder(): Folder?
	local map = findMap()
	local buildings = map and map:FindFirstChild(MapSchema.BuildingsFolder)
	return if buildings and buildings:IsA("Folder") then buildings else nil
end

-- Folder holding intact crushable props.
function MapService.getPropsFolder(): Folder?
	local map = findMap()
	local props = map and map:FindFirstChild(MapSchema.PropsFolder)
	return if props and props:IsA("Folder") then props else nil
end

-- Destroy the current map and all debris, then build the current map fresh.
function MapService.RoundReset()
	build(current)
end

-- Switch to the next map in the rotation and build it.
function MapService.advance()
	local rotation = Config.Maps.Rotation
	rotationIndex = rotationIndex % #rotation + 1
	current = Maps[rotation[rotationIndex]]
	build(current)
end

-- Studio testing: jump straight to a map by id.
function MapService.load(id: string): boolean
	local def = Maps[id]
	if not def then
		return false
	end
	current = def
	rotationIndex = table.find(Config.Maps.Rotation, id) or rotationIndex
	build(current)
	return true
end

return MapService
