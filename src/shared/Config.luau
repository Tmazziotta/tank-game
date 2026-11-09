--!strict
-- All tunable gameplay values. Units: studs, seconds, radians.

local Config = {
	Tank = {
		MaxForwardSpeed = 30,
		MaxReverseSpeed = 16,
		-- Drive forces are sized from assembly mass so tuning survives model changes.
		DriveAcceleration = 45, -- studs/s^2 along the hull's forward axis
		LateralGrip = 140, -- studs/s^2 of sideways correction (stops sliding)
		TurnRate = math.rad(85), -- hull yaw speed, rad/s
		TurnTorquePerMass = 500, -- yaw torque cap = mass * this
		YawInertiaPerMass = 16, -- yaw moment of inertia estimate = mass * this (~(L^2+W^2)/12)
		YawResponse = 0.5, -- fraction of the yaw-rate error closed per frame (<1 avoids chatter)
		YawFrictionCompensation = 0.28, -- feed-forward torque (fraction of cap) while turning; measured in playtest
		UprightTorquePerMass = 400, -- self-righting torque cap = mass * this (soft: lets the hull rock)
		UprightResponsiveness = 10,
		GroundFriction = 0.15, -- friction on the tank's ground-contact parts
		TurretTraverseSpeed = math.rad(80), -- capped turret speed relative to hull, rad/s
		TurretGain = 7, -- proportional gain from angle error to turret speed
		TurretMaxTorque = 5e5,
		BarrelMinElevation = math.rad(-7), -- depression limit (hinge LowerAngle)
		BarrelMaxElevation = math.rad(22), -- elevation limit (hinge UpperAngle)
		BarrelElevationSpeed = math.rad(45), -- capped pitch speed, rad/s
		BarrelGain = 8,
		BarrelMaxTorque = 2e5,
	},

	Camera = {
		Distance = 34, -- behind the hull
		Height = 18,
		LookAhead = 12, -- look-at point in front of the hull
		LookHeight = 3,
		Smoothing = 6, -- higher = snappier follow
		SpeedPullback = 8, -- extra distance at full forward speed
		SpeedRise = 3, -- extra height at full forward speed
		FieldOfView = 70,
	},

	Weapon = {
		Cooldown = 2.0,
		Range = 600,
		RayBackOffset = 8, -- ray starts this far behind the muzzle so point-blank walls still register
		BlastRadius = 7,
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

	Combat = {
		MaxHealth = 100,
		ShellDamage = 40, -- before armor and angle multipliers
		-- Damage multipliers per plate: front armor > sides > rear.
		FrontArmorMultiplier = 0.6,
		SideArmorMultiplier = 1.0,
		RearArmorMultiplier = 1.5,
		FrontArc = math.rad(45), -- plate normal within this of the facing = front (same for rear)
		-- Impact angle is measured from the plate's surface normal (0 = square-on).
		FullDamageAngle = math.rad(25), -- full damage up to here
		RicochetAngle = math.rad(70), -- at or past this the shell bounces off: no damage
		GrazeMultiplier = 0.5, -- damage multiplier just short of the ricochet angle
		SpawnProtection = 3, -- seconds; firing ends it early
		KillCreditWindow = 15, -- a death this soon after being hit credits the attacker
		WreckBlastRadius = 9, -- a dying tank blows chunks out of nearby walls
	},

	Respawn = {
		Delay = 5, -- Players.RespawnTime
		WreckLifetime = 5,
		WreckLaunchSpeed = 22, -- upward kick given to the hull when it explodes
		TurretPopSpeed = 45, -- the turret flies off
	},

	Round = {
		MinPlayers = 2, -- below this the server waits (players can still drive and shoot)
		Intermission = 10,
		Duration = 180,
		Results = 8,
	},
}

return Config
