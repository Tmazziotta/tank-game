--!strict
-- Dockyard: a tight grid of indestructible shipping containers. Two container rows split
-- the yard into three bands; breakable brick walls seal the gaps in those rows, so the
-- only open routes are the narrow edge lanes until someone blasts a flank open. Short
-- sightlines, crate piles everywhere: a brawler's map.

local MapKit = require(script.Parent.Parent.MapKit)

local at = MapKit.at
local center = Vector3.new(0, 0, 0)

local RED = Color3.fromRGB(225, 85, 75)
local BLUE = Color3.fromRGB(70, 130, 220)
local ORANGE = Color3.fromRGB(245, 150, 60)
local TEAL = Color3.fromRGB(60, 180, 170)
local BRICK = Color3.fromRGB(190, 110, 90)

-- 24 x 8 x 8 container lying along X (yaw 90 for along Z).
local function container(x: number, z: number, color: Color3, yaw: number?): MapKit.Cover
	return { size = Vector3.new(24, 8, 8), origin = at(x, z, yaw), color = color, material = Enum.Material.DiamondPlate }
end

local cover: { MapKit.Cover } = {
	-- North and south rows: containers with 26-stud gaps, sealed by brick walls below.
	container(-50, -32, RED),
	container(0, -32, BLUE),
	container(50, -32, ORANGE),
	container(-50, 32, TEAL),
	container(0, 32, RED),
	container(50, 32, BLUE),
	-- Middle band: short stacks to fight around.
	container(-38, 0, ORANGE, 90),
	container(38, 0, TEAL, 90),
	-- Spawn-side shields.
	{ size = Vector3.new(16, 6, 4), origin = at(-30, -62), color = BLUE, material = Enum.Material.DiamondPlate },
	{ size = Vector3.new(16, 6, 4), origin = at(30, -62), color = RED, material = Enum.Material.DiamondPlate },
	{ size = Vector3.new(16, 6, 4), origin = at(-30, 62), color = ORANGE, material = Enum.Material.DiamondPlate },
	{ size = Vector3.new(16, 6, 4), origin = at(30, 62), color = TEAL, material = Enum.Material.DiamondPlate },
}

local buildings: { MapKit.Building } = {
	-- Gap walls: 6 chunks (24 studs) fill each 26-stud gap; 2 rows tall, so tanks can't see over.
	MapKit.wall(at(-25, -32), 6, 2, BRICK),
	MapKit.wall(at(25, -32), 6, 2, BRICK),
	MapKit.wall(at(-25, 32), 6, 2, BRICK),
	MapKit.wall(at(25, 32), 6, 2, BRICK),
	{
		spec = {
			name = "Office",
			width = 4,
			depth = 3,
			floors = 2,
			color = Color3.fromRGB(240, 235, 220),
			roofColor = Color3.fromRGB(110, 120, 140),
			doorWidth = 2,
			doorHeight = 1,
			windows = true,
		},
		origin = at(0, 0, 90),
	},
}

local props: { MapKit.Prop } = {}
for _, p in { { -62, 0 }, { 62, 0 }, { -18, 14 }, { 18, -14 }, { -72, -52 }, { 72, 52 }, { -8, -52 }, { 8, 52 }, { 70, -48 }, { -70, 48 } } do
	MapKit.crates(props, p[1], p[2], (p[1] * 7) % 45)
end

local map: MapKit.MapDef = {
	id = "Dockyard",
	displayName = "Dockyard",
	center = center,
	halfSize = Vector2.new(84, 84),
	groundColor = Color3.fromRGB(120, 125, 135),
	boundaryColor = Color3.fromRGB(80, 90, 110),
	wanderRadius = 60,
	sides = {
		{ MapKit.spawn(-55, -72, center), MapKit.spawn(0, -72, center), MapKit.spawn(55, -72, center) },
		{ MapKit.spawn(-55, 72, center), MapKit.spawn(0, 72, center), MapKit.spawn(55, 72, center) },
	},
	buildings = buildings,
	cover = cover,
	props = props,
}

return map
