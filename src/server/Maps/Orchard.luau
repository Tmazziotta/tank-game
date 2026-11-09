--!strict
-- Orchard: a wide-open farm field with long sightlines. Two tree groves and fence lines
-- give concealment that melts under fire; a barn, a farmhouse and a few big boulders are
-- the only real cover. Rewards fast flanking and long-range shooting.

local MapKit = require(script.Parent.Parent.MapKit)

local at = MapKit.at
local center = Vector3.new(0, 0, 0)

local ROCK = Color3.fromRGB(140, 140, 150)

local function boulder(x: number, z: number, size: Vector3, yaw: number): MapKit.Cover
	return { size = size, origin = at(x, z, yaw), color = ROCK, material = Enum.Material.Slate }
end

local props: { MapKit.Prop } = {}
MapKit.grove(props, 40, -88, 4, 4, 16, 1) -- north-east grove
MapKit.grove(props, -88, 40, 4, 4, 16, 2) -- south-west grove
MapKit.fence(props, -100, 22, -30, 22)
MapKit.fence(props, 30, -22, 100, -22)
MapKit.fence(props, 22, 30, 22, 100)
MapKit.fence(props, -22, -100, -22, -30)
MapKit.crates(props, 30, 40, 20) -- hay-yard by the farmhouse
MapKit.crates(props, -40, -30, -15) -- by the barn door

local map: MapKit.MapDef = {
	id = "Orchard",
	displayName = "Orchard",
	center = center,
	halfSize = Vector2.new(128, 128),
	groundColor = Color3.fromRGB(105, 165, 85),
	boundaryColor = Color3.fromRGB(150, 115, 85),
	wanderRadius = 110,
	spawns = {
		MapKit.spawn(112, 0, center),
		MapKit.spawn(-112, 0, center),
		MapKit.spawn(0, 112, center),
		MapKit.spawn(0, -112, center),
		MapKit.spawn(100, 100, center),
		MapKit.spawn(-100, -100, center),
	},
	buildings = {
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
			origin = CFrame.lookAt(Vector3.new(-58, 0, -58), Vector3.zero),
		},
		{
			spec = {
				name = "Farmhouse",
				width = 4,
				depth = 4,
				floors = 2,
				color = Color3.fromRGB(250, 240, 200),
				roofColor = Color3.fromRGB(70, 110, 160),
				doorWidth = 1,
				doorHeight = 1,
				windows = true,
			},
			origin = CFrame.lookAt(Vector3.new(60, 0, 60), Vector3.zero),
		},
	},
	cover = {
		boulder(-9, 6, Vector3.new(14, 8, 10), 20),
		boulder(10, -7, Vector3.new(12, 7, 9), -35),
		boulder(-72, 8, Vector3.new(10, 6, 14), 10),
		boulder(74, -8, Vector3.new(10, 6, 14), -10),
		boulder(8, 72, Vector3.new(14, 6, 10), 30),
		boulder(-8, -74, Vector3.new(14, 6, 10), -30),
	},
	props = props,
}

return map
