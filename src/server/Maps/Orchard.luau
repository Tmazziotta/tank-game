--!strict
-- Orchard: three routes between the spawns.
--   West, the orchards: rows of fruit trees. Concealment, not cover: they hide you until
--     someone plows or shoots through them.
--   Center, the field: wide-open farmland around a low hill. The hill sees everything, and
--     everything sees the hill. Scope country.
--   East, the village: a barn, a farmhouse, a silo, fences and hay. Corners and short
--     sightlines.
-- Mirrored across z = 0, so both sides get the same map.

local MapKit = require(script.Parent.Parent.MapKit)

local at = MapKit.at
local center = Vector3.new(0, 0, 0)

local GRASS_HILL = Color3.fromRGB(95, 150, 75)
local SILO = Color3.fromRGB(200, 200, 205)

-- South half --------------------------------------------------------------------------

local cover: { MapKit.Cover } = {}
-- Spawn shields: hay-bale stacks (hard).
MapKit.block(cover, -55, -192, Vector3.new(18, 6, 6), Color3.fromRGB(220, 190, 110), Enum.Material.Fabric)
MapKit.block(cover, 55, -192, Vector3.new(18, 6, 6), Color3.fromRGB(220, 190, 110), Enum.Material.Fabric)
-- Lane dividers: hedgerows (hard, taller than a tank) with gaps to cross.
local HEDGE = Color3.fromRGB(60, 110, 55)
MapKit.block(cover, -95, -170, Vector3.new(6, 8, 44), HEDGE, Enum.Material.Grass)
MapKit.block(cover, -95, -90, Vector3.new(6, 8, 40), HEDGE, Enum.Material.Grass)
MapKit.block(cover, 100, -175, Vector3.new(6, 8, 50), HEDGE, Enum.Material.Grass)
MapKit.block(cover, 100, -80, Vector3.new(6, 8, 44), HEDGE, Enum.Material.Grass)
-- Field boulders.
MapKit.rock(cover, -45, -120, Vector3.new(14, 8, 10), 20)
MapKit.rock(cover, 50, -85, Vector3.new(12, 7, 9), -35)
MapKit.rock(cover, -10, -85, Vector3.new(10, 6, 14), 10)
-- Orchard: a stone well and a tool shed wall.
MapKit.rock(cover, -175, -95, Vector3.new(8, 6, 8), 0)
-- Village: silo.
MapKit.block(cover, 125, -60, Vector3.new(12, 24, 12), SILO, Enum.Material.Metal)

local buildings: { MapKit.Building } = {
	{
		spec = {
			name = "Barn",
			width = 7,
			depth = 6,
			floors = 3,
			color = Color3.fromRGB(200, 60, 55),
			roofColor = Color3.fromRGB(110, 70, 60),
			doorWidth = 3, -- drive-through
			doorHeight = 2,
			windows = false,
		},
		origin = at(185, -130, 0),
	},
	{
		spec = {
			name = "Farmhouse",
			width = 5,
			depth = 4,
			floors = 2,
			color = Color3.fromRGB(250, 240, 200),
			roofColor = Color3.fromRGB(70, 110, 160),
			doorWidth = 1,
			doorHeight = 1,
			windows = true,
		},
		origin = at(205, -45, 90),
	},
}

local props: { MapKit.Prop } = {}
-- Orchard rows.
MapKit.grove(props, -235, -175, 5, 3, 16, 21)
MapKit.grove(props, -235, -105, 4, 4, 16, 22)
MapKit.grove(props, -150, -150, 2, 3, 16, 23)
-- Field fences.
MapKit.fence(props, -95, -140, -95, -120) -- light gate in the hedge gap
MapKit.fence(props, -60, -150, 40, -150)
-- Village yard.
MapKit.fence(props, 150, -100, 230, -100)
MapKit.fence(props, 150, -20, 150, -70)
MapKit.crates(props, 160, -80, 15)
MapKit.crates(props, 230, -165, -20)
MapKit.crates(props, 170, -20, 40)
MapKit.crates(props, -120, -40, 0)

MapKit.mirrorCover(cover, center)
MapKit.mirrorBuildings(buildings, center)
MapKit.mirrorProps(props, center)

-- Center line ----------------------------------------------------------------------------

-- The hill: low and wide, ramps on all four sides. Two rocks on top for hull-down cover.
MapKit.plateau(cover, 0, 0, 70, 50, 6, { "S", "N", "W", "E" }, GRASS_HILL)
MapKit.rock(cover, -15, 0, Vector3.new(6, 10, 14), 5)
MapKit.rock(cover, 18, 6, Vector3.new(6, 10, 12), -10)
MapKit.grove(props, -230, -16, 3, 3, 16, 24)
MapKit.fence(props, 150, 0, 240, 0)

local map: MapKit.MapDef = {
	id = "Orchard",
	displayName = "Orchard",
	center = center,
	halfSize = Vector2.new(250, 250),
	groundColor = Color3.fromRGB(105, 165, 85),
	boundaryColor = Color3.fromRGB(150, 115, 85),
	wanderRadius = 200,
	sides = MapKit.sides({ { -40, -218 }, { 0, -225 }, { 40, -218 } }, center),
	buildings = buildings,
	cover = cover,
	props = props,
}

return map
