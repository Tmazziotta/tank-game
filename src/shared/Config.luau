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
		TurnTorquePerMass = 500, -- AngularVelocity MaxTorque = mass * this
		GroundFriction = 0.15, -- friction on the tank's ground-contact parts
		TurretTraverseSpeed = math.rad(80), -- capped turret speed relative to hull, rad/s
		TurretGain = 7, -- proportional gain from angle error to turret speed
		TurretMaxTorque = 5e5,
	},

	Camera = {
		Distance = 34, -- behind the hull
		Height = 18,
		LookAhead = 12, -- look-at point in front of the hull
		LookHeight = 3,
		Smoothing = 6, -- higher = snappier follow
		FieldOfView = 70,
	},

	Weapon = {
		Cooldown = 2.0,
		Range = 600,
		RayBackOffset = 8, -- ray starts this far behind the muzzle so point-blank walls still register
		BlastRadius = 7,
		BlastImpulse = 65, -- velocity change (studs/s) given to chunks at the blast center
		BlastUpwardBias = 0.35,
		TracerLifetime = 0.18,
	},

	Destruction = {
		ChunkSize = 4, -- wall chunk width/height
		WallThickness = 2,
		RoofThickness = 1,
		DebrisLifetime = 8,
		DebrisFadeTime = 0.6,
		MaxDebris = 500, -- oldest debris is removed early above this
	},
}

return Config
