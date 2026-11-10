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
local Surfaces = require(ReplicatedStorage.Shared.Surfaces)
local TerrainBuilder = require(script.Parent.TerrainBuilder)

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

-- Lift a ground-level placement onto the terrain at its position (sinking it slightly on a
-- slope so no gap shows under the downhill edge).
local function onGround(origin: CFrame, hasTerrain: boolean): CFrame
	if not hasTerrain then
		return origin
	end
	local y = TerrainBuilder.groundY(origin.Position.X, origin.Position.Z)
	return if y > 0 then origin + Vector3.new(0, y - 0.5, 0) else origin
end

local function buildCover(placement: MapKit.Cover, parent: Instance, hasTerrain: boolean)
	block(
		parent,
		"CoverBlock",
		placement.size,
		onGround(placement.origin, hasTerrain and placement.shape == nil) * CFrame.new(0, placement.size.Y / 2, 0),
		placement.color or Config.Maps.CoverColor,
		placement.material or Enum.Material.SmoothPlastic,
		placement.shape
	)
end

-- Thin, non-colliding ground patch (surface or water); queryable so probes see it.
local function buildPatch(patch: MapKit.Patch, parent: Instance)
	local style = MapKit.PatchStyles[patch.look]
	local part = Instance.new("Part")
	part.Name = patch.look
	part.Anchored = true
	part.CanCollide = style.slippery == true
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(patch.size.X, 0.2, patch.size.Y)
	if style.slippery then
		-- Zero friction that wins over the tank's own (high friction weight).
		part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	end
	local top = 0.04 * style.layer + 0.02
	part.CFrame = patch.origin * CFrame.new(0, top - 0.1, 0)
	part.Material = style.material
	part.Color = style.color
	part.Transparency = style.transparency or 0
	part.Reflectance = style.reflectance or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	if style.surface then
		part:SetAttribute(Surfaces.Attribute, style.surface)
	end
	if style.hazard then
		part:SetAttribute(Surfaces.HazardAttribute, style.hazard)
	end
	part:SetAttribute(MapSchema.IndestructibleAttribute, true)
	part.Parent = parent
end

local function decor(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

-- Warning sign facing away from `center`.
local function mineSign(parent: Instance, position: Vector3, center: Vector3)
	local outward = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	local facing = if outward.Magnitude > 1e-3 then outward.Unit else Vector3.zAxis
	local base = CFrame.lookAt(position, position + facing)
	decor(parent, Vector3.new(0.4, 5, 0.4), base * CFrame.new(0, 2.5, 0), Color3.fromRGB(120, 90, 60), Enum.Material.Wood)
	local board = decor(parent, Vector3.new(3.6, 2.2, 0.2), base * CFrame.new(0, 4.4, -0.3), Color3.fromRGB(240, 200, 40), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(200, 30, 30)
	label.Text = "MINES"
	label.Parent = gui
	gui.Parent = board
end

-- A marked zone with mines scattered inside; mines are queryable so shells can set them off.
local function buildMinefield(field: MapKit.Minefield, parent: Instance, hasTerrain: boolean)
	local zone = Instance.new("Folder")
	zone.Name = "Minefield"
	zone.Parent = parent
	buildPatch({ look = "Minefield", size = field.size, origin = field.origin }, zone)
	local hx, hz = field.size.X / 2, field.size.Y / 2
	local center = field.origin.Position
	for _, corner in { Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0, -hz), Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, hz) } do
		mineSign(zone, field.origin:PointToWorldSpace(corner * 1.04), center)
	end
	local rng = Random.new(field.seed)
	local placed: { Vector3 } = {}
	local spacing = Config.Hazards.MineSpacing
	local tries = 0
	while #placed < field.count and tries < field.count * 30 do
		tries += 1
		local local_ = Vector3.new(rng:NextNumber(-hx + 2, hx - 2), 0, rng:NextNumber(-hz + 2, hz - 2))
		local p = field.origin:PointToWorldSpace(local_)
		local ok = true
		for _, other in placed do
			if (other - p).Magnitude < spacing then
				ok = false
				break
			end
		end
		if ok then
			table.insert(placed, p)
			local y = if hasTerrain then TerrainBuilder.groundY(p.X, p.Z) else 0
			local mine = Instance.new("Part")
			mine.Name = "Mine"
			mine.Shape = Enum.PartType.Cylinder
			mine.Size = Vector3.new(0.7, 2.6, 2.6)
			mine.CFrame = CFrame.new(p.X, y + 0.25, p.Z) * CFrame.Angles(0, 0, math.pi / 2)
			mine.Color = Color3.fromRGB(70, 75, 60)
			mine.Material = Enum.Material.Metal
			mine.Anchored = true
			mine.CanCollide = false
			mine.CanTouch = false
			mine:SetAttribute(MapSchema.MineAttribute, true)
			mine.Parent = zone
		end
	end
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
	TerrainBuilder.build(def) -- first: everything else sits on it
	local hasTerrain = def.terrain ~= nil

	local map = Instance.new("Folder")
	map.Name = MapSchema.MapFolder

	local buildings = folder(map, MapSchema.BuildingsFolder)
	for i, placement in def.buildings do
		BuildingGenerator.build(placement.spec, placement.origin, i).Parent = buildings
	end

	local cover = folder(map, MapSchema.CoverFolder)
	for _, placement in def.cover do
		buildCover(placement, cover, hasTerrain)
	end
	buildBoundary(def, cover)

	local props = folder(map, MapSchema.PropsFolder)
	local rng = Random.new(#def.props)
	for _, prop in def.props do
		PropBuilder.build(prop.kind, onGround(prop.origin, hasTerrain), rng, prop.length).Parent = props
	end

	local ground = folder(map, MapSchema.GroundFolder)
	local patches: { MapKit.Patch } = def.ground or {}
	for _, patch in patches do
		buildPatch(patch, ground)
	end
	local minefields = folder(map, MapSchema.MinefieldsFolder)
	local fields: { MapKit.Minefield } = def.minefields or {}
	for _, field in fields do
		buildMinefield(field, minefields, hasTerrain)
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
