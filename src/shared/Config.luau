--!strict
-- All tunable gameplay values. Units: studs, seconds, radians.

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

	-- The tanks players can own. Tier I of each class is the free starter; higher tiers
	-- need a level and coins. Stats = class base (Classes) x Mods x upgrades. Mods keys:
	-- Health, Damage, Reload (cooldown multiplier, <1 = faster), Speed, Turret, Armor
	-- (damage-taken multiplier on every plate, <1 = tougher).
	TankOrder = { "Pip", "Zipper", "Comet", "Biscuit", "Badger", "Ranger", "Boulder", "Rhino", "Fortress" },
	DefaultTank = "Biscuit",
	Tanks = {
		Pip = { Class = "Light", Tier = 1, DisplayName = "Pip", Cost = 0, Mods = {} },
		Zipper = {
			Class = "Light",
			Tier = 2,
			DisplayName = "Zipper",
			Cost = 1500,
			Mods = { Health = 1.1, Damage = 1.1, Speed = 1.08 }, -- even faster
		},
		Comet = {
			Class = "Light",
			Tier = 3,
			DisplayName = "Comet",
			Cost = 4000,
			Mods = { Health = 1.2, Damage = 1.2, Speed = 1.1, Reload = 0.88 }, -- rapid fire
		},
		Biscuit = { Class = "Medium", Tier = 1, DisplayName = "Biscuit", Cost = 0, Mods = {} },
		Badger = {
			Class = "Medium",
			Tier = 2,
			DisplayName = "Badger",
			Cost = 1500,
			Mods = { Health = 1.12, Damage = 1.1, Turret = 1.2 }, -- quick turret
		},
		Ranger = {
			Class = "Medium",
			Tier = 3,
			DisplayName = "Ranger",
			Cost = 4000,
			Mods = { Health = 1.22, Damage = 1.22, Reload = 0.92, Turret = 1.15 },
		},
		Boulder = { Class = "Heavy", Tier = 1, DisplayName = "Boulder", Cost = 0, Mods = {} },
		Rhino = {
			Class = "Heavy",
			Tier = 2,
			DisplayName = "Rhino",
			Cost = 1500,
			Mods = { Health = 1.12, Damage = 1.15, Speed = 1.05 }, -- hits harder
		},
		Fortress = {
			Class = "Heavy",
			Tier = 3,
			DisplayName = "Fortress",
			Cost = 4000,
			Mods = { Health = 1.25, Damage = 1.2, Armor = 0.9 }, -- tougher plates all round
		},
	},

	Progression = {
		-- XP needed to reach level n = XPPerLevelStep * n * (n - 1) / 2  (L2 = 200, L4 = 1200, L8 = 5600)
		XPPerLevelStep = 200,
		MaxLevel = 30,
		TierLevel = { 1, 4, 8 }, -- level needed to buy a tank of tier 1 / 2 / 3
	},

	-- Per-tank upgrades: each track has MaxLevel levels; each level applies its PerLevel
	-- multipliers again (compounding). Cost of level n = Costs[n] x TierCostFactor[tier].
	Upgrades = {
		TrackOrder = { "Gun", "Armor", "Engine" },
		MaxLevel = 3,
		Costs = { 200, 400, 800 },
		TierCostFactor = { 1, 1.5, 2.25 },
		Tracks = {
			Gun = { DisplayName = "Gun", PerLevel = { Damage = 1.05, Reload = 0.97 } },
			Armor = { DisplayName = "Armor", PerLevel = { Health = 1.06 } },
			Engine = { DisplayName = "Engine", PerLevel = { Speed = 1.04 } },
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
		StoreName = "PlayerData_v1", -- bump the suffix to start everyone fresh
	},

	Maps = {
		Rotation = { "Town", "Dockyard", "Orchard" }, -- one map per round, in this order
		BoundaryHeight = 14, -- indestructible arena walls
		BoundaryThickness = 4,
		CoverColor = Color3.fromRGB(95, 105, 140), -- default hard-cover color
		MaxRampAngle = math.rad(10), -- tanks stall on slopes much past ~15 deg (Heavy worst)
		GroundMargin = 200, -- baseplate extends this far past the boundary
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
		AvoidCommitTime = 1.5,
		WalkableNormalY = 0.9, -- surfaces flatter than ~25 deg (ramps) don't count as walls -- keep swerving to the same side this long (follows walls around)
		SteerSoftAngle = math.rad(30), -- heading error that gets full turn input
		StuckSpeed = 1.5, -- below this (studs/s) while driving or turning counts as stuck...
		StuckSpin = 0.15, -- ...if also turning slower than this (rad/s)
		StuckTime = 1.2,
		UnstickTime = 1.0, -- reverse-and-turn duration when stuck
	},

	-- 3v3 elimination, best of 5. Bots fill empty team slots.
	Round = {
		MinPlayers = 1, -- real players needed to start a match (bots fill the rest)
		TeamSize = 3,
		RoundsToWin = 3, -- first to this many round wins takes the match...
		MaxRounds = 5, -- ...or most round wins after this many rounds (draws can stall)
		FirstPreRound = 12, -- countdown before round 1 (tanks frozen, garage open)
		PreRound = 8, -- countdown before later rounds
		Duration = 180, -- round time cap; then the team health % tiebreak decides
		RoundOver = 5, -- round result screen
		MatchOver = 10, -- match result screen
		LiveInterval = 0.25, -- seconds between team alive/health updates to clients
	},

	Teams = {
		Order = { "Red", "Blue" },
		Red = { DisplayName = "Red", Color = Color3.fromRGB(255, 110, 100) },
		Blue = { DisplayName = "Blue", Color = Color3.fromRGB(100, 160, 255) },
	},
}

return Config
