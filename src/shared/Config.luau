--!strict
-- All tunable gameplay values. Units: studs, seconds, radians.

local RunService = game:GetService("RunService")

local Config = {
	-- Physics shared by every tank. Per-class stats (speed, armor, gun...) live in Classes.
	Tank = {
		-- Drive forces are sized from assembly mass so tuning survives model changes.
		LateralGrip = 140, -- studs/s^2 of sideways correction (stops sliding)
		TurnTorquePerMass = 500, -- yaw torque cap = mass * this
		YawInertiaPerMass = 16, -- yaw inertia estimate = mass * this * scale^2 (~(L^2+W^2)/12)
		YawResponse = 0.5, -- fraction of the yaw-rate error closed per frame (<1 avoids chatter)
		YawFrictionCompensation = 0.28, -- feed-forward torque (fraction of cap) while turning; measured in playtest
		UprightTorquePerMass = 400, -- self-righting torque cap = mass * this (soft: lets the hull rock)
		UprightResponsiveness = 10,
		GroundFriction = 0.15, -- friction on the tank's ground-contact parts
		TurretGain = 7, -- proportional gain from angle error to turret speed
		TurretMaxTorque = 5e5,
		BarrelMinElevation = math.rad(-7), -- depression limit (hinge LowerAngle)
		BarrelMaxElevation = math.rad(22), -- elevation limit (hinge UpperAngle)
		BarrelElevationSpeed = math.rad(45), -- capped pitch speed, rad/s
		BarrelGain = 8,
		BarrelMaxTorque = 2e5,
	},

	Camera = {
		-- Mouse-look orbit around the tank; the screen center is the aim point.
		MouseSensitivity = math.rad(0.25), -- radians of camera turn per pixel of mouse movement
		TouchSensitivity = math.rad(0.3), -- radians per pixel of look-drag on touch screens
		DefaultPitch = math.rad(-10), -- negative = looking down
		MinPitch = math.rad(-40),
		MaxPitch = math.rad(15),
		Distance = 30, -- orbit radius around the focus point
		FocusHeight = 5, -- orbit focus above the hull center
		Lift = 5, -- extra camera height so the tank sits below the crosshair
		Smoothing = 10, -- position follow; higher = snappier (rotation is never smoothed)
		SpeedPullback = 8, -- extra distance at full forward speed
		SizeFollow = 0.5, -- 0 = same camera for every class, 1 = scales fully with tank size
		FieldOfView = 70,
		-- Scope (Shift toggles): camera on the turret, zoomed, slower mouse.
		ScopeZoom = 4, -- field of view divided by this; mouse sensitivity too
		ScopeHeight = 2.5, -- camera height above the turret center (x tank scale)
	},

	Weapon = {
		Range = 900, -- max shell flight distance
		ShellSpeed = 500, -- studs/s: shells take time to arrive, so lead moving targets at range
		ShellGravity = 20, -- studs/s^2 drop; aim is auto-compensated for stationary targets
		ShellStep = 0.1, -- seconds per segment when tracing a predicted path (barrel marker)
		RayBackOffset = 8, -- ray starts this far behind the muzzle so point-blank walls still register
		BlastImpulse = 90, -- velocity change (studs/s) given to chunks at the blast center
		BlastUpwardBias = 0.5,
		TracerLifetime = 0.18, -- ricochet streak
	},

	Destruction = {
		ChunkSize = 4, -- wall chunk width/height
		WallThickness = 2,
		RoofThickness = 1,
		DebrisLifetime = 8,
		DebrisFadeTime = 0.6,
		MaxDebris = 500, -- oldest debris is removed early above this
		-- Sag: a chunk with nothing welded beneath it falls once it has fewer welds than this.
		-- Intact buildings have at least 3 on every such chunk (e.g. above windows/doors).
		MinWeldsWhenUnsupported = 3,
		CollapsePasses = 4, -- cascade depth per blast; caps chain reactions
	},

	-- Tank classes (see DESIGN.md roster). Armor values are damage-TAKEN multipliers per
	-- plate, so lower = tougher; front < side < rear for every class. Damage is per shell
	-- before armor and impact-angle multipliers.
	ClassOrder = { "Light", "Medium", "Heavy" },
	DefaultClass = "Medium",
	Classes = {
		Light = {
			DisplayName = "Light",
			Role = "Fast flanker. Paper armor, low damage.",
			MaxHealth = 75,
			FrontArmor = 0.9,
			SideArmor = 1.2,
			RearArmor = 1.6,
			MaxForwardSpeed = 42,
			MaxReverseSpeed = 22,
			DriveAcceleration = 70, -- studs/s^2
			TurnRate = math.rad(115), -- hull yaw speed, rad/s
			TurretTraverseSpeed = math.rad(120), -- rad/s relative to hull
			Damage = 25,
			Cooldown = 1.2,
			BlastRadius = 5,
			Scale = 0.8, -- model size
			BarrelLength = 0.8, -- multiplier on the base barrel
			BarrelWidth = 0.8,
			Trim = "Antenna",
		},
		Medium = {
			DisplayName = "Medium",
			Role = "All-rounder. Jack of all trades.",
			MaxHealth = 100,
			FrontArmor = 0.6,
			SideArmor = 1.0,
			RearArmor = 1.5,
			MaxForwardSpeed = 30,
			MaxReverseSpeed = 16,
			DriveAcceleration = 45,
			TurnRate = math.rad(85),
			TurretTraverseSpeed = math.rad(80),
			Damage = 40,
			Cooldown = 2.0,
			BlastRadius = 7,
			Scale = 1,
			BarrelLength = 1,
			BarrelWidth = 1,
			Trim = "None",
		},
		Heavy = {
			DisplayName = "Heavy",
			Role = "Frontline brawler. Slow, big target.",
			MaxHealth = 150,
			FrontArmor = 0.45,
			SideArmor = 0.9,
			RearArmor = 1.4,
			MaxForwardSpeed = 20,
			MaxReverseSpeed = 11,
			DriveAcceleration = 30,
			TurnRate = math.rad(55),
			TurretTraverseSpeed = math.rad(50),
			Damage = 60,
			Cooldown = 3.0,
			BlastRadius = 9,
			Scale = 1.25,
			BarrelLength = 1.3,
			BarrelWidth = 1.35,
			Trim = "Skirts",
		},
	},

	-- Toy lines (DESIGN.md "Toy lines"). Each line multiplies its tanks' class stats by its
	-- Mods (same keys as tank Mods below) and has its own behavior-mod library.
	-- Tank looks (TankLook): each line's palette and materials, and the blueprint a tank uses
	-- when its Tanks entry has no Look. Blueprint parts: Tracks, Hull, Turret, Gun, Extras.
	-- The team (or, in the Garage, the line) color goes on a flag and fender stripes.
	Looks = {
		Palettes = {
			Brick = {
				Main = Color3.fromRGB(214, 72, 52),
				Second = Color3.fromRGB(245, 190, 40),
				Trim = Color3.fromRGB(45, 115, 210),
				Dark = Color3.fromRGB(55, 58, 68),
				Light = Color3.fromRGB(255, 244, 170),
				Foam = Color3.fromRGB(245, 190, 40),
			},
			Plush = {
				Main = Color3.fromRGB(236, 150, 190),
				Second = Color3.fromRGB(252, 232, 214),
				Trim = Color3.fromRGB(176, 150, 224),
				Dark = Color3.fromRGB(96, 70, 92),
				Light = Color3.fromRGB(255, 255, 255),
				Foam = Color3.fromRGB(252, 232, 214),
			},
			Foam = {
				Main = Color3.fromRGB(255, 150, 40),
				Second = Color3.fromRGB(60, 130, 230),
				Trim = Color3.fromRGB(170, 222, 60),
				Dark = Color3.fromRGB(46, 52, 72),
				Light = Color3.fromRGB(255, 236, 120),
				Foam = Color3.fromRGB(255, 120, 30), -- dart tips
				Noodle = Color3.fromRGB(60, 130, 230), -- foam bumper tubes
			},
		},
		Materials = {
			Brick = Enum.Material.Plastic,
			Plush = Enum.Material.Fabric,
			Foam = Enum.Material.SmoothPlastic, -- blaster shell; "Foam" parts use FoamMaterial
		},
		FoamMaterial = Enum.Material.Rubber,
		BrickSeam = 0.22, -- Brick blocks shrink by this so the joins between them show
		Brick = { CourseHeight = 0.9, BrickLength = 2.6, BrickWidth = 5 }, -- slab brick sizes
		Foam = { EdgeRound = 0.4, NoodleSize = 1.3 }, -- shell edge radius (x thinner side), bumper tube
		Defaults = {
			Brick = {
				Light = { Tracks = "Wheels", Hull = "Slab", Turret = "Box", Gun = "Plain", Extras = { "Antenna" } },
				Medium = { Tracks = "Treads", Hull = "Slab", Turret = "Box", Gun = "Plain", Extras = {} },
				Heavy = { Tracks = "Skirted", Hull = "Long", Turret = "Wide", Gun = "Stubby", Extras = {} },
			},
			Plush = {
				Light = { Tracks = "Treads", Hull = "Round", Turret = "Head", Gun = "Snout", Extras = { "Ears" } },
				Medium = { Tracks = "Treads", Hull = "Round", Turret = "Head", Gun = "Snout", Extras = { "Ears" } },
				Heavy = { Tracks = "Skirted", Hull = "Round", Turret = "Head", Gun = "Stubby", Extras = { "Ears" } },
			},
			Foam = {
				Light = { Tracks = "Wheels", Hull = "Wedge", Turret = "Blaster", Gun = "Dart", Extras = {} },
				Medium = { Tracks = "Treads", Hull = "Wedge", Turret = "Blaster", Gun = "Dart", Extras = {} },
				Heavy = { Tracks = "Skirted", Hull = "Long", Turret = "Blaster", Gun = "Dart", Extras = {} },
			},
		},
	},

	-- Line signatures: what every tank of a line does, before any mods.
	Signatures = {
		Brick = {
			ChipsPerHit = 3, -- bricks knocked off the hull by each damaging hit
			ChipSize = Vector3.new(1.2, 0.7, 0.8),
			ChipSpeed = 28, -- studs/s they fly off at
		},
		Plush = {
			HopSpeed = 42, -- upward velocity change of a hop (Space / HOP button)
			HopCooldown = 2.5,
			GroundProbe = 1.5, -- hull must be within this of the ground to hop
			BounceMinSpeed = 12, -- wall bounce only above this speed into the wall
			BounceRestitution = 0.8, -- fraction of the into-wall speed bounced back
			BouncePop = 8, -- small upward kick on a bounce
			BounceLoose = 0.35, -- seconds the drive lets go after a bounce so it carries
		},
		Foam = {
			ClipSize = 4, -- darts per clip
			DartInterval = 0.25, -- seconds between darts in a clip
			-- Clip reload = the tank's per-dart Cooldown x ClipSize, timed from the last dart
			-- (an unfinished clip also tops up after that long without firing).
		},
	},

	Lines = {
		Order = { "Brick", "Plush", "Foam" },
		Defs = {
			Brick = {
				DisplayName = "Brick Co.",
				Color = Color3.fromRGB(214, 72, 52),
				Blurb = "Snap-together block tanks. Tough armor, slow tracks.",
				Mods = { Health = 1.15, Armor = 0.9, Speed = 0.9 },
			},
			Plush = {
				DisplayName = "Plush Patrol",
				Color = Color3.fromRGB(236, 132, 186),
				Blurb = "Stitched stuffed animals. Fast and bouncy, but fragile.",
				Mods = { Health = 0.85, Speed = 1.15, Turret = 1.1 },
			},
			Foam = {
				DisplayName = "Foam Force",
				Color = Color3.fromRGB(255, 150, 40),
				Blurb = "Dart blasters. Rapid fire, low damage per dart.",
				Mods = { Damage = 0.6, Reload = 0.6 },
			},
		},
	},

	-- The 21 tanks: per line, a tier 1 light starter; tier 2 light/medium/heavy all from it;
	-- tier 3 of each class from the same class at tier 2 (Parent). Stats = class base x line
	-- Mods x TierScale x the tank's own Mods x equipped stat mods. Mods keys: Health, Damage,
	-- Reload (cooldown multiplier, <1 = faster), Speed, Turret, Armor (damage taken, <1 =
	-- tougher). ModRows = the tank's mod rows 3 and 4 (pick 1 of 2), from its line's library.
	TankOrder = {
		"Chip", "Clicker", "Stacker", "Bulwark", "Dasher", "Mason", "Castellan",
		"Button", "Bunbun", "Cubby", "Grizzle", "Hopscotch", "Patches", "BigHug",
		"Pew", "Zinger", "Blaster", "Thumper", "Whizbang", "Volley", "Megadart",
	},
	DefaultTank = "Chip", -- fallback for unknown ids (display, test dummies)
	TierScale = { 1, 1.25, 1.55 }, -- Health and Damage per tier: stock beats last tier fully modded
	StarterLevel = 3, -- player level to buy another line's tier 1 starter
	StarterCost = 500,
	Tanks = {
		-- Brick Co.
		Chip = { Look = { Tracks = "Wheels", Hull = "Slab", Turret = "Box", Gun = "Plain", Extras = { "Antenna", "Lamps" } },
			Line = "Brick", Class = "Light", Tier = 1, DisplayName = "Chip", Cost = 0, Mods = {},
			ModRows = { { "BrickWall", "SpareParts" }, { "RamPlate", "Interlock" } } },
		Clicker = { Line = "Brick", Class = "Light", Tier = 2, Parent = "Chip", DisplayName = "Clicker", Cost = 1500,
			Mods = { Speed = 1.05 }, ModRows = { { "SpareParts", "HeavyBricks" }, { "RamPlate", "ClusterBrick" } } },
		Stacker = { Line = "Brick", Class = "Medium", Tier = 2, Parent = "Chip", DisplayName = "Stacker", Cost = 1500,
			Mods = {}, ModRows = { { "BrickWall", "Rebuild" }, { "Interlock", "ClusterBrick" } } },
		Bulwark = { Line = "Brick", Class = "Heavy", Tier = 2, Parent = "Chip", DisplayName = "Bulwark", Cost = 1500,
			Mods = { Armor = 0.95 }, ModRows = { { "Fortify", "Rebuild" }, { "RamPlate", "HeavyBricks" } } },
		Dasher = { Line = "Brick", Class = "Light", Tier = 3, Parent = "Clicker", DisplayName = "Dasher", Cost = 4000,
			Mods = { Speed = 1.05 }, ModRows = { { "SpareParts", "ClusterBrick" }, { "RamPlate", "HeavyBricks" } } },
		Mason = { Line = "Brick", Class = "Medium", Tier = 3, Parent = "Stacker", DisplayName = "Mason", Cost = 4000,
			Mods = { Reload = 0.95 }, ModRows = { { "BrickWall", "Interlock" }, { "Rebuild", "ClusterBrick" } } },
		Castellan = { Line = "Brick", Class = "Heavy", Tier = 3, Parent = "Bulwark", DisplayName = "Castellan", Cost = 4000,
			Mods = { Armor = 0.92 }, ModRows = { { "Fortify", "BrickWall" }, { "RamPlate", "Interlock" } } },
		-- Plush Patrol
		Button = { Look = { Tracks = "Treads", Hull = "Round", Turret = "Head", Gun = "Snout", Extras = { "Ears", "Buttons", "Tail" } },
			Line = "Plush", Class = "Light", Tier = 1, DisplayName = "Button", Cost = 0, Mods = {},
			ModRows = { { "DoubleHop", "FluffArmor" }, { "Bouncy", "SqueakyDecoy" } } },
		Bunbun = { Line = "Plush", Class = "Light", Tier = 2, Parent = "Button", DisplayName = "Bunbun", Cost = 1500,
			Mods = { Speed = 1.05 }, ModRows = { { "DoubleHop", "Zoomies" }, { "Pounce", "SqueakyDecoy" } } },
		Cubby = { Line = "Plush", Class = "Medium", Tier = 2, Parent = "Button", DisplayName = "Cubby", Cost = 1500,
			Mods = {}, ModRows = { { "FluffArmor", "Cuddle" }, { "Bouncy", "StuffingBurst" } } },
		Grizzle = { Line = "Plush", Class = "Heavy", Tier = 2, Parent = "Button", DisplayName = "Grizzle", Cost = 1500,
			Mods = { Health = 1.05 }, ModRows = { { "Cuddle", "FluffArmor" }, { "StuffingBurst", "Pounce" } } },
		Hopscotch = { Line = "Plush", Class = "Light", Tier = 3, Parent = "Bunbun", DisplayName = "Hopscotch", Cost = 4000,
			Mods = { Speed = 1.05 }, ModRows = { { "Zoomies", "DoubleHop" }, { "Pounce", "Bouncy" } } },
		Patches = { Line = "Plush", Class = "Medium", Tier = 3, Parent = "Cubby", DisplayName = "Patches", Cost = 4000,
			Mods = { Turret = 1.1 }, ModRows = { { "SqueakyDecoy", "FluffArmor" }, { "StuffingBurst", "Zoomies" } } },
		BigHug = { Line = "Plush", Class = "Heavy", Tier = 3, Parent = "Grizzle", DisplayName = "Big Hug", Cost = 4000,
			Mods = { Health = 1.05 }, ModRows = { { "Cuddle", "StuffingBurst" }, { "Bouncy", "SqueakyDecoy" } } },
		-- Foam Force
		Pew = { Look = { Tracks = "Wheels", Hull = "Wedge", Turret = "Blaster", Gun = "Dart", Extras = { "Clip", "Bumper" } },
			Line = "Foam", Class = "Light", Tier = 1, DisplayName = "Pew", Cost = 0, Mods = {},
			ModRows = { { "StickyDarts", "SpeedLoader" }, { "MegaDart", "SplitDart" } } },
		Zinger = { Line = "Foam", Class = "Light", Tier = 2, Parent = "Pew", DisplayName = "Zinger", Cost = 1500,
			Mods = { Speed = 1.05 }, ModRows = { { "SpeedLoader", "HoverDarts" }, { "SplitDart", "Ricochet" } } },
		Blaster = { Line = "Foam", Class = "Medium", Tier = 2, Parent = "Pew", DisplayName = "Blaster", Cost = 1500,
			Mods = {}, ModRows = { { "StickyDarts", "DrumMag" }, { "MegaDart", "Suction" } } },
		Thumper = { Line = "Foam", Class = "Heavy", Tier = 2, Parent = "Pew", DisplayName = "Thumper", Cost = 1500,
			Mods = { Damage = 1.05 }, ModRows = { { "DrumMag", "Suction" }, { "MegaDart", "Ricochet" } } },
		Whizbang = { Line = "Foam", Class = "Light", Tier = 3, Parent = "Zinger", DisplayName = "Whizbang", Cost = 4000,
			Mods = { Reload = 0.95 }, ModRows = { { "HoverDarts", "StickyDarts" }, { "SplitDart", "SpeedLoader" } } },
		Volley = { Line = "Foam", Class = "Medium", Tier = 3, Parent = "Blaster", DisplayName = "Volley", Cost = 4000,
			Mods = { Reload = 0.95 }, ModRows = { { "DrumMag", "Ricochet" }, { "SplitDart", "MegaDart" } } },
		Megadart = { Line = "Foam", Class = "Heavy", Tier = 3, Parent = "Thumper", DisplayName = "Megadart", Cost = 4000,
			Mods = { Damage = 1.05 }, ModRows = { { "Suction", "StickyDarts" }, { "MegaDart", "HoverDarts" } } },
	},

	Progression = {
		-- XP needed to reach level n = XPPerLevelStep * n * (n - 1) / 2  (L2 = 200, L4 = 1200, L8 = 5600)
		XPPerLevelStep = 200,
		MaxLevel = 30,
	},

	-- Per-tank mod trees (DESIGN.md "Mod trees"): Rows rows, pick 1 of 2 per row. Unlocking a
	-- mod spends that tank's XP (it earns XP while you drive it); a row opens once the row
	-- above has a mod unlocked. Elite = every row has one unlocked, which unlocks the tanks
	-- it leads to. Rows 1-2 are the same stat sidegrades on every tank; rows 3-4 are the
	-- tank's ModRows. Stats = multipliers (tank Mods keys); Behavior = a hook the match runs.
	Mods = {
		Rows = 4,
		RowXP = { 150, 300, 500, 800 }, -- tank XP per unlock in each row, at tier 1
		TierXPFactor = { 1, 1.6, 2.4 },
		CommonRows = { { "QuickLoader", "HeavyShells" }, { "ThickPlates", "TunedEngine" } },
		Defs = {
			-- Stat sidegrades (every tank)
			QuickLoader = { DisplayName = "Quick Loader", Blurb = "Reload 10% faster.", Stats = { Reload = 0.9 } },
			HeavyShells = { DisplayName = "Heavy Shells", Blurb = "10% more damage per shot.", Stats = { Damage = 1.1 } },
			ThickPlates = { DisplayName = "Thick Plates", Blurb = "10% more health.", Stats = { Health = 1.1 } },
			TunedEngine = { DisplayName = "Tuned Engine", Blurb = "8% faster driving.", Stats = { Speed = 1.08 } },
			-- Brick Co.
			BrickWall = { DisplayName = "Brick Wall", Blurb = "Bricks knocked off you stack into a wall behind you.", Behavior = "BrickWall" },
			RamPlate = { DisplayName = "Ram Plate", Blurb = "Ramming breaks walls and damages tanks.", Behavior = "RamPlate" },
			Rebuild = { DisplayName = "Rebuild", Blurb = "Slowly snap lost health back on when not hit for a while.", Behavior = "Rebuild" },
			HeavyBricks = { DisplayName = "Heavy Bricks", Blurb = "Your shells knock tanks back.", Behavior = "HeavyBricks" },
			Interlock = { DisplayName = "Interlock", Blurb = "Take less damage while standing still.", Behavior = "Interlock" },
			ClusterBrick = { DisplayName = "Cluster Brick", Blurb = "Shells burst into bricks: bigger blast.", Behavior = "ClusterBrick" },
			SpareParts = { DisplayName = "Spare Parts", Blurb = "Repair some health on every kill.", Behavior = "SpareParts" },
			Fortify = { DisplayName = "Fortify", Blurb = "Tougher front plate, weaker rear.", Behavior = "Fortify" },
			-- Plush Patrol
			DoubleHop = { DisplayName = "Double Hop", Blurb = "Hop again in mid-air.", Behavior = "DoubleHop" },
			SqueakyDecoy = { DisplayName = "Squeaky Decoy", Blurb = "Drop a squeaky plush that draws enemy fire.", Behavior = "SqueakyDecoy" },
			Bouncy = { DisplayName = "Bouncy", Blurb = "Bounce off walls with a burst of speed.", Behavior = "Bouncy" },
			Cuddle = { DisplayName = "Cuddle", Blurb = "Ramming an enemy hurts them and heals you.", Behavior = "Cuddle" },
			StuffingBurst = { DisplayName = "Stuffing Burst", Blurb = "When destroyed, your stuffing heals nearby teammates.", Behavior = "StuffingBurst" },
			FluffArmor = { DisplayName = "Fluff Armor", Blurb = "The first hit each round does half damage.", Behavior = "FluffArmor" },
			Zoomies = { DisplayName = "Zoomies", Blurb = "Speed burst after every kill.", Behavior = "Zoomies" },
			Pounce = { DisplayName = "Pounce", Blurb = "Hop lunges you forward.", Behavior = "Pounce" },
			-- Foam Force
			StickyDarts = { DisplayName = "Sticky Darts", Blurb = "Hits slow the target for a moment.", Behavior = "StickyDarts" },
			MegaDart = { DisplayName = "Mega Dart", Blurb = "The last dart in each clip is a big one.", Behavior = "MegaDart" },
			DrumMag = { DisplayName = "Drum Mag", Blurb = "Bigger clip, longer reload.", Behavior = "DrumMag" },
			SplitDart = { DisplayName = "Split Dart", Blurb = "Fire three darts in a spread.", Behavior = "SplitDart" },
			SpeedLoader = { DisplayName = "Speed Loader", Blurb = "Reload a clip much faster.", Behavior = "SpeedLoader" },
			Ricochet = { DisplayName = "Ricochet", Blurb = "Darts bounce once off walls.", Behavior = "Ricochet" },
			Suction = { DisplayName = "Suction Cups", Blurb = "Darts stick and deal damage over time.", Behavior = "Suction" },
			HoverDarts = { DisplayName = "Hover Darts", Blurb = "Faster darts with no drop.", Behavior = "HoverDarts" },
		},
	},
	Economy = {
		KillCoins = 25,
		KillXP = 50,
		RoundWinCoins = 30, -- each player on the team that wins a round
		RoundWinXP = 40,
		MatchWinCoins = 100, -- each player on the team that wins the match
		MatchWinXP = 150,
		MatchCoins = 20, -- everyone present when a match ends
		MatchXP = 50,
		PlaytimeInterval = 60, -- seconds alive in an active round per playtime reward
		PlaytimeCoins = 5,
		PlaytimeXP = 10,
	},

	Data = {
		StoreName = "PlayerData_v2", -- bump the suffix to start everyone fresh (v2: toy lines)
	},

	-- The experience's places. The Garage is the start place; PLAY teleports to a reserved
	-- Match server. In dev mode (on in Studio, where a teleport would load the *published*
	-- place rather than your synced code) one server runs both: PLAY moves you into the
	-- arena instead.
	Places = {
		GaragePlaceId = 134500042163643,
		MatchPlaceId = 117097211658942,
		DevMode = RunService:IsStudio(),
		MatchGracePeriod = 5, -- Match place: wait this long after the first arrival before starting
		TeleportAttempts = 2, -- tries per teleport (one retry), then give up
		TeleportRetryDelay = 1.5,
	},

	-- The Garage: a kid's desk with your tank on a cardboard turntable (built per client).
	Garage = {
		ScenePosition = Vector3.new(0, 400, 3000), -- desk-top center, far from any arena
				SpinSpeed = math.rad(18), -- idle turntable spin, per second
		DragSpeed = math.rad(0.45), -- turntable yaw per pixel dragged
		SpinResumeDelay = 1.5, -- seconds after a drag before the idle spin resumes
		CameraOffset = Vector3.new(0, 11, 30), -- from the turntable center
		CameraLookHeight = 5, -- camera aims this far above the turntable center
		FieldOfView = 50,
		LoadoutSlots = 3, -- tanks in the garage carousel (a game pass adds one, later)
		LockedSlots = 1, -- extra slots shown locked (the game pass), after the real ones
		StatPips = 5, -- pips per stat bar on the tank card
	},

	Maps = {
		Rotation = { "Town", "Dockyard", "Orchard" }, -- one map per round, in this order
		BoundaryHeight = 14, -- indestructible arena walls
		BoundaryThickness = 4,
		CoverColor = Color3.fromRGB(95, 105, 140), -- default hard-cover color
		MaxRampAngle = math.rad(10), -- tanks stall on slopes much past ~15 deg (Heavy worst)
		GroundMargin = 200, -- baseplate extends this far past the boundary
	},

	-- Ground surfaces change how tanks drive: multipliers on top speed, acceleration (drive
	-- force), sideways grip and turn rate. Brake (optional, defaults to Accel) is the drive
	-- force while coasting: low on ice, so tanks keep sliding. A ground part's "Surface" attribute picks the
	-- kind; otherwise its material does (terrain included).
	Surfaces = {
		Kinds = {
			Normal = { Speed = 1, Accel = 1, Grip = 1, Turn = 1 },
			Road = { Speed = 1.15, Accel = 1.1, Grip = 1, Turn = 1 },
			Gravel = { Speed = 0.9, Accel = 0.85, Grip = 0.85, Turn = 0.95 },
			Sand = { Speed = 0.75, Accel = 0.7, Grip = 0.9, Turn = 0.85 },
			Mud = { Speed = 0.5, Accel = 0.5, Grip = 0.8, Turn = 0.6 },
			Ice = { Speed = 1, Accel = 0.3, Brake = 0.03, Grip = 0.04, Turn = 0.7 }, -- slides, drifts, slow to stop
			Ford = { Speed = 0.55, Accel = 0.6, Grip = 0.9, Turn = 0.75 }, -- shallow water
		},
		Materials = {
			[Enum.Material.Mud] = "Mud",
			[Enum.Material.Ice] = "Ice",
			[Enum.Material.Glacier] = "Ice",
			[Enum.Material.Cobblestone] = "Road",
			[Enum.Material.Asphalt] = "Road",
			[Enum.Material.Pebble] = "Gravel",
			[Enum.Material.Sand] = "Sand",
		},
		ProbeInterval = 0.1, -- seconds between checks of what's under a tank
		ProbeDepth = 8, -- studs below the hull center
	},

	Hazards = {
		WaterCheckInterval = 0.15,
		MineTriggerRadius = 4.5, -- a hull this close (flat distance) sets a mine off
		MineDamage = 60, -- at the center; falls to half at the edge of the blast
		MineBlastRadius = 11,
		MineChainDelay = 0.15, -- a mine caught in a blast goes off this much later
		MineChainRadius = 5, -- a mine sets off neighbors this close (less than the spacing, so
		-- one mine doesn't clear a whole field; a shell blast clears a local path)
		MineSpacing = 8, -- minimum distance between mines in a field
		MineCheckInterval = 0.05,
	},

	Terrain = {
		MountainStart = 10, -- studs past the boundary before mountains begin
		MountainRise = 70, -- studs over which they reach full height
	},

	Props = {
		CrateSize = 4.5,
		FenceSegment = 8, -- studs per fence piece (each breaks separately)
		CrushInterval = 0.1, -- seconds between tank-vs-prop overlap checks
		CrushMinPush = 12, -- studs/s a crushed prop is thrown at, at minimum
		CrushPushFactor = 1.2, -- x tank speed
		Density = 0.3, -- debris density, so tanks shove broken props aside
	},

	Combat = {
		FrontArc = math.rad(45), -- plate normal within this of the facing = front (same for rear)
		-- Impact angle is measured from the plate's surface normal (0 = square-on).
		FullDamageAngle = math.rad(25), -- full damage up to here
		RicochetAngle = math.rad(70), -- at or past this the shell bounces off: no damage
		GrazeMultiplier = 0.5, -- damage multiplier just short of the ricochet angle
		SpawnProtection = 3, -- seconds; firing ends it early
		TankSwitchCooldown = 1, -- seconds between tank changes that respawn you
		KillCreditWindow = 15, -- a death this soon after being hit credits the attacker
		WreckBlastRadius = 9, -- a dying tank blows chunks out of nearby walls
	},

	Respawn = {
		WreckLifetime = 5,
		WreckLaunchSpeed = 22, -- upward kick given to the hull when it explodes
		TurretPopSpeed = 45, -- the turret flies off
	},

	Bots = {
		-- Fighting distance: close in beyond MaxRange, back off inside MinRange, circle between.
		MinRange = 35,
		MaxRange = 150,
		BackoffMargin = 10, -- once backing off, keep going until MinRange + this
		OrbitAngle = math.rad(60), -- heading offset from the target while circling (angles the armor)
		OrbitFlipMin = 4, -- seconds between switching circling direction (random in range)
		OrbitFlipMax = 9,
		CircleThrottle = 0.6,
		ReactionTime = 0.8, -- seconds a target must be in sight before the first shot
		AimScatter = 2.5, -- studs of random aim offset, re-rolled after every shot
		AimTolerance = math.rad(3), -- fire once the barrel is this close to the aim point
		BreachRange = 35, -- shoot destructible walls this close when they hide the target
		RetargetInterval = 0.5,
		HiddenTargetPenalty = 120, -- studs added to a target's distance when it is out of sight
		AvoidDistance = 14, -- look-ahead for walls
		AvoidRadius = 4.5, -- sphere cast radius: about half the tank's width
		AvoidCommitTime = 1.5, -- keep swerving to the same side this long (follows walls around)
		HazardLookahead = 18, -- studs ahead checked for deep water and minefields
		RouteSampleSpacing = 10, -- studs between deep-water checks on the line to a target
		RouteReach = 12, -- a detour point counts as reached this close
		WalkableNormalY = 0.9, -- surfaces flatter than ~25 deg (ramps) don't count as walls
		SteerSoftAngle = math.rad(30), -- heading error that gets full turn input
		StuckSpeed = 1.5, -- below this (studs/s) while driving or turning counts as stuck...
		StuckSpin = 0.15, -- ...if also turning slower than this (rad/s)
		StuckTime = 1.2,
		StallTime = 3, -- driving but not moving this long (even while turning) also counts as stuck
		UnstickTime = 1.0, -- reverse-and-turn duration when stuck
	},

	-- 4v4 elimination, best of 5. Bots fill empty team slots.
	Round = {
		MinPlayers = 1, -- real players needed to start a match (bots fill the rest)
		TeamSize = 4, -- 8-player servers (set Max Players to 8 in Game Settings)
		RoundsToWin = 3, -- first to this many round wins takes the match...
		MaxRounds = 5, -- ...or most round wins after this many rounds (draws can stall)
		FirstPreRound = 12, -- countdown before round 1 (tanks frozen, garage open)
		PreRound = 8, -- countdown before later rounds
		Duration = 180, -- round time cap; then the team health % tiebreak decides
		RoundOver = 5, -- round result screen
		MatchOver = 10, -- match result screen
		LiveInterval = 0.25, -- seconds between team alive/health updates to clients
	},

	-- How teams show in a match (DESIGN: Team identity): an outline + nameplate color relative
	-- to you. Blue vs orange-red stays distinct under protan/deutan/tritan simulation
	-- (CIELAB difference > 100 for each).
	TeamIdentity = {
		Ally = Color3.fromRGB(45, 150, 255),
		Enemy = Color3.fromRGB(255, 95, 35),
		OutlineTransparency = 0,
		-- Tint over the line's paint: faint up close, stronger far away so distant tanks
		-- (tiny on phones) still read as ally / enemy.
		FillNear = 0.85,
		FillFar = 0.45,
		FillNearDistance = 60,
		FillFarDistance = 260,
	},

	Teams = {
		Order = { "Red", "Blue" },
		Red = { DisplayName = "Red", Color = Color3.fromRGB(255, 110, 100) },
		Blue = { DisplayName = "Blue", Color = Color3.fromRGB(100, 160, 255) },
	},
}

return Config
