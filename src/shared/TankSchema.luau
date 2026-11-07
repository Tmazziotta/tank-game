--!strict
-- Instance names shared by the server-side tank builder and the client controller.

return {
	OwnerAttribute = "OwnerUserId",
	Hull = "Hull",
	Turret = "Turret",
	Barrel = "Barrel",
	Seat = "DriverSeat",
	Drive = "Drive", -- LinearVelocity under Hull
	Steer = "Steer", -- AngularVelocity under Hull
	TurretHinge = "TurretHinge", -- HingeConstraint under Hull
	Muzzle = "Muzzle", -- Attachment under Barrel; LookVector = firing direction
}
