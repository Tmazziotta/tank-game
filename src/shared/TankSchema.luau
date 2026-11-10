--!strict
-- Instance names shared by the server-side tank builder and the client controller.

return {
	OwnerAttribute = "OwnerUserId",
	Hull = "Hull",
	Turret = "Turret",
	Barrel = "Barrel",
	Seat = "DriverSeat",
	Drive = "Drive", -- LinearVelocity under Hull
	Steer = "Steer", -- Torque under Hull (yaw, hull-relative)
	MaxTorqueAttribute = "MaxTorque",
	BaseForceAttribute = "BaseForce", -- on Drive: full-traction MaxAxesForce (surfaces scale it) -- on Steer: torque cap for the client yaw controller
	TurretHinge = "TurretHinge", -- HingeConstraint under Hull (yaw)
	BarrelHinge = "BarrelHinge", -- HingeConstraint under Turret (pitch, positive = up)
	Muzzle = "Muzzle", -- Attachment under Barrel; LookVector = firing direction
	-- Attributes on the tank model, written by the server for clients to display.
	HealthAttribute = "Health",
	MaxHealthAttribute = "MaxHealth",
	ProtectedUntilAttribute = "ProtectedUntil", -- workspace:GetServerTimeNow() timestamp
	-- Workspace folders.
	TanksFolder = "Tanks",
	WrecksFolder = "Wrecks",
}
