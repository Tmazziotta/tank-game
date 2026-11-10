--!strict
-- Town: three routes between the spawns, and a river across the middle that each route
-- crosses differently.
--   West, the park: muddy lawns, a tree grove and low stone walls; crosses the river at a
--     slow, exposed ford guarded by a minefield. Long sightlines for scoped shooting.
--   Center, the streets: fast cobbled roads lined with destructible buildings, crossing the
--     river on a single bridge (the chokepoint). Blast through a shop to open a new angle.
--   East, the ridge: a gravel climb onto a plateau where the river ends. Whoever holds it
--     sees down into the streets and the park, and can sit hull-down behind its rocks.
-- Mirrored across z = 0, so both sides get the same map.

local MapKit = require(script.Parent.Parent.MapKit)

local at = MapKit.at
local center = Vector3.new(0, 0, 0)

local STONE = Color3.fromRGB(160, 155, 150)
local CONCRETE = Color3.fromRGB(120, 125, 150)

local function building(name: string, x: number, z: number, yaw: number, w: number, d: number, floors: number, color: Color3, roof: Color3, door: number): MapKit.Building
	return {
		spec = {
			name = name,
			width = w,
			depth = d,
			floors = floors,
			color = color,
			roofColor = roof,
			doorWidth = door,
			doorHeight = 2,
			windows = true,
		},
		origin = at(x, z, yaw),
	}
end

-- South half --------------------------------------------------------------------------

local buildings: { MapKit.Building } = {
	-- Street frontage: doors face the main street (x = 0).
	building("Shop", -50, -150, -90, 6, 5, 3, Color3.fromRGB(255, 205, 80), Color3.fromRGB(230, 140, 60), 2),
	building("Hut", 48, -160, 90, 4, 4, 2, Color3.fromRGB(255, 125, 105), Color3.fromRGB(200, 80, 80), 1),
	building("Warehouse", -52, -70, -90, 8, 6, 3, Color3.fromRGB(110, 175, 255), Color3.fromRGB(70, 110, 200), 3),
	building("Bakery", 50, -85, 90, 5, 5, 3, Color3.fromRGB(240, 200, 170), Color3.fromRGB(150, 90, 70), 1),
	-- Park side wall: breakable, opens the park-to-street crossing.
	MapKit.wall(at(-95, -110, 90), 8, 2, Color3.fromRGB(190, 110, 90)),
}

local cover: { MapKit.Cover } = {}
-- Lane dividers: indestructible apartment blocks between the routes, with gaps to cross
-- (west: either side of the breakable park wall; east: by the ridge ramp).
local APARTMENT = Color3.fromRGB(175, 165, 190)
MapKit.block(cover, -100, -175, Vector3.new(26, 18, 40), APARTMENT, Enum.Material.Concrete)
MapKit.block(cover, -100, -45, Vector3.new(26, 18, 36), APARTMENT, Enum.Material.Concrete)
MapKit.block(cover, 105, -205, Vector3.new(26, 18, 30), APARTMENT, Enum.Material.Concrete)
MapKit.block(cover, 105, -150, Vector3.new(26, 18, 40), APARTMENT, Enum.Material.Concrete)
-- Spawn shields.
MapKit.block(cover, -60, -190, Vector3.new(20, 6, 5), CONCRETE)
MapKit.block(cover, 60, -190, Vector3.new(20, 6, 5), CONCRETE)
-- Park: low stone walls to duck behind (tank-high, so turrets peek over).
MapKit.block(cover, -185, -135, Vector3.new(34, 4, 4), STONE, Enum.Material.Cobblestone)
MapKit.block(cover, -150, -60, Vector3.new(4, 4, 30), STONE, Enum.Material.Cobblestone)
MapKit.block(cover, -215, -40, Vector3.new(26, 4, 4), STONE, Enum.Material.Cobblestone, 20)
-- Street: parked trucks and planters.
MapKit.block(cover, 14, -120, Vector3.new(8, 7, 16), CONCRETE, Enum.Material.DiamondPlate)
MapKit.block(cover, -24, -50, Vector3.new(8, 7, 16), CONCRETE, Enum.Material.DiamondPlate)
-- Ridge approach: rocks on the lane floor.
MapKit.rock(cover, 200, -170, Vector3.new(14, 9, 10), 25)
MapKit.rock(cover, 135, -140, Vector3.new(10, 8, 14), -15)
MapKit.rock(cover, 222, -140, Vector3.new(12, 10, 12), 40)

local props: { MapKit.Prop } = {}
MapKit.grove(props, -235, -115, 3, 3, 17, 11)
MapKit.fence(props, -135, -175, -135, -130)
MapKit.fence(props, -240, -75, -170, -75)
MapKit.crates(props, -75, -115, 10)
MapKit.crates(props, 22, -60, -20)
MapKit.crates(props, -20, -175, 30)
MapKit.crates(props, 70, -112, 5)
for _, p in { { 80, -212 }, { -100, -205 }, { 70, -130 }, { -40, -110 } } do
	MapKit.tree(props, p[1], p[2])
end

-- Ground: cobbled main street and cross street (fast), muddy park, gravel ridge climb,
-- sandy riverbanks.
local ground: { MapKit.Patch } = {}
MapKit.patch(ground, "Road", 0, -142, 26, 216)
MapKit.patch(ground, "Road", 2, -115, 180, 18)
MapKit.patch(ground, "Mud", -160, -100, 40, 40)
MapKit.patch(ground, "Mud", -190, -170, 45, 30)
MapKit.patch(ground, "Mud", -185, -28, 44, 20) -- churned-up ford approach
MapKit.patch(ground, "Gravel", 185, -150, 90, 70)
MapKit.patch(ground, "Sand", -227, -18, 46, 6)
MapKit.patch(ground, "Sand", -42, -18, 246, 6)

-- A minefield on the park's riverbank: rush the ford and you risk it.
local minefields: { MapKit.Minefield } = {}
MapKit.minefield(minefields, -130, -40, 30, 26, 9, 31)

local hills: { MapKit.Hill } = {}
MapKit.hill(hills, -205, -205, 40, 4) -- park mound

MapKit.mirror(buildings, center)
MapKit.mirror(cover, center)
MapKit.mirror(props, center)
MapKit.mirror(ground, center)
MapKit.mirror(minefields, center)
MapKit.mirror(hills, center)

-- Center line ----------------------------------------------------------------------------

-- The river: deep from the west wall to the foot of the ridge (drive in and you sink).
-- Three ways across: the park ford, the street bridge, or around the end via the ridge.
MapKit.patch(ground, "DeepWater", -85, 0, 330, 30)
MapKit.patch(ground, "Ford", -185, 0, 40, 32)
local crossings: { { Vector3 } } = {
	MapKit.bridge(cover, props, 0, 0, 24, 34),
	{ Vector3.new(-185, 0, -30), Vector3.new(-185, 0, 30) }, -- ford
	{ Vector3.new(105, 0, -45), Vector3.new(105, 0, 45) }, -- around the river's end, up the ridge
}
-- The ridge: 10 high, ramps from both spawns and from the street side; rocks on top give
-- hull-down positions at both crests.
MapKit.plateau(cover, 185, 0, 90, 110, 10, { "S", "N", "W" })
MapKit.rock(cover, 170, -45, Vector3.new(16, 15, 6), 5)
MapKit.rock(cover, 200, 45, Vector3.new(16, 15, 6), -5)
MapKit.rock(cover, 150, 10, Vector3.new(6, 15, 14), 10)

local map: MapKit.MapDef = {
	id = "Town",
	displayName = "Town",
	center = center,
	halfSize = Vector2.new(250, 250),
	groundColor = Color3.fromRGB(99, 95, 99),
	boundaryColor = Color3.fromRGB(120, 125, 150),
	wanderRadius = 200,
	sides = MapKit.sides({ { -40, -218 }, { 0, -225 }, { 40, -218 } }, center),
	buildings = buildings,
	cover = cover,
	props = props,
	ground = ground,
	minefields = minefields,
	terrain = {
		hills = hills,
		hillMaterial = Enum.Material.Grass,
		mountains = { height = 70, material = Enum.Material.Rock, peak = Enum.Material.Snow, seed = 3 },
		colors = { [Enum.Material.Grass] = Color3.fromRGB(90, 140, 75), [Enum.Material.Rock] = Color3.fromRGB(120, 118, 125) },
	},
	crossings = crossings,
}

return map
