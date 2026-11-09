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
	},

	Weapon = {
		Range = 600,
		RayBackOffset = 8, -- ray starts this far behind the muzzle so point-blank walls still register
		BlastImpulse = 90, -- velocity change (studs/s) given to chunks at the blast center
		BlastUpwardBias = 0.5,
		TracerLifetime = 0.18,
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

	Combat = {
		FrontArc = math.rad(45), -- plate normal within this of the facing = front (same for rear)
		-- Impact angle is measured from the plate's surface normal (0 = square-on).
		FullDamageAngle = math.rad(25), -- full damage up to here
		RicochetAngle = math.rad(70), -- at or past this the shell bounces off: no damage
		GrazeMultiplier = 0.5, -- damage multiplier just short of the ricochet angle
		SpawnProtection = 3, -- seconds; firing ends it early
		ClassSwitchCooldown = 1, -- seconds between class changes that respawn you
		KillCreditWindow = 15, -- a death this soon after being hit credits the attacker
		WreckBlastRadius = 9, -- a dying tank blows chunks out of nearby walls
	},

	Respawn = {
		Delay = 5, -- Players.RespawnTime
		WreckLifetime = 5,
		WreckLaunchSpeed = 22, -- upward kick given to the hull when it explodes
		TurretPopSpeed = 45, -- the turret flies off
	},

	Bots = {
		Count = 0, -- AI tanks on live servers
		StudioCount = 1, -- Studio playtests get this many, so solo testing has an opponent
		Color = Color3.fromRGB(150, 155, 170),
		-- Fighting distance: close in beyond MaxRange, back off inside MinRange, circle between.
		MinRange = 28,
		MaxRange = 80,
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
		HiddenTargetPenalty = 60, -- studs added to a target's distance when it is out of sight
		AvoidDistance = 14, -- look-ahead for walls
		AvoidRadius = 4.5, -- sphere cast radius: about half the tank's width
		AvoidCommitTime = 1.5, -- keep swerving to the same side this long (follows walls around)
		SteerSoftAngle = math.rad(30), -- heading error that gets full turn input
		StuckSpeed = 1.5, -- below this (studs/s) while driving or turning counts as stuck...
		StuckSpin = 0.15, -- ...if also turning slower than this (rad/s)
		StuckTime = 1.2,
		UnstickTime = 1.0, -- reverse-and-turn duration when stuck
		WanderRadius = 90, -- around the arena center, when there is no one to fight
	},

	Round = {
		MinPlayers = 2, -- below this the server waits (players can still drive and shoot)
		Intermission = 10,
		Duration = 180,
		Results = 8,
	},
}

return Config
