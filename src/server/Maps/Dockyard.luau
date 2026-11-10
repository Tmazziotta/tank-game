--!strict
-- Dockyard: three routes between the spawns.
--   West, the quay: a long asphalt dock (fast) with crane legs and bollards along the harbor
--     edge; drive off it and you sink. A flooded dry dock cuts it in half: cross on the
--     bridge or squeeze past the end. Long sightlines down the waterfront.
--   Center, the container stacks: a maze of indestructible containers with brick walls
--     sealing some gaps, and oil slicks that send tanks sliding. Close-quarters brawling.
--   East, the warehouses: a gravel yard with two big sheds per side you can shoot your way
--     through, and a raised loading dock in the middle of the lane.
-- Mirrored across z = 0, so both sides get the same map.

local MapKit = require(script.Parent.Parent.MapKit)

local at = MapKit.at
local center = Vector3.new(0, 0, 0)

local RED = Color3.fromRGB(225, 85, 75)
local BLUE = Color3.fromRGB(70, 130, 220)
local ORANGE = Color3.fromRGB(245, 150, 60)
local TEAL = Color3.fromRGB(60, 180, 170)
local BRICK = Color3.fromRGB(190, 110, 90)
local STEEL = Color3.fromRGB(230, 190, 60)
local CONCRETE = Color3.fromRGB(150, 150, 155)

-- Shipping container lying along X (yaw 90 for along Z); `stack` 2 for a double stack.
local function container(list: { MapKit.Cover }, x: number, z: number, color: Color3, yaw: number?, stack: number?)
	MapKit.block(list, x, z, Vector3.new(24, 8 * (stack or 1), 8), color, Enum.Material.DiamondPlate, yaw)
end

local function warehouse(x: number, z: number): MapKit.Building
	return {
		spec = {
			name = "Shed",
			width = 9,
			depth = 6,
			floors = 3,
			color = Color3.fromRGB(200, 205, 215),
			roofColor = Color3.fromRGB(120, 130, 150),
			doorWidth = 3, -- tank-wide: drive in, blast out the back
			doorHeight = 2,
			windows = true,
		},
		origin = at(x, z, 0), -- door faces south
	}
end

-- South half --------------------------------------------------------------------------

local cover: { MapKit.Cover } = {}
-- Spawn shields.
container(cover, -55, -190, BLUE)
container(cover, 55, -190, RED)
-- Quay: crane legs and bollards.
for _, z in { -150, -70 } do
	MapKit.block(cover, -215, z, Vector3.new(6, 30, 6), STEEL, Enum.Material.Metal)
	MapKit.block(cover, -175, z, Vector3.new(6, 30, 6), STEEL, Enum.Material.Metal)
end
for _, z in { -195, -115, -35 } do
	MapKit.block(cover, -226, z, Vector3.new(4, 3, 4), CONCRETE, Enum.Material.Metal)
end
container(cover, -150, -110, TEAL, 90, 2)
container(cover, -190, -52, ORANGE)
-- Container stacks: rows across the lane with gaps; some gaps sealed by brick walls.
container(cover, -75, -140, RED)
container(cover, -20, -140, ORANGE, nil, 2)
container(cover, 45, -140, TEAL)
container(cover, -55, -95, BLUE, 90)
container(cover, 10, -100, RED, 90, 2)
container(cover, 70, -90, ORANGE, 90)
container(cover, -80, -45, TEAL)
container(cover, -25, -50, BLUE)
container(cover, 40, -45, RED, nil, 2)
-- Lane dividers: double-stacked container walls along the lanes, with gaps to cross.
for _, z in { -185, -160, -55, -30 } do
	container(cover, -110, z, BLUE, 90, 2)
end
for _, z in { -200, -176, -60, -36 } do
	container(cover, 125, z, ORANGE, 90, 2)
end
container(cover, 125, -120, TEAL, 90)
-- More of the maze.
container(cover, -75, -165, TEAL, 90)
container(cover, 80, -180, BLUE, 90)
container(cover, -10, -175, RED)
container(cover, 85, -30, TEAL, 90)
-- East lane: rows of pallets (hard, low) between the sheds.
MapKit.block(cover, 135, -110, Vector3.new(4, 5, 24), CONCRETE, Enum.Material.WoodPlanks)
MapKit.block(cover, 230, -60, Vector3.new(4, 5, 24), CONCRETE, Enum.Material.WoodPlanks)

local buildings: { MapKit.Building } = {
	MapKit.wall(at(12, -140), 7, 2, BRICK),
	MapKit.wall(at(-52, -45), 5, 2, BRICK),
	MapKit.wall(at(-110, -95, 90), 6, 2, BRICK), -- quay-to-stacks crossing
	warehouse(185, -150),
	warehouse(185, -80),
}

local props: { MapKit.Prop } = {}
for _, p in { { -190, -170 }, { -160, -40 }, { -230, -85 }, { -45, -115 }, { 40, -70 }, { 95, -170 }, { 140, -40 }, { 225, -30 }, { -40, -120 } } do
	MapKit.crates(props, p[1], p[2], (p[1] * 7) % 45)
end
MapKit.fence(props, 110, -200, 110, -120)

-- Ground: asphalt quay (fast), oil slicks in the maze (no grip), gravel yard.
local ground: { MapKit.Patch } = {}
MapKit.patch(ground, "Road", -172, -134, 120, 228)
MapKit.patch(ground, "Oil", 0, -72, 36, 26)
MapKit.patch(ground, "Oil", 60, -118, 26, 30, 30)
MapKit.patch(ground, "Gravel", 185, -115, 110, 200)

MapKit.mirror(cover, center)
MapKit.mirror(buildings, center)
MapKit.mirror(props, center)
MapKit.mirror(ground, center)

-- Center line ----------------------------------------------------------------------------

container(cover, -150, 0, BLUE, nil, 2)
container(cover, -30, 0, ORANGE, 90, 2)
container(cover, 30, 0, TEAL, 90)
-- The harbor: deep water along the west edge, and a flooded dry dock cutting into the quay.
MapKit.patch(ground, "DeepWater", -241, 0, 18, 500)
MapKit.patch(ground, "DeepWater", -214, 0, 72, 36)
local crossings: { { Vector3 } } = {
	MapKit.bridge(cover, props, -205, 0, 22, 40),
	{ Vector3.new(-170, 0, -30), Vector3.new(-170, 0, 30) }, -- past the dry dock's end
}
-- Loading dock: raised slab in the east lane, ramps at both ends.
MapKit.plateau(cover, 185, 0, 70, 50, 5, { "S", "N" }, CONCRETE)
container(cover, 175, 0, RED, 90) -- cover on the dock

local map: MapKit.MapDef = {
	id = "Dockyard",
	displayName = "Dockyard",
	center = center,
	halfSize = Vector2.new(250, 250),
	groundColor = Color3.fromRGB(120, 125, 135),
	boundaryColor = Color3.fromRGB(80, 90, 110),
	wanderRadius = 200,
	sides = MapKit.sides({ { -30, -218 }, { 0, -225 }, { 30, -218 } }, center),
	buildings = buildings,
	cover = cover,
	props = props,
	ground = ground,
	crossings = crossings,
}

return map
