--!strict
-- Town: the original arena. Three buildings of different sizes around an open square,
-- mid-range fights, a warehouse you can drive through. Crates and fences add soft cover.

local MapKit = require(script.Parent.Parent.MapKit)

local at = MapKit.at
local center = Vector3.new(0, 0, 20)

local props: { MapKit.Prop } = {}
MapKit.crates(props, 24, -32, 15)
MapKit.crates(props, -24, 95, -10)
MapKit.crates(props, 62, -10, 40)
MapKit.crates(props, -70, 60, 0)
MapKit.fence(props, -75, 112, -30, 112)
MapKit.fence(props, 30, 112, 75, 112)
MapKit.fence(props, -95, -20, -95, 40)
for _, p in { { -92, -70 }, { -88, 95 }, { 88, 100 }, { 95, -72 }, { 68, 128 }, { -60, -85 } } do
	MapKit.tree(props, p[1], p[2])
end

local map: MapKit.MapDef = {
	id = "Town",
	displayName = "Town",
	center = center,
	halfSize = Vector2.new(110, 122),
	groundColor = Color3.fromRGB(99, 95, 99),
	boundaryColor = Color3.fromRGB(120, 125, 150),
	wanderRadius = 90,
	-- Asymmetric map: teams swap sides every round, so both get each side.
	sides = {
		{ MapKit.spawn(0, -60, center), MapKit.spawn(-70, -45, center), MapKit.spawn(70, -45, center) },
		{ MapKit.spawn(0, 128, center), MapKit.spawn(-85, 120, center), MapKit.spawn(85, 120, center) },
	},
	buildings = {
		{
			spec = {
				name = "Hut",
				width = 4,
				depth = 4,
				floors = 3,
				color = Color3.fromRGB(255, 125, 105),
				roofColor = Color3.fromRGB(200, 80, 80),
				doorWidth = 1,
				doorHeight = 2,
				windows = true,
			},
			origin = at(-45, 5, -25),
		},
		{
			spec = {
				name = "Shop",
				width = 6,
				depth = 5,
				floors = 4,
				color = Color3.fromRGB(255, 205, 80),
				roofColor = Color3.fromRGB(230, 140, 60),
				doorWidth = 2,
				doorHeight = 2,
				windows = true,
			},
			origin = at(42, 15, 20),
		},
		{
			spec = {
				name = "Warehouse",
				width = 9,
				depth = 7,
				floors = 5,
				color = Color3.fromRGB(110, 175, 255),
				roofColor = Color3.fromRGB(70, 110, 200),
				doorWidth = 3, -- wide enough to drive a tank through
				doorHeight = 2,
				windows = true,
			},
			origin = at(0, 70, 0),
		},
	},
	cover = {
		{ size = Vector3.new(14, 6, 4), origin = at(-14, -20, 15) },
		{ size = Vector3.new(4, 6, 12), origin = at(18, -12, -10) },
		{ size = Vector3.new(10, 5, 10), origin = at(-28, 40, 0) },
		{ size = Vector3.new(12, 6, 4), origin = at(30, 50, -30) },
		{ size = Vector3.new(16, 4, 4), origin = at(0, 25, 0) },
	},
	props = props,
}

return map
