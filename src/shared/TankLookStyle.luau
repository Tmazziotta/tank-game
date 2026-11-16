--!strict
-- Line styling for tank parts. The parts kit (TankLook) asks for generic shapes in a role
-- color; each line turns them into its own toy look:
--   Brick: glossy hard plastic, all square. Big blocks (slabs) are stacked from staggered
--          bricks with wide seams and peg holes on their sides; every round shape (balls,
--          tubes, ellipsoids) becomes a block.
--   Plush: fabric; boxes become soft pillows (rounded) and wedges become plump rounds.
--   Foam:  fully matte, all capsule: slabs are rounded shells with round ends, decks are
--          ringed by thick "pool noodle" bumpers; wedges become soft round noses.
-- Every piece is decoration (no collision, no mass) welded to a physics anchor.

local Config = require(script.Parent.Config)

local TankLookStyle = {}

-- Box/Wedge: blocks. Round: ellipsoid. Pill: rounded block. Ball: sphere.
-- Tube: cylinder along the part's X axis (size = length, diameter, diameter).
-- Hole: a Tube that stays round in every line (Brick peg holes).
export type Shape = "Box" | "Wedge" | "Round" | "Pill" | "Ball" | "Tube" | "Hole"
-- Palette slots (Config.Looks.Palettes) plus Glow (lights).
export type Role = "Main" | "Second" | "Trim" | "Dark" | "Light" | "Foam" | "Noodle" | "Glow"

export type Kit = {
	model: Model,
	line: string,
	at: (x: number, y: number, z: number) -> CFrame, -- tank-local layout units -> world
	k: number, -- class scale
}

local ROUNDED: { [string]: { [string]: string } } = {
	Brick = { Round = "Box", Pill = "Box", Ball = "Box", Tube = "Box" },
	Plush = { Box = "Pill", Wedge = "Round" },
	Foam = { Wedge = "Round" },
}

local function color(kit: Kit, role: Role): Color3
	local palette = (Config.Looks.Palettes :: any)[kit.line] or Config.Looks.Palettes.Brick
	return palette[if role == "Glow" then "Light" else role] or palette.Main
end

local function material(kit: Kit, role: Role): Enum.Material
	if role == "Glow" then
		return Enum.Material.Neon
	elseif role == "Foam" or role == "Noodle" then
		return Config.Looks.FoamMaterial
	end
	return (Config.Looks.Materials :: any)[kit.line] or Enum.Material.SmoothPlastic
end

local function mesh(part: BasePart, kind: Enum.MeshType)
	local m = Instance.new("SpecialMesh")
	m.MeshType = kind
	m.Parent = part
end

-- One decorative piece, welded to `anchor`. `size` is in layout units (scaled by kit.k);
-- `cframe` is already in world space (from kit.at).
function TankLookStyle.piece(kit: Kit, anchor: BasePart, name: string, shape: Shape, role: Role, size: Vector3, cframe: CFrame): BasePart
	local styled = (ROUNDED[kit.line] or {})[shape] or shape
	local scaled = size * kit.k
	local part: BasePart
	if styled == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local p = Instance.new("Part")
		p.Shape = if styled == "Tube" or styled == "Hole" then Enum.PartType.Cylinder elseif styled == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
		part = p
	end
	if kit.line == "Brick" and (styled == "Box" or styled == "Wedge") then
		local seam = Config.Looks.BrickSeam * kit.k
		scaled = Vector3.new(math.max(scaled.X - seam, 0.05), math.max(scaled.Y - seam, 0.05), math.max(scaled.Z - seam, 0.05))
	end
	part.Name = name
	part.Size = scaled
	part.CFrame = cframe
	part.Color = color(kit, role)
	part.Material = material(kit, role)
	if role ~= "Glow" then
		part.Reflectance = (Config.Looks.Reflectance :: any)[kit.line] or 0
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	if styled == "Round" then
		mesh(part, Enum.MeshType.Sphere)
	elseif styled == "Pill" then
		mesh(part, Enum.MeshType.Head)
	end
	part.Parent = kit.model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function offset(kit: Kit, cframe: CFrame, x: number, y: number, z: number): CFrame
	return cframe * CFrame.new(x * kit.k, y * kit.k, z * kit.k)
end

-- Brick: cut a box into courses of bricks (rows ~0.9 tall), joints staggered row to row.
local function bricks(kit: Kit, anchor: BasePart, name: string, role: Role, size: Vector3, cframe: CFrame)
	local cfg = Config.Looks.Brick
	local rows = math.max(1, math.round(size.Y / cfg.CourseHeight))
	local cols = math.max(1, math.ceil(size.X / cfg.BrickWidth))
	local rowH, colW = size.Y / rows, size.X / cols
	local count = math.max(1, math.round(size.Z / cfg.BrickLength))
	local len = size.Z / count
	for r = 0, rows - 1 do
		local y = -size.Y / 2 + rowH * (r + 0.5)
		-- Joints along Z; odd rows shift half a brick (half bricks at the ends).
		local cuts = { -size.Z / 2 }
		local shift = if r % 2 == 1 and count > 1 then len / 2 else 0
		for i = 1, count do
			local z = -size.Z / 2 + i * len - shift
			if z > cuts[#cuts] + 0.05 and z < size.Z / 2 - 0.05 then
				table.insert(cuts, z)
			end
		end
		table.insert(cuts, size.Z / 2)
		for i = 1, #cuts - 1 do
			for col = 0, cols - 1 do
				local x = -size.X / 2 + colW * (col + 0.5)
				local z = (cuts[i] + cuts[i + 1]) / 2
				TankLookStyle.piece(kit, anchor, name, "Box", role, Vector3.new(colW, rowH, cuts[i + 1] - cuts[i]), offset(kit, cframe, x, y, z))
			end
		end
	end
end

-- Foam: a capsule-ish shell: a box with rounded long edges (two crossed cores + 4 tubes)
-- and rounded (ellipsoid) ends front and back.
local function shell(kit: Kit, anchor: BasePart, name: string, role: Role, size: Vector3, cframe: CFrame)
	local r = math.min(size.X, size.Y) * Config.Looks.Foam.EdgeRound
	local cap = math.min(size.Z * 0.25, math.min(size.X, size.Y) * 0.5)
	local core = size.Z - 2 * cap
	TankLookStyle.piece(kit, anchor, name, "Box", role, Vector3.new(size.X - 2 * r, size.Y, core), cframe)
	TankLookStyle.piece(kit, anchor, name, "Box", role, Vector3.new(size.X, size.Y - 2 * r, core), cframe)
	local along = CFrame.Angles(0, math.rad(90), 0)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			local at = offset(kit, cframe, sx * (size.X / 2 - r), sy * (size.Y / 2 - r), 0) * along
			TankLookStyle.piece(kit, anchor, name, "Tube", role, Vector3.new(core, 2 * r, 2 * r), at)
		end
	end
	for _, sz in { -1, 1 } do
		local at = offset(kit, cframe, 0, 0, sz * (core / 2))
		TankLookStyle.piece(kit, anchor, name, "Round", role, Vector3.new(size.X, size.Y, 2 * cap), at)
	end
end

-- A big structural block (hull body, deck, turret body): bricks for Brick, a rounded shell
-- for Foam, a single (pillowed) piece for Plush. `size` in layout units, `cframe` world.
function TankLookStyle.slab(kit: Kit, anchor: BasePart, name: string, role: Role, size: Vector3, cframe: CFrame)
	if kit.line == "Brick" then
		bricks(kit, anchor, name, role, size, cframe)
	elseif kit.line == "Foam" then
		shell(kit, anchor, name, role, size, cframe)
	else
		TankLookStyle.piece(kit, anchor, name, "Box", role, size, cframe)
	end
end

-- Brick only: a row of round peg holes along both X sides of a slab of `size`.
function TankLookStyle.pegs(kit: Kit, anchor: BasePart, size: Vector3, cframe: CFrame, count: number)
	if kit.line ~= "Brick" then
		return
	end
	local d = math.min(0.7, size.Y * 0.45)
	for _, side in { -1, 1 } do
		for i = 1, count do
			local z = -size.Z / 2 + size.Z * (i - 0.5) / count
			local at = offset(kit, cframe, side * (size.X / 2 - 0.08), 0, z)
			TankLookStyle.piece(kit, anchor, "PegHole", "Hole", "Dark", Vector3.new(0.3, d, d), at)
		end
	end
end

-- Foam only: a ring of soft foam tubes around the edge of a deck of `size` (X by Z).
function TankLookStyle.bumpers(kit: Kit, anchor: BasePart, size: Vector3, cframe: CFrame)
	if kit.line ~= "Foam" then
		return
	end
	local d = Config.Looks.Foam.NoodleSize
	local hx, hz = size.X / 2, size.Z / 2
	local alongZ = CFrame.Angles(0, math.rad(90), 0)
	for _, s in { -1, 1 } do
		TankLookStyle.piece(kit, anchor, "Noodle", "Tube", "Noodle", Vector3.new(size.Z, d, d), offset(kit, cframe, s * hx, 0, 0) * alongZ)
		TankLookStyle.piece(kit, anchor, "Noodle", "Tube", "Noodle", Vector3.new(size.X, d, d), offset(kit, cframe, 0, 0, s * hz))
		for _, t in { -1, 1 } do
			TankLookStyle.piece(kit, anchor, "NoodleCorner", "Ball", "Noodle", Vector3.new(d, d, d), offset(kit, cframe, s * hx, 0, t * hz))
		end
	end
end

-- Plush only: a row of stitches from `a` to `b` (layout units), as little light dashes.
function TankLookStyle.stitches(kit: Kit, anchor: BasePart, a: Vector3, b: Vector3, count: number)
	if kit.line ~= "Plush" then
		return
	end
	local span = b - a
	local step = span / count
	local dash = Vector3.new(0.18, 0.18, math.max(step.Magnitude * 0.55, 0.2))
	for i = 0, count - 1 do
		local mid = a + step * (i + 0.5)
		local look = CFrame.lookAt(Vector3.zero, span.Unit)
		local cf = kit.at(mid.X, mid.Y, mid.Z) * look.Rotation
		TankLookStyle.piece(kit, anchor, "Stitch", "Box", "Light", dash, cf)
	end
end

return TankLookStyle
