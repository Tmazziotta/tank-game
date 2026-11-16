--!strict
-- The tank parts kit: dresses a tank's (invisible) physics skeleton from its blueprint
-- (TankCatalog.look): one Tracks, Hull, Turret and Gun part plus any Extras, each drawn in
-- the line's style (TankLookStyle). Every tank also gets the accent color on fender stripes
-- and a flag, so teams stay readable whatever the line.
--
-- Layout units match TankBuilder's Medium tank (kit.at scales them): ground y = 0, deck top
-- y = 3.7, turret ring y = 3.8 at z = -0.6, gun axis y = 5.0 starting at z = -2.6 (forward
-- is -Z). Parts stay inside the physics envelope so hits match what you see.

local Style = require(script.Parent.TankLookStyle)
local TankCatalog = require(script.Parent.TankCatalog)

type Kit = Style.Kit

export type Anchors = {
	hull: BasePart,
	turret: BasePart,
	barrel: BasePart,
}

export type Dressed = {
	muzzle: number, -- gun length to the muzzle, in barrel units (TankBuilder places it)
}

local TankLook = {}

-- Cylinders run along local X; these aim it.
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)
local ALONG_Y = CFrame.Angles(0, 0, math.rad(90))

local V = Vector3.new
local piece = Style.piece

type Ctx = Kit & {
	hull: BasePart,
	turret: BasePart,
	barrel: BasePart,
	L: number,
	W: number,
	side: number, -- x of the hull's outer side (stripes, skirts)
	stripeY: number, -- height of the accent stripes
	turretTop: number, -- y of the turret roof (antennas, ears, clips sit on it)
	gunAt: (d: number) -> number, -- z of a point d barrel-units along the gun
}

-- Tracks ---------------------------------------------------------------------------------

local function roadWheels(c: Ctx, side: number, zs: { number }, diameter: number, x: number)
	for _, z in zs do
		piece(c, c.hull, "Wheel", "Tube", "Second", V(0.5, diameter, diameter), c.at(x * side, 1.6, z))
		piece(c, c.hull, "Hub", "Tube", "Dark", V(0.6, diameter * 0.35, diameter * 0.35), c.at((x + 0.1) * side, 1.6, z))
	end
end

local function treads(c: Ctx)
	for _, side in { -1, 1 } do
		piece(c, c.hull, "Tread", "Tube", "Dark", V(10, 3, 3), c.at(3.4 * side, 1.6, 0) * ALONG_Z)
		for _, z in { -5, 5 } do
			piece(c, c.hull, "TreadCap", "Ball", "Dark", V(3, 3, 3), c.at(3.4 * side, 1.6, z))
		end
		roadWheels(c, side, { -3.75, -1.25, 1.25, 3.75 }, 2.1, 5.0)
		Style.stitches(c, c.hull, V(3.4 * side, 3.15, -4.6), V(3.4 * side, 3.15, 4.6), 9)
	end
end

local TRACKS: { [string]: (Ctx) -> () } = {
	-- Rounded track pods with road wheels.
	Treads = treads,
	-- Three big wheels a side: quick little scouts.
	Wheels = function(c: Ctx)
		for _, side in { -1, 1 } do
			for _, z in { -3.6, 0, 3.6 } do
				piece(c, c.hull, "Wheel", "Tube", "Dark", V(1.4, 3.2, 3.2), c.at(4.2 * side, 1.6, z))
				piece(c, c.hull, "Hub", "Tube", "Second", V(1.5, 1.3, 1.3), c.at(4.25 * side, 1.6, z))
			end
			piece(c, c.hull, "Axle", "Box", "Dark", V(0.8, 0.8, 8.4), c.at(3.4 * side, 1.6, 0))
		end
	end,
	-- Treads behind armor skirts: heavies.
	Skirted = function(c: Ctx)
		treads(c)
		for _, side in { -1, 1 } do
			Style.slab(c, c.hull, "Skirt", "Main", V(0.6, 2.0, 10.6), c.at(5.25 * side, 2.2, 0))
			piece(c, c.hull, "SkirtEdge", "Box", "Second", V(0.7, 0.4, 10.6), c.at(5.25 * side, 1.2, 0))
		end
		c.side = 5.6
	end,
}

-- Hulls (top of deck ~3.7) ---------------------------------------------------------------

local HULLS: { [string]: (Ctx) -> () } = {
	-- Flat box hull with a full-width deck.
	Slab = function(c: Ctx)
		Style.slab(c, c.hull, "Body", "Second", V(6.2, 2, 10), c.at(0, 2.2, 0))
		Style.pegs(c, c.hull, V(6.2, 2, 10), c.at(0, 2.2, 0), 4)
		Style.slab(c, c.hull, "Deck", "Main", V(9.8, 0.6, 11.6), c.at(0, 3.4, 0))
		Style.bumpers(c, c.hull, V(9.8, 0.6, 11.6), c.at(0, 3.2, 0))
		piece(c, c.hull, "Nose", "Box", "Main", V(6.2, 0.8, 0.8), c.at(0, 2.6, -5.3))
	end,
	-- Sloped front plate: sleeker, pointier.
	Wedge = function(c: Ctx)
		Style.slab(c, c.hull, "Body", "Second", V(6.2, 2, 9), c.at(0, 2.2, 0.5))
		Style.pegs(c, c.hull, V(6.2, 2, 9), c.at(0, 2.2, 0.5), 4)
		Style.slab(c, c.hull, "Deck", "Main", V(9.8, 0.6, 9.2), c.at(0, 3.4, 1.2))
		Style.bumpers(c, c.hull, V(9.8, 0.6, 9.2), c.at(0, 3.2, 1.2))
		-- A wedge's slope falls toward -Z: high at the back, low at the nose.
		piece(c, c.hull, "Glacis", "Wedge", "Main", V(9.8, 2.4, 2.6), c.at(0, 2.5, -4.7))
	end,
	-- Long hull with a raised engine deck and exhausts at the back.
	Long = function(c: Ctx)
		Style.slab(c, c.hull, "Body", "Second", V(6.2, 2, 10.4), c.at(0, 2.2, 0.2))
		Style.pegs(c, c.hull, V(6.2, 2, 10.4), c.at(0, 2.2, 0.2), 4)
		Style.slab(c, c.hull, "Deck", "Main", V(9.8, 0.6, 11.8), c.at(0, 3.4, 0.1))
		Style.bumpers(c, c.hull, V(9.8, 0.6, 11.8), c.at(0, 3.2, 0.1))
		Style.slab(c, c.hull, "Engine", "Second", V(7.4, 0.9, 1.8), c.at(0, 4.15, 5.0))
		for _, side in { -1, 1 } do
			piece(c, c.hull, "Exhaust", "Tube", "Dark", V(1.6, 0.7, 0.7), c.at(2.9 * side, 4.6, 5.6) * ALONG_Y)
		end
		piece(c, c.hull, "Plow", "Box", "Dark", V(8.6, 1.0, 0.6), c.at(0, 2.2, -5.9))
	end,
	-- One soft rounded body (plush), with a fat seam stitched around it.
	Round = function(c: Ctx)
		piece(c, c.hull, "Body", "Pill", "Main", V(8.8, 2.9, 11.6), c.at(0, 2.55, 0))
		piece(c, c.hull, "Belly", "Pill", "Second", V(6.4, 1.4, 9.4), c.at(0, 1.6, 0))
		Style.stitches(c, c.hull, V(0, 4.0, -4.8), V(0, 4.0, 2.4), 8)
		c.side = 4.35
		c.stripeY = 2.6
	end,
}

-- Turrets (ring at y 3.8, z -0.6) --------------------------------------------------------

local TURRETS: { [string]: (Ctx) -> () } = {
	-- Low drum with a round dome.
	Dome = function(c: Ctx)
		piece(c, c.turret, "TurretBase", "Tube", "Main", V(1.5, 5.8, 5.8), c.at(0, 4.55, -0.6) * ALONG_Y)
		piece(c, c.turret, "Dome", "Ball", "Second", V(4.2, 4.2, 4.2), c.at(0, 5.2, -0.6))
		c.turretTop = 7.2
	end,
	-- Square turret with a hatch and a rear bustle.
	Box = function(c: Ctx)
		Style.slab(c, c.turret, "TurretBody", "Main", V(5.4, 1.8, 5.2), c.at(0, 4.7, -0.5))
		Style.pegs(c, c.turret, V(5.4, 1.8, 5.2), c.at(0, 4.7, -0.5), 3)
		Style.slab(c, c.turret, "Bustle", "Second", V(4.4, 1.2, 1.4), c.at(0, 4.6, 2.6))
		piece(c, c.turret, "Hatch", "Box", "Second", V(2.0, 0.4, 2.0), c.at(-1.0, 5.8, 0.2))
		piece(c, c.turret, "Mantlet", "Box", "Dark", V(2.2, 1.4, 0.7), c.at(0, 5.0, -3.3))
		c.turretTop = 5.6
	end,
	-- Two stacked blocks with a little cupola: a tall tower.
	Tall = function(c: Ctx)
		Style.slab(c, c.turret, "TurretBody", "Main", V(5.0, 1.6, 5.0), c.at(0, 4.6, -0.6))
		Style.pegs(c, c.turret, V(5.0, 1.6, 5.0), c.at(0, 4.6, -0.6), 3)
		Style.slab(c, c.turret, "TurretTop", "Second", V(3.6, 1.4, 3.6), c.at(0, 6.1, -0.2))
		piece(c, c.turret, "Cupola", "Tube", "Dark", V(0.6, 1.6, 1.6), c.at(0.8, 7.1, 0.2) * ALONG_Y)
		piece(c, c.turret, "Mantlet", "Box", "Dark", V(2.0, 1.4, 0.7), c.at(0, 5.0, -3.4))
		c.turretTop = 7.4
	end,
	-- Wide, flat turret with a big rear bustle: a heavy's.
	Wide = function(c: Ctx)
		Style.slab(c, c.turret, "TurretBody", "Main", V(6.6, 1.5, 5.6), c.at(0, 4.6, -0.5))
		Style.pegs(c, c.turret, V(6.6, 1.5, 5.6), c.at(0, 4.6, -0.5), 3)
		Style.slab(c, c.turret, "Bustle", "Second", V(5.6, 1.2, 2.0), c.at(0, 4.55, 3.1))
		piece(c, c.turret, "Mantlet", "Box", "Dark", V(2.6, 1.8, 0.9), c.at(0, 5.0, -3.6))
		c.turretTop = 5.4
	end,
	-- A plush head with a snout.
	Head = function(c: Ctx)
		piece(c, c.turret, "Head", "Round", "Main", V(5.8, 3.4, 5.4), c.at(0, 5.2, -0.4))
		piece(c, c.turret, "Snout", "Round", "Second", V(2.8, 1.8, 1.6), c.at(0, 4.9, -3.0))
		piece(c, c.turret, "Nose", "Ball", "Dark", V(0.9, 0.9, 0.9), c.at(0, 5.5, -3.7))
		for _, side in { -1, 1 } do
			piece(c, c.turret, "Eye", "Ball", "Dark", V(0.8, 0.8, 0.8), c.at(1.1 * side, 6.1, -2.8))
		end
		c.turretTop = 6.8
	end,
	-- A foam blaster body: plastic shell on a soft foam pad, with a top rail.
	Blaster = function(c: Ctx)
		piece(c, c.turret, "Pad", "Box", "Foam", V(5.2, 0.6, 6.0), c.at(0, 4.0, -0.4))
		Style.slab(c, c.turret, "Shell", "Second", V(4.6, 2.0, 5.6), c.at(0, 5.2, -0.3))
		for i = 0, 2 do
			piece(c, c.turret, "Grip", "Tube", "Dark", V(4.75, 0.25, 0.25), c.at(0, 4.6 + i * 0.45, 1.6))
		end
		piece(c, c.turret, "Rail", "Box", "Main", V(1.2, 0.5, 5.0), c.at(0, 6.45, -0.3))
		for _, side in { -1, 1 } do
			piece(c, c.turret, "Vent", "Box", "Trim", V(0.3, 0.8, 2.6), c.at(2.4 * side, 5.3, 0.2))
		end
		c.turretTop = 6.7
	end,
}

-- Guns (along the barrel; each returns how far its muzzle is) ----------------------------

local GUNS: { [string]: (Ctx) -> number } = {
	-- Plain tube with a muzzle ring.
	Plain = function(c: Ctx): number
		piece(c, c.barrel, "Gun", "Tube", "Dark", V(7 * c.L, c.W, c.W), c.at(0, 5.0, c.gunAt(3.5)) * ALONG_Z)
		piece(c, c.barrel, "MuzzleRing", "Tube", "Second", V(1.0, 1.4 * c.W, 1.4 * c.W), c.at(0, 5.0, c.gunAt(6.6)) * ALONG_Z)
		return 7.2
	end,
	-- Long thin gun with a sleeve and a boxy brake.
	Long = function(c: Ctx): number
		piece(c, c.barrel, "Gun", "Tube", "Dark", V(8.2 * c.L, 0.8 * c.W, 0.8 * c.W), c.at(0, 5.0, c.gunAt(4.1)) * ALONG_Z)
		piece(c, c.barrel, "Sleeve", "Tube", "Second", V(1.6, 1.2 * c.W, 1.2 * c.W), c.at(0, 5.0, c.gunAt(1.2)) * ALONG_Z)
		piece(c, c.barrel, "Brake", "Box", "Dark", V(1.5 * c.W, 1.0 * c.W, 1.4), c.at(0, 5.0, c.gunAt(8.0)))
		return 8.6
	end,
	-- Short fat howitzer.
	Stubby = function(c: Ctx): number
		piece(c, c.barrel, "Gun", "Tube", "Dark", V(5 * c.L, 1.5 * c.W, 1.5 * c.W), c.at(0, 5.0, c.gunAt(2.5)) * ALONG_Z)
		piece(c, c.barrel, "MuzzleRing", "Tube", "Second", V(1.0, 1.9 * c.W, 1.9 * c.W), c.at(0, 5.0, c.gunAt(4.6)) * ALONG_Z)
		return 5.2
	end,
	-- Two thin tubes side by side.
	Twin = function(c: Ctx): number
		for _, side in { -1, 1 } do
			piece(c, c.barrel, "Gun", "Tube", "Dark", V(7 * c.L, 0.6 * c.W, 0.6 * c.W), c.at(0.42 * c.W * side, 5.0, c.gunAt(3.5)) * ALONG_Z)
		end
		piece(c, c.barrel, "Bridge", "Box", "Second", V(1.6 * c.W, 0.5 * c.W, 0.8), c.at(0, 5.0, c.gunAt(5.6)))
		return 7.2
	end,
	-- Foam blaster barrel: fat plastic tube, foam dart nose poking out.
	Dart = function(c: Ctx): number
		piece(c, c.barrel, "Gun", "Tube", "Trim", V(5.6 * c.L, 1.3 * c.W, 1.3 * c.W), c.at(0, 5.0, c.gunAt(2.8)) * ALONG_Z)
		piece(c, c.barrel, "Ring", "Tube", "Main", V(0.6, 1.6 * c.W, 1.6 * c.W), c.at(0, 5.0, c.gunAt(5.3)) * ALONG_Z)
		piece(c, c.barrel, "DartTip", "Ball", "Foam", V(1.1 * c.W, 1.1 * c.W, 1.1 * c.W), c.at(0, 5.0, c.gunAt(5.75)))
		return 6.2
	end,
	-- Soft fabric snout with stitched bands and a pom on the end.
	Snout = function(c: Ctx): number
		piece(c, c.barrel, "Gun", "Tube", "Second", V(6 * c.L, 1.1 * c.W, 1.1 * c.W), c.at(0, 5.0, c.gunAt(3.0)) * ALONG_Z)
		for _, d in { 2.0, 4.0 } do
			piece(c, c.barrel, "Band", "Tube", "Trim", V(0.4, 1.25 * c.W, 1.25 * c.W), c.at(0, 5.0, c.gunAt(d)) * ALONG_Z)
		end
		piece(c, c.barrel, "Pom", "Ball", "Trim", V(1.4 * c.W, 1.4 * c.W, 1.4 * c.W), c.at(0, 5.0, c.gunAt(6.0)))
		return 6.6
	end,
}

-- Extras ---------------------------------------------------------------------------------

local EXTRAS: { [string]: (Ctx) -> () } = {
	Antenna = function(c: Ctx)
		piece(c, c.turret, "Antenna", "Tube", "Dark", V(3.6, 0.2, 0.2), c.at(1.7, c.turretTop + 1.8, 1.0) * ALONG_Y)
		piece(c, c.turret, "AntennaTip", "Ball", "Glow", V(0.6, 0.6, 0.6), c.at(1.7, c.turretTop + 3.7, 1.0))
	end,
	Lamps = function(c: Ctx)
		for _, side in { -1, 1 } do
			piece(c, c.hull, "Headlight", "Ball", "Glow", V(1, 1, 1), c.at(2.3 * side, 2.8, -5.5))
		end
	end,
	Exhausts = function(c: Ctx)
		for _, side in { -1, 1 } do
			piece(c, c.hull, "Exhaust", "Tube", "Dark", V(1.4, 0.7, 0.7), c.at(2.9 * side, 4.3, 5.3) * ALONG_Y)
		end
	end,
	Spare = function(c: Ctx)
		piece(c, c.hull, "SpareWheel", "Tube", "Dark", V(0.8, 2.4, 2.4), c.at(0, 2.6, 6.0) * ALONG_Z)
	end,
	-- Round bear ears on the head.
	Ears = function(c: Ctx)
		for _, side in { -1, 1 } do
			piece(c, c.turret, "Ear", "Round", "Main", V(1.6, 1.6, 0.8), c.at(2.0 * side, c.turretTop - 0.2, -0.4))
			piece(c, c.turret, "EarInner", "Round", "Second", V(1.0, 1.0, 0.85), c.at(2.0 * side, c.turretTop - 0.25, -0.45))
		end
	end,
	-- Long floppy bunny ears.
	BunnyEars = function(c: Ctx)
		for _, side in { -1, 1 } do
			local tilt = CFrame.Angles(math.rad(-15), 0, math.rad(-12 * side))
			piece(c, c.turret, "Ear", "Round", "Main", V(1.2, 3.8, 0.7), c.at(1.1 * side, c.turretTop + 1.3, 0.3) * tilt)
			piece(c, c.turret, "EarInner", "Round", "Second", V(0.6, 3.0, 0.75), c.at(1.1 * side, c.turretTop + 1.3, 0.25) * tilt)
		end
	end,
	-- Two big sewing buttons on the nose.
	Buttons = function(c: Ctx)
		for _, side in { -1, 1 } do
			local at = c.at(1.9 * side, 2.8, -5.55)
			piece(c, c.hull, "Button", "Tube", "Trim", V(0.35, 1.5, 1.5), at * ALONG_Z)
			for _, dx in { -0.25, 0.25 } do
				for _, dy in { -0.25, 0.25 } do
					piece(c, c.hull, "ButtonHole", "Ball", "Dark", V(0.22, 0.22, 0.22), c.at(1.9 * side + dx, 2.8 + dy, -5.75))
				end
			end
		end
	end,
	Tail = function(c: Ctx)
		piece(c, c.hull, "Tail", "Ball", "Second", V(1.6, 1.6, 1.6), c.at(0, 3.0, 5.9))
	end,
	-- Dart clip on the roof, dart noses showing at the back.
	Clip = function(c: Ctx)
		Style.slab(c, c.turret, "Clip", "Main", V(2.4, 1.0, 3.0), c.at(0, c.turretTop + 0.5, 0.4))
		-- Four darts lying in the clip: blue foam bodies, round orange tips forward.
		for i = 0, 3 do
			local x = -0.75 + i * 0.5
			piece(c, c.turret, "ClipDart", "Tube", "Trim", V(2.6, 0.42, 0.42), c.at(x, c.turretTop + 1.2, 0.6) * ALONG_Z)
			piece(c, c.turret, "ClipDartTip", "Ball", "Foam", V(0.5, 0.5, 0.5), c.at(x, c.turretTop + 1.2, -0.75))
		end
	end,
	-- Round drum magazine on the side.
	Drum = function(c: Ctx)
		piece(c, c.turret, "Drum", "Tube", "Second", V(1.2, 3.0, 3.0), c.at(2.9, 5.0, 0.6))
		piece(c, c.turret, "DrumCap", "Tube", "Foam", V(1.3, 1.2, 1.2), c.at(2.95, 5.0, 0.6))
	end,
	-- Soft foam bumper across the nose.
	Bumper = function(c: Ctx)
		piece(c, c.hull, "Bumper", "Pill", "Foam", V(8.4, 1.3, 1.1), c.at(0, 1.9, -6.0))
	end,
}

-- Accent: fender stripes and a flag, in team (or line) color.
local function accent(c: Ctx)
	for _, side in { -1, 1 } do
		piece(c, c.hull, "AccentStripe", "Box", "Accent", V(0.3, 0.8, 7.5), c.at(c.side * side, c.stripeY, 0.4))
	end
	piece(c, c.hull, "FlagPole", "Tube", "Dark", V(5.4, 0.25, 0.25), c.at(-3.9, 6.4, 5.0) * ALONG_Y)
	piece(c, c.hull, "Flag", "Box", "Accent", V(0.15, 1.9, 2.9), c.at(-3.9, 8.1, 6.45))
end

-- Dress `anchors` as tank `tankId`. `kit` gives the model, line, accent and layout transform;
-- L and W are the class's barrel length/width multipliers.
function TankLook.dress(kit: Kit, anchors: Anchors, tankId: string, L: number, W: number): Dressed
	local look = TankCatalog.look(tankId)
	local c: Ctx = {
		model = kit.model,
		line = kit.line,
		accent = kit.accent,
		at = kit.at,
		k = kit.k,
		hull = anchors.hull,
		turret = anchors.turret,
		barrel = anchors.barrel,
		L = L,
		W = W,
		side = 4.95,
		stripeY = 3.2,
		turretTop = 6,
		gunAt = function(d: number): number
			return -2.6 - d * L
		end,
	}
	local hull = HULLS[look.Hull] or HULLS.Slab
	local tracks = TRACKS[look.Tracks] or TRACKS.Treads
	local turret = TURRETS[look.Turret] or TURRETS.Dome
	local gun = GUNS[look.Gun] or GUNS.Plain
	hull(c)
	tracks(c)
	turret(c)
	local muzzle = gun(c)
	for _, name in look.Extras do
		local extra = EXTRAS[name]
		if extra then
			extra(c)
		end
	end
	accent(c)
	return { muzzle = muzzle }
end

return TankLook
