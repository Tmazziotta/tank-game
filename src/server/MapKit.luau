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
}

export type Prop = {
	kind: PropBuilder.Kind,
	origin: CFrame,
	length: number?, -- fence pieces only
}

export type MapDef = {
	id: string,
	displayName: string,
	center: Vector3,
	halfSize: Vector2, -- boundary half-extents (X, Z) around center
	groundColor: Color3,
	boundaryColor: Color3,
	wanderRadius: number, -- bots roam this far from center when idle
	spawns: { CFrame },
	buildings: { Building }, -- destructible (buildings and free-standing walls)
	cover: { Cover }, -- indestructible
	props: { Prop }, -- crushable
}

local MapKit = {}

-- Ground-level CFrame at (x, z), yawed.
function MapKit.at(x: number, z: number, yawDegrees: number?): CFrame
	return CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
end

-- Spawn at (x, z) facing `center`.
function MapKit.spawn(x: number, z: number, center: Vector3): CFrame
	local position = Vector3.new(x, 0.1, z)
	return CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
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
