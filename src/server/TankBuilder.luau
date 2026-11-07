--!strict
-- Builds a toy-style tank from primitive parts. Forward is the model's -Z (LookVector).
-- Hull assembly: hull + treads + fenders + seat (welded). Turret assembly: turret + dome,
-- joined to the hull by a motorised yaw hinge. Barrel assembly: barrel + muzzle brake,
-- joined to the turret by a motorised, angle-limited pitch hinge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TankSchema = require(ReplicatedStorage.Shared.TankSchema)

export type Tank = {
	model: Model,
	hull: Part,
	turret: Part,
	barrel: Part,
	seat: Seat,
	drive: LinearVelocity,
	steer: AngularVelocity,
	hinge: HingeConstraint,
	barrelHinge: HingeConstraint,
	muzzle: Attachment,
}

local TankBuilder = {}

local DARK = Color3.fromRGB(58, 62, 80)
local WHEEL = Color3.fromRGB(255, 150, 60)
local LIGHT = Color3.fromRGB(255, 240, 150)

local function contactPhysics(): PhysicalProperties
	-- High weights make the tank's low friction dominate over the ground's.
	return PhysicalProperties.new(0.7, Config.Tank.GroundFriction, 0, 100, 100)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function makePart(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function decor(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
end

-- Cylinders extend along their local X axis; these rotations aim that axis.
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- X axis -> forward (-Z)
local ALONG_Y = CFrame.Angles(0, 0, math.rad(90)) -- X axis -> up

function TankBuilder.build(origin: CFrame, bodyColor: Color3): Tank
	local model = Instance.new("Model")
	model.Name = "Tank"

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- Hull assembly ---------------------------------------------------------
	local hull = makePart(model, TankSchema.Hull, Enum.PartType.Block, Vector3.new(6.2, 2, 10), at(0, 2.2, 0), bodyColor:Lerp(DARK, 0.25))
	hull.CustomPhysicalProperties = contactPhysics()

	local fender = makePart(model, "Fender", Enum.PartType.Block, Vector3.new(9.8, 0.6, 11.6), at(0, 3.4, 0), bodyColor)
	fender.CustomPhysicalProperties = contactPhysics()
	weld(hull, fender)

	for _, side in { -1, 1 } do
		local x = 3.4 * side
		local pod = makePart(model, "Tread", Enum.PartType.Cylinder, Vector3.new(10, 3, 3), at(x, 1.6, 0) * ALONG_Z, DARK)
		pod.CustomPhysicalProperties = contactPhysics()
		weld(hull, pod)
		for _, z in { -5, 5 } do
			local cap = makePart(model, "TreadCap", Enum.PartType.Ball, Vector3.new(3, 3, 3), at(x, 1.6, z), DARK)
			cap.CustomPhysicalProperties = contactPhysics()
			weld(hull, cap)
		end
		for _, z in { -3.3, 0, 3.3 } do
			local wheel = makePart(model, "Wheel", Enum.PartType.Cylinder, Vector3.new(0.4, 2.2, 2.2), at(5.0 * side, 1.6, z), WHEEL)
			decor(wheel)
			weld(hull, wheel)
		end
		local lamp = makePart(model, "Headlight", Enum.PartType.Ball, Vector3.new(1, 1, 1), at(2.3 * side, 2.6, -5.0), LIGHT)
		lamp.Material = Enum.Material.Neon
		decor(lamp)
		weld(hull, lamp)
	end

	local seat = Instance.new("Seat")
	seat.Name = TankSchema.Seat
	seat.Size = Vector3.new(2.2, 0.5, 2.2)
	seat.CFrame = at(0, 3.95, 3.6)
	seat.Color = DARK
	seat.Material = Enum.Material.SmoothPlastic
	seat.TopSurface = Enum.SurfaceType.Smooth
	decor(seat)
	seat.Parent = model
	weld(hull, seat)

	-- Turret assembly ------------------------------------------------------
	local turretColor = lighten(bodyColor, 0.12)
	local turret = makePart(model, TankSchema.Turret, Enum.PartType.Cylinder, Vector3.new(1.5, 5.8, 5.8), at(0, 4.55, -0.6) * ALONG_Y, turretColor)
	turret.CanCollide = false

	local dome = makePart(model, "Dome", Enum.PartType.Ball, Vector3.new(4.2, 4.2, 4.2), at(0, 5.2, -0.6), lighten(bodyColor, 0.3))
	decor(dome)
	weld(turret, dome)

	-- Barrel assembly: pitches on its own hinge at the front of the turret.
	local barrel = makePart(model, TankSchema.Barrel, Enum.PartType.Cylinder, Vector3.new(7, 1, 1), at(0, 5.0, -6.1) * ALONG_Z, DARK)
	barrel.CanCollide = false
	barrel.CanTouch = false

	local brake = makePart(model, "MuzzleBrake", Enum.PartType.Cylinder, Vector3.new(1.2, 1.5, 1.5), at(0, 5.0, -9.2) * ALONG_Z, WHEEL)
	decor(brake)
	weld(barrel, brake)

	local muzzle = Instance.new("Attachment")
	muzzle.Name = TankSchema.Muzzle
	muzzle.Parent = barrel
	muzzle.WorldCFrame = at(0, 5.0, -9.8)

	-- Barrel hinge (axis = attachment X = tank right; positive angle = nose up) ---
	local trunnionCFrame = at(0, 5.0, -2.6)
	local trunnion0 = Instance.new("Attachment")
	trunnion0.Name = "Trunnion"
	trunnion0.Parent = turret
	trunnion0.WorldCFrame = trunnionCFrame
	local trunnion1 = Instance.new("Attachment")
	trunnion1.Name = "Trunnion"
	trunnion1.Parent = barrel
	trunnion1.WorldCFrame = trunnionCFrame

	local barrelHinge = Instance.new("HingeConstraint")
	barrelHinge.Name = TankSchema.BarrelHinge
	barrelHinge.Attachment0 = trunnion0
	barrelHinge.Attachment1 = trunnion1
	barrelHinge.ActuatorType = Enum.ActuatorType.Motor
	barrelHinge.MotorMaxTorque = Config.Tank.BarrelMaxTorque
	barrelHinge.AngularVelocity = 0
	barrelHinge.LimitsEnabled = true
	barrelHinge.LowerAngle = math.deg(Config.Tank.BarrelMinElevation)
	barrelHinge.UpperAngle = math.deg(Config.Tank.BarrelMaxElevation)
	barrelHinge.Parent = turret

	-- Turret hinge (axis = attachment X = up) --------------------------------
	local ringCFrame = at(0, 3.8, -0.6) * ALONG_Y
	local ring0 = Instance.new("Attachment")
	ring0.Name = "TurretRing"
	ring0.Parent = hull
	ring0.WorldCFrame = ringCFrame
	local ring1 = Instance.new("Attachment")
	ring1.Name = "TurretRing"
	ring1.Parent = turret
	ring1.WorldCFrame = ringCFrame

	local hinge = Instance.new("HingeConstraint")
	hinge.Name = TankSchema.TurretHinge
	hinge.Attachment0 = ring0
	hinge.Attachment1 = ring1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.MotorMaxTorque = Config.Tank.TurretMaxTorque
	hinge.AngularVelocity = 0
	hinge.Parent = hull

	-- Drive constraints ------------------------------------------------------
	local driveAttachment = Instance.new("Attachment")
	driveAttachment.Name = "DriveAttachment"
	driveAttachment.Parent = hull

	local drive = Instance.new("LinearVelocity")
	drive.Name = TankSchema.Drive
	drive.Attachment0 = driveAttachment
	drive.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	drive.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	-- Y force stays 0 so gravity alone holds the tank down.
	drive.MaxAxesForce = Vector3.zero
	drive.VectorVelocity = Vector3.zero
	drive.Parent = hull

	local steer = Instance.new("AngularVelocity")
	steer.Name = TankSchema.Steer
	steer.Attachment0 = driveAttachment
	-- World-relative: also holds pitch/roll at zero, which keeps the toy tank upright.
	steer.RelativeTo = Enum.ActuatorRelativeTo.World
	steer.AngularVelocity = Vector3.zero
	steer.MaxTorque = 0
	steer.Parent = hull

	model.PrimaryPart = hull

	local tank: Tank = {
		model = model,
		hull = hull,
		turret = turret,
		barrel = barrel,
		seat = seat,
		drive = drive,
		steer = steer,
		hinge = hinge,
		barrelHinge = barrelHinge,
		muzzle = muzzle,
	}
	TankBuilder.sizeForces(tank)
	return tank
end

-- Size drive force/torque from the current mass (call again after a driver sits).
function TankBuilder.sizeForces(tank: Tank)
	local mass = tank.hull.AssemblyMass + tank.turret.AssemblyMass + tank.barrel.AssemblyMass
	local frictionAccel = workspace.Gravity * Config.Tank.GroundFriction
	tank.drive.MaxAxesForce = Vector3.new(
		mass * (Config.Tank.LateralGrip + frictionAccel),
		0,
		mass * (Config.Tank.DriveAcceleration + frictionAccel)
	)
	tank.steer.MaxTorque = mass * Config.Tank.TurnTorquePerMass
end

return TankBuilder
