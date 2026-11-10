--!strict
-- Types and placement helpers for map definitions (src/server/Maps). A map is plain data;
-- MapService builds it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingGenerator = require(script.Parent.BuildingGenerator)
local Config = require(ReplicatedStorage.Shared.Config)
local PropBuilder = require(script.Parent.PropBuilder)

export type Building = {
	spec: BuildingGenerator.BuildingSpec,
	origin: CFrame, -- ground-level center; the door (or wall face) faces its LookVector
}

export type Cover = {
	size: Vector3,
	origin: CFrame, -- ground-level center
	color: Color3?,
	material: Enum.Material?,
	shape: Shape?, -- default: a box
}

-- Wedge: a ramp rising toward the origin's +Z. CornerWedge: a pyramid corner peaking over
-- the origin's local (+X, -Z) corner.
export type Shape = "Wedge" | "CornerWedge"

export type Prop = {
	kind: PropBuilder.Kind,
	origin: CFrame,
	length: number?, -- fence pieces only
}

-- Thin ground patch: changes the surface (mud, gravel...), or is water. Doesn't collide.
export type Patch = {
	look: PatchLook,
	size: Vector2, -- X, Z
	origin: CFrame, -- ground-level center
}

-- Minefield: a marked zone with `count` mines scattered inside it.
export type Minefield = {
	size: Vector2,
	origin: CFrame,
	count: number,
	seed: number,
}

-- Gentle terrain hill: a smooth bump `height` tall, `radius` wide.
export type Hill = {
	origin: CFrame,
	radius: number,
	height: number,
}

export type TerrainDef = {
	hills: { Hill },
	hillMaterial: Enum.Material,
	mountains: { height: number, material: Enum.Material, peak: Enum.Material?, seed: number }?,
	colors: { [Enum.Material]: Color3 }?,
}

-- Looks for ground patches: material, color, and what they do.
export type PatchLook = "Mud" | "Gravel" | "Road" | "Sand" | "Ice" | "Oil" | "Ford" | "DeepWater" | "Minefield"

export type PatchStyle = {
	material: Enum.Material,
	color: Color3,
	surface: string?, -- Config.Surfaces.Kinds key (else the material decides)
	hazard: string?,
	transparency: number?,
	reflectance: number?,
	layer: number, -- higher layers sit on top where patches overlap
	-- Solid and frictionless: tanks ride on it and slide (ice, oil). Other patches are
	-- non-colliding decals over the ground, so ground friction still applies there.
	slippery: boolean?,
}

export type MapDef = {
	id: string,
	displayName: string,
	center: Vector3,
	halfSize: Vector2, -- boundary half-extents (X, Z) around center
	groundColor: Color3,
	boundaryColor: Color3,
	wanderRadius: number, -- bots roam this far from center when idle
	sides: { { CFrame } }, -- two team sides, each with at least Config.Round.TeamSize spawns
	buildings: { Building }, -- destructible (buildings and free-standing walls)
	cover: { Cover }, -- indestructible
	props: { Prop }, -- crushable
	ground: { Patch }?, -- surfaces and water
	minefields: { Minefield }?,
	terrain: TerrainDef?,
	-- Routes across deep water for bots: each is a list of points to drive through in order
	-- (either direction), e.g. both ends of a bridge.
	crossings: { { Vector3 } }?,
}

local MapKit = {}

MapKit.PatchStyles = {
	Mud = { material = Enum.Material.Mud, color = Color3.fromRGB(100, 75, 50), layer = 1 },
	Gravel = { material = Enum.Material.Pebble, color = Color3.fromRGB(160, 155, 145), layer = 1 },
	Road = { material = Enum.Material.Cobblestone, color = Color3.fromRGB(135, 130, 125), layer = 2 },
	Sand = { material = Enum.Material.Sand, color = Color3.fromRGB(215, 195, 140), layer = 1 },
	Ice = { material = Enum.Material.Ice, color = Color3.fromRGB(185, 220, 245), layer = 1, slippery = true },
	Oil = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(25, 25, 32), surface = "Ice", reflectance = 0.35, layer = 2, slippery = true },
	Ford = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(95, 170, 210), surface = "Ford", transparency = 0.2, reflectance = 0.15, layer = 4 },
	DeepWater = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(30, 85, 150), surface = "Ford", hazard = "DeepWater", transparency = 0.05, reflectance = 0.25, layer = 3 },
	Minefield = { material = Enum.Material.Ground, color = Color3.fromRGB(115, 95, 70), hazard = "Mines", layer = 1 },
} :: { [PatchLook]: PatchStyle }

local GROUND = Color3.fromRGB(150, 140, 120)

-- Ground-level CFrame at (x, z), yawed.
function MapKit.at(x: number, z: number, yawDegrees: number?): CFrame
	return CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
end

-- Spawn at (x, z) facing `center`.
function MapKit.spawn(x: number, z: number, center: Vector3): CFrame
	local position = Vector3.new(x, 0.1, z)
	return CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
end

-- Ramp of `height` rising toward the origin's +Z, at the steepest angle tanks can climb.
-- `x, z` is the center of its footprint.
function MapKit.ramp(x: number, z: number, width: number, height: number, yawDegrees: number, color: Color3?): Cover
	local length = height / math.tan(Config.Maps.MaxRampAngle)
	return {
		size = Vector3.new(width, height, length),
		origin = MapKit.at(x, z, yawDegrees),
		color = color or GROUND,
		material = Enum.Material.Ground,
		shape = "Wedge",
	}
end

export type Side = "N" | "S" | "E" | "W" -- N = +Z, E = +X

-- Raised, indestructible plateau (w along X, d along Z) with ramps on the given sides.
-- Each ramp spans its whole side, so the shape has no inside corners for tanks to wedge in.
-- High ground: tanks on top see over cover and can sit back from the edge, showing
-- only the turret over the crest.
function MapKit.plateau(list: { Cover }, x: number, z: number, w: number, d: number, h: number, ramps: { Side }, color: Color3?)
	local c = color or GROUND
	table.insert(list, { size = Vector3.new(w, h, d), origin = MapKit.at(x, z), color = c, material = Enum.Material.Ground })
	local length = h / math.tan(Config.Maps.MaxRampAngle)
	for _, side in ramps do
		if side == "S" then
			table.insert(list, MapKit.ramp(x, z - d / 2 - length / 2, w, h, 0, c))
		elseif side == "N" then
			table.insert(list, MapKit.ramp(x, z + d / 2 + length / 2, w, h, 180, c))
		elseif side == "W" then
			table.insert(list, MapKit.ramp(x - w / 2 - length / 2, z, d, h, 90, c))
		else
			table.insert(list, MapKit.ramp(x + w / 2 + length / 2, z, d, h, -90, c))
		end
	end
	-- Where two ramps meet, fill the notch between them with a corner piece that blends
	-- both slopes (otherwise it's an inside corner tanks get wedged in).
	local has: { [string]: boolean } = {}
	for _, side in ramps do
		has[side] = true
	end
	-- { z side, x side, corner x sign, corner z sign, yaw that points the peak inward }
	local corners: { { any } } = { { "S", "W", -1, -1, -90 }, { "S", "E", 1, -1, 180 }, { "N", "W", -1, 1, 0 }, { "N", "E", 1, 1, 90 } }
	for _, corner in corners do
		if has[corner[1]] and has[corner[2]] then
			local sx: number, sz: number = corner[3], corner[4]
			table.insert(list, {
				size = Vector3.new(length, h, length),
				origin = MapKit.at(x + sx * (w / 2 + length / 2), z + sz * (d / 2 + length / 2), corner[5]),
				color = c,
				material = Enum.Material.Ground,
				shape = "CornerWedge" :: Shape,
			})
		end
	end
end

-- Rock: a chunky indestructible block, slightly rotated.
function MapKit.rock(list: { Cover }, x: number, z: number, size: Vector3, yawDegrees: number)
	table.insert(list, {
		size = size,
		origin = MapKit.at(x, z, yawDegrees),
		color = Color3.fromRGB(140, 140, 150),
		material = Enum.Material.Slate,
	})
end

-- Mirror symmetry: append a copy of every entry reflected across the line z = center.Z,
-- so both team sides get the same layout (lanes stay on the same X for both teams). Build
-- the south half, mirror it, then add anything that sits on the center line.
local function reflected(origin: CFrame, center: Vector3): CFrame
	local p = origin.Position
	local look = origin.LookVector
	local position = Vector3.new(p.X, p.Y, 2 * center.Z - p.Z)
	return CFrame.lookAt(position, position + Vector3.new(look.X, 0, -look.Z))
end

function MapKit.mirror<T>(list: { T }, center: Vector3)
	for i = 1, #list do
		local copy: any = table.clone(list[i] :: any)
		copy.origin = reflected(copy.origin, center)
		table.insert(list, copy)
	end
end

-- Spawns for both sides: `south` are (x, z) points on the -Z side; side 2 mirrors them.
function MapKit.sides(south: { { number } }, center: Vector3): { { CFrame } }
	local a, b = {}, {}
	for _, point in south do
		table.insert(a, MapKit.spawn(point[1], point[2], center))
		table.insert(b, MapKit.spawn(point[1], 2 * center.Z - point[2], center))
	end
	return { a, b }
end

-- A block of hard cover.
function MapKit.block(list: { Cover }, x: number, z: number, size: Vector3, color: Color3, material: Enum.Material?, yawDegrees: number?)
	table.insert(list, { size = size, origin = MapKit.at(x, z, yawDegrees), color = color, material = material })
end

function MapKit.patch(list: { Patch }, look: PatchLook, x: number, z: number, w: number, d: number, yawDegrees: number?)
	table.insert(list, { look = look, size = Vector2.new(w, d), origin = MapKit.at(x, z, yawDegrees) })
end

function MapKit.minefield(list: { Minefield }, x: number, z: number, w: number, d: number, count: number, seed: number)
	table.insert(list, { size = Vector2.new(w, d), origin = MapKit.at(x, z), count = count, seed = seed })
end

function MapKit.hill(list: { Hill }, x: number, z: number, radius: number, height: number)
	-- Steepest slope of the bump is height * pi / (2 * radius); keep it drivable.
	assert(height * math.pi / (2 * radius) <= math.tan(Config.Maps.MaxRampAngle) + 1e-3, "hill too steep")
	table.insert(list, { origin = MapKit.at(x, z), radius = radius, height = height })
end

-- Bridge along Z over water: a low deck with ramps at both ends and breakable rails.
-- Returns the crossing (both approach points) for bots.
function MapKit.bridge(cover: { Cover }, props: { Prop }, x: number, z: number, width: number, span: number): { Vector3 }
	local h = 3
	local wood = Color3.fromRGB(150, 110, 75)
	MapKit.plateau(cover, x, z, width, span, h, { "S", "N" }, wood)
	MapKit.fence(props, x - width / 2 + 1, z - span / 2, x - width / 2 + 1, z + span / 2)
	MapKit.fence(props, x + width / 2 - 1, z - span / 2, x + width / 2 - 1, z + span / 2)
	local reach = span / 2 + h / math.tan(Config.Maps.MaxRampAngle) + 8
	return { Vector3.new(x, 0, z - reach), Vector3.new(x, 0, z + reach) }
end

-- Free-standing destructible wall: `length` chunks long, `rows` chunks high. It runs along
-- the origin's X axis.
function MapKit.wall(origin: CFrame, length: number, rows: number, color: Color3): Building
	return {
		spec = {
			name = "Wall",
			width = length,
			depth = 1,
			floors = rows,
			color = color,
			roofColor = color,
			doorWidth = 0,
			doorHeight = 0,
			windows = false,
			wallOnly = true,
		},
		origin = origin,
	}
end

-- Small crate pile: two side by side and one on top, around (x, z).
function MapKit.crates(list: { Prop }, x: number, z: number, yawDegrees: number?)
	local s = Config.Props.CrateSize
	local base = MapKit.at(x, z, yawDegrees)
	table.insert(list, { kind = "Crate", origin = base * CFrame.new(-s / 2 - 0.1, 0, 0) })
	table.insert(list, { kind = "Crate", origin = base * CFrame.new(s / 2 + 0.1, 0, 0) * CFrame.Angles(0, math.rad(12), 0) })
	table.insert(list, { kind = "Crate", origin = base * CFrame.new(0, s, 0) * CFrame.Angles(0, math.rad(-20), 0) })
end

-- Fence from (x1, z1) to (x2, z2), in separately breakable pieces.
function MapKit.fence(list: { Prop }, x1: number, z1: number, x2: number, z2: number)
	local from = Vector3.new(x1, 0, z1)
	local to = Vector3.new(x2, 0, z2)
	local length = (to - from).Magnitude
	local pieces = math.max(1, math.round(length / Config.Props.FenceSegment))
	local step = (to - from) / pieces
	for i = 0, pieces - 1 do
		local start = from + step * i
		table.insert(list, { kind = "Fence", origin = CFrame.lookAt(start, start + step), length = step.Magnitude })
	end
end

function MapKit.tree(list: { Prop }, x: number, z: number)
	table.insert(list, { kind = "Tree", origin = MapKit.at(x, z) })
end

-- Grid of trees: `columns` x `rows` starting at (x, z), `spacing` apart, slightly jittered.
function MapKit.grove(list: { Prop }, x: number, z: number, columns: number, rows: number, spacing: number, seed: number)
	local rng = Random.new(seed)
	for i = 0, columns - 1 do
		for j = 0, rows - 1 do
			MapKit.tree(list, x + i * spacing + rng:NextNumber(-2, 2), z + j * spacing + rng:NextNumber(-2, 2))
		end
	end
end

return MapKit
