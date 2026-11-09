--!strict
-- Static level data: where things go. Building code lives elsewhere.

local BuildingGenerator = require(script.Parent.BuildingGenerator)

export type BuildingPlacement = {
	spec: BuildingGenerator.BuildingSpec,
	origin: CFrame, -- ground-level center; the door faces this CFrame's LookVector
}

export type CoverPlacement = {
	size: Vector3,
	origin: CFrame, -- ground-level center
}

local MapLayout = {}

local CENTER = Vector3.new(0, 0, 20)
MapLayout.Center = CENTER

local function facingCenter(x: number, z: number): CFrame
	local pos = Vector3.new(x, 0.1, z)
	return CFrame.lookAt(pos, Vector3.new(CENTER.X, pos.Y, CENTER.Z))
end

local function ground(x: number, z: number, yawDegrees: number): CFrame
	return CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yawDegrees), 0)
end

MapLayout.SpawnPoints = {
	facingCenter(0, -60),
	facingCenter(-70, -45),
	facingCenter(70, -45),
	facingCenter(0, 130),
}

MapLayout.Buildings = {
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
		origin = ground(-45, 5, -25),
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
		origin = ground(42, 15, 20),
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
		origin = ground(0, 70, 0),
	},
} :: { BuildingPlacement }

MapLayout.Cover = {
	{ size = Vector3.new(14, 6, 4), origin = ground(-14, -20, 15) },
	{ size = Vector3.new(4, 6, 12), origin = ground(18, -12, -10) },
	{ size = Vector3.new(10, 5, 10), origin = ground(-28, 40, 0) },
	{ size = Vector3.new(12, 6, 4), origin = ground(30, 50, -30) },
	{ size = Vector3.new(16, 4, 4), origin = ground(0, 25, 0) },
} :: { CoverPlacement }

return MapLayout
