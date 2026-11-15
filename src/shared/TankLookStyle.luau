--!strict
-- Line styling for tank parts. The parts kit (TankLook) asks for generic shapes in a role
-- color; each line turns them into its own toy look:
--   Brick: hard plastic blocks, slightly shrunk so the seams between them show; round
--          shapes become blocks too.
--   Plush: fabric; boxes become soft pillows (rounded) and wedges become plump rounds.
--   Foam:  blaster plastic shell, with "Foam" role parts in soft rubber.
-- Every piece is decoration (no collision, no mass) welded to a physics anchor.

local Config = require(script.Parent.Config)

local TankLookStyle = {}

-- Box/Wedge: blocks. Round: ellipsoid. Pill: rounded block. Ball: sphere.
-- Tube: cylinder along the part's X axis (size = length, diameter, diameter).
export type Shape = "Box" | "Wedge" | "Round" | "Pill" | "Ball" | "Tube"
-- Palette slots (Config.Looks.Palettes) plus Accent (team / line color) and Glow (lights).
export type Role = "Main" | "Second" | "Trim" | "Dark" | "Light" | "Foam" | "Accent" | "Glow"

export type Kit = {
	model: Model,
	line: string,
	accent: Color3,
	at: (x: number, y: number, z: number) -> CFrame, -- tank-local layout units -> world
	k: number, -- class scale
}

local ROUNDED: { [string]: { [string]: string } } = {
	Brick = { Round = "Box", Pill = "Box", Ball = "Box" },
	Plush = { Box = "Pill", Wedge = "Round" },
	Foam = {},
}

local function color(kit: Kit, role: Role): Color3
	if role == "Accent" then
		return kit.accent
	end
	local palette = (Config.Looks.Palettes :: any)[kit.line] or Config.Looks.Palettes.Brick
	return palette[if role == "Glow" then "Light" else role] or palette.Main
end

local function material(kit: Kit, role: Role): Enum.Material
	if role == "Glow" then
		return Enum.Material.Neon
	elseif role == "Foam" then
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
	-- Accent (flags, stripes) and lights keep their exact shape in every line.
	local keep = role == "Accent" or role == "Glow"
	local styled = if keep then shape else (ROUNDED[kit.line] or {})[shape] or shape
	local scaled = size * kit.k
	local part: BasePart
	if styled == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local p = Instance.new("Part")
		p.Shape = if styled == "Tube" then Enum.PartType.Cylinder elseif styled == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
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
