--!strict
-- Builds the arena (destructible buildings + indestructible cover) and rebuilds it from
-- scratch on RoundReset.

local BuildingGenerator = require(script.Parent.BuildingGenerator)
local DebrisService = require(script.Parent.DebrisService)
local MapLayout = require(script.Parent.MapLayout)

local MapService = {}

local MAP_NAME = "Map"
local COVER_COLOR = Color3.fromRGB(95, 105, 140)

local function findMap(): Folder?
	local map = workspace:FindFirstChild(MAP_NAME)
	return if map and map:IsA("Folder") then map else nil
end

local function buildCover(placement: MapLayout.CoverPlacement, parent: Instance)
	local block = Instance.new("Part")
	block.Name = "CoverBlock"
	block.Anchored = true
	block.Size = placement.size
	block.CFrame = placement.origin * CFrame.new(0, placement.size.Y / 2, 0)
	block.Color = COVER_COLOR
	block.Material = Enum.Material.SmoothPlastic
	block.TopSurface = Enum.SurfaceType.Smooth
	block:SetAttribute("Indestructible", true)
	block.Parent = parent
end

-- Folder holding destructible buildings, for blast queries.
function MapService.getBuildingsFolder(): Folder?
	local map = findMap()
	local buildings = map and map:FindFirstChild("Buildings")
	return if buildings and buildings:IsA("Folder") then buildings else nil
end

-- Destroy the current map and all debris, then build a fresh one.
function MapService.RoundReset()
	local old = findMap()
	if old then
		old:Destroy()
	end
	DebrisService.clear()

	local map = Instance.new("Folder")
	map.Name = MAP_NAME

	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = map
	for i, placement in MapLayout.Buildings do
		BuildingGenerator.build(placement.spec, placement.origin, i).Parent = buildings
	end

	local cover = Instance.new("Folder")
	cover.Name = "Cover"
	cover.Parent = map
	for _, placement in MapLayout.Cover do
		buildCover(placement, cover)
	end

	map.Parent = workspace
end

return MapService
