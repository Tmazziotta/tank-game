--!strict
-- Generates pre-fractured buildings: perimeter walls and a roof made of chunk grids.
-- Every chunk is unanchored and welded to each face-touching neighbour, and the bottom
-- row is welded to an anchored foundation. The whole building is therefore one anchored
-- assembly (no physics cost) until welds are broken.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type BuildingSpec = {
	name: string,
	width: number, -- chunks along local X
	depth: number, -- chunks along local Z
	floors: number, -- chunk rows of wall height
	color: Color3,
	roofColor: Color3,
	doorWidth: number, -- chunks, centered in the front (-Z) wall; 0 for none
	doorHeight: number, -- chunk rows
	windows: boolean,
}

type ChunkDef = {
	position: Vector3, -- building-local center
	size: Vector3,
	color: Color3,
}

local BuildingGenerator = {}

BuildingGenerator.CHUNK_ATTRIBUTE = "Chunk"

local FOUNDATION_HEIGHT = 0.2 -- thin, so tanks can roll over the lip
local CONTACT_EPSILON = 0.05

local function varied(color: Color3, rng: Random): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * rng:NextNumber(0.9, 1.05), 0, 1))
end

-- Windows on odd rows, staggered one column per window row so no chunk is sandwiched
-- between a window below and a window above (it would only hang by its two side welds).
local function isWindow(column: number, row: number, count: number): boolean
	if row % 2 ~= 1 or column <= 0 or column >= count - 1 then
		return false
	end
	local stagger = (row // 2) % 3
	return (column + stagger) % 3 == 1
end

local function isDoorColumn(spec: BuildingSpec, column: number): boolean
	local first = math.floor((spec.width - spec.doorWidth) / 2)
	return spec.doorWidth > 0 and column >= first and column < first + spec.doorWidth
end

local function isDoor(spec: BuildingSpec, column: number, row: number): boolean
	return row < spec.doorHeight and isDoorColumn(spec, column)
end

local function layout(spec: BuildingSpec, rng: Random): { ChunkDef }
	local s = Config.Destruction.ChunkSize
	local t = Config.Destruction.WallThickness
	local outerW = spec.width * s
	local outerD = spec.depth * s
	local base = FOUNDATION_HEIGHT
	local chunks: { ChunkDef } = {}

	local function add(position: Vector3, size: Vector3, color: Color3)
		table.insert(chunks, { position = position, size = size, color = varied(color, rng) })
	end

	for row = 0, spec.floors - 1 do
		local y = base + s * (row + 0.5)
		-- Front (-Z) and back (+Z) walls span the full width.
		for column = 0, spec.width - 1 do
			local x = -outerW / 2 + s * (column + 0.5)
			local size = Vector3.new(s, s, t)
			-- No windows above the door, so the lintel keeps a chunk on top of it.
			local frontWindow = spec.windows and isWindow(column, row, spec.width) and not isDoorColumn(spec, column)
			local frontOpen = isDoor(spec, column, row) or frontWindow
			if not frontOpen then
				add(Vector3.new(x, y, -outerD / 2 + t / 2), size, spec.color)
			end
			if not (spec.windows and isWindow(column, row, spec.width)) then
				add(Vector3.new(x, y, outerD / 2 - t / 2), size, spec.color)
			end
		end
		-- Side walls fit between the front and back walls.
		local sideLength = (outerD - 2 * t) / spec.depth
		for column = 0, spec.depth - 1 do
			if spec.windows and isWindow(column, row, spec.depth) then
				continue
			end
			local z = -outerD / 2 + t + sideLength * (column + 0.5)
			local size = Vector3.new(t, s, sideLength)
			add(Vector3.new(-outerW / 2 + t / 2, y, z), size, spec.color)
			add(Vector3.new(outerW / 2 - t / 2, y, z), size, spec.color)
		end
	end

	-- Roof slabs sit on top of the walls.
	local roofT = Config.Destruction.RoofThickness
	local roofY = base + s * spec.floors + roofT / 2
	for ix = 0, spec.width - 1 do
		for iz = 0, spec.depth - 1 do
			local position = Vector3.new(-outerW / 2 + s * (ix + 0.5), roofY, -outerD / 2 + s * (iz + 0.5))
			add(position, Vector3.new(s, roofT, s), spec.roofColor)
		end
	end

	return chunks
end

-- Two axis-aligned boxes share a face if they touch/overlap on all three axes and
-- overlap with positive area on at least two of them.
local function shareFace(a: ChunkDef, b: ChunkDef): boolean
	local delta = a.position - b.position
	local half = (a.size + b.size) / 2
	local overlap = {
		half.X - math.abs(delta.X),
		half.Y - math.abs(delta.Y),
		half.Z - math.abs(delta.Z),
	}
	local positive = 0
	for _, amount in overlap do
		if amount < -CONTACT_EPSILON then
			return false
		end
		if amount > CONTACT_EPSILON then
			positive += 1
		end
	end
	return positive >= 2
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- Returns an unparented Model. `origin` is the ground-level center of the footprint.
function BuildingGenerator.build(spec: BuildingSpec, origin: CFrame, seed: number?): Model
	local rng = Random.new(seed or 0)
	local s = Config.Destruction.ChunkSize
	local model = Instance.new("Model")
	model.Name = spec.name

	local foundation = Instance.new("Part")
	foundation.Name = "Foundation"
	foundation.Anchored = true
	foundation.Size = Vector3.new(spec.width * s + 2, FOUNDATION_HEIGHT, spec.depth * s + 2)
	foundation.CFrame = origin * CFrame.new(0, FOUNDATION_HEIGHT / 2, 0)
	foundation.Color = Color3.fromRGB(200, 200, 210)
	foundation.Material = Enum.Material.SmoothPlastic
	foundation.TopSurface = Enum.SurfaceType.Smooth
	foundation.Parent = model

	local defs = layout(spec, rng)
	local parts: { Part } = table.create(#defs)
	for i, def in defs do
		local part = Instance.new("Part")
		part.Name = "Chunk"
		part.Size = def.size
		part.CFrame = origin * CFrame.new(def.position)
		part.Color = def.color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = false
		part:SetAttribute(BuildingGenerator.CHUNK_ATTRIBUTE, true)
		part.Parent = model
		parts[i] = part
	end

	for i = 1, #defs do
		local a = defs[i]
		if a.position.Y - a.size.Y / 2 <= FOUNDATION_HEIGHT + CONTACT_EPSILON then
			weld(foundation, parts[i])
		end
		for j = i + 1, #defs do
			if shareFace(a, defs[j]) then
				weld(parts[i], parts[j])
			end
		end
	end

	model.PrimaryPart = foundation
	return model
end

return BuildingGenerator
