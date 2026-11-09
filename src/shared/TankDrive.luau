--!strict
-- Low-level tank control shared by the player's client controller and server-side bots:
-- hull drive + yaw-rate control, and turret/barrel aiming through the hinge motors.
-- Whoever simulates a tank's physics calls these every frame.

local Config = require(script.Parent.Config)
local TankSchema = require(script.Parent.TankSchema)

export type Refs = {
	model: Model,
	hull: BasePart,
	turret: BasePart,
	drive: LinearVelocity,
	steer: Torque,
	hinge: HingeConstraint,
	barrelHinge: HingeConstraint,
	muzzle: Attachment,
}

local TankDrive = {}

-- Looks up a tank model's control instances; nil if anything is missing.
function TankDrive.resolve(model: Model): Refs?
	local hull = model:FindFirstChild(TankSchema.Hull)
	local turret = model:FindFirstChild(TankSchema.Turret)
	local barrel = model:FindFirstChild(TankSchema.Barrel)
	if not (hull and hull:IsA("BasePart") and turret and turret:IsA("BasePart") and barrel) then
		return nil
	end
	local drive = hull:FindFirstChild(TankSchema.Drive)
	local steer = hull:FindFirstChild(TankSchema.Steer)
	local hinge = hull:FindFirstChild(TankSchema.TurretHinge)
	local barrelHinge = turret:FindFirstChild(TankSchema.BarrelHinge)
	local muzzle = barrel:FindFirstChild(TankSchema.Muzzle)
	if
		not (
			drive
			and drive:IsA("LinearVelocity")
			and steer
			and steer:IsA("Torque")
			and hinge
			and hinge:IsA("HingeConstraint")
			and barrelHinge
			and barrelHinge:IsA("HingeConstraint")
			and muzzle
			and muzzle:IsA("Attachment")
		)
	then
		return nil
	end
	return {
		model = model,
		hull = hull,
		turret = turret,
		drive = drive,
		steer = steer,
		hinge = hinge,
		barrelHinge = barrelHinge,
		muzzle = muzzle,
	}
end

function TankDrive.wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- Yaw (about hull up) of a world direction, measured from hull forward.
-- Positive = counter-clockwise from above (left), matching the hinge's positive direction.
function TankDrive.hullYaw(hullCFrame: CFrame, worldDir: Vector3): number
	local d = hullCFrame:VectorToObjectSpace(worldDir)
	return math.atan2(-d.X, -d.Z)
end

-- throttle: -1 (reverse) .. 1 (forward). turn: -1 (left) .. 1 (right).
function TankDrive.drive(tank: Refs, throttle: number, turn: number, dt: number)
	local cfg = Config.Tank
	local speed = if throttle >= 0 then cfg.MaxForwardSpeed else cfg.MaxReverseSpeed
	-- Attachment space: -Z is forward. Positive spin about up is counter-clockwise, so right = negative.
	tank.drive.VectorVelocity = Vector3.new(0, 0, -throttle * speed)

	-- Yaw-rate controller. Runs once per frame while physics substeps, so instead of a fixed
	-- gain (which overshoots and chatters) it asks for the torque that closes a fraction of
	-- the rate error within this frame, plus friction feed-forward while turning.
	local targetRate = -turn * cfg.TurnRate
	local yawRate = tank.hull.AssemblyAngularVelocity:Dot(tank.hull.CFrame.UpVector)
	local maxTorque = tank.steer:GetAttribute(TankSchema.MaxTorqueAttribute)
	local cap = if type(maxTorque) == "number" then maxTorque else 0
	local inertia = tank.hull.AssemblyMass * cfg.YawInertiaPerMass
	local torque = inertia * (targetRate - yawRate) * cfg.YawResponse / math.max(dt, 1 / 240)
	if targetRate ~= 0 then
		torque += math.sign(targetRate) * cap * cfg.YawFrictionCompensation
	end
	tank.steer.Torque = Vector3.new(0, math.clamp(torque, -cap, cap), 0)
end

local function aimTurret(tank: Refs, target: Vector3)
	local toTarget = target - tank.turret.Position
	if Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude < 2 then
		tank.hinge.AngularVelocity = 0
		return
	end
	local hullCFrame = tank.hull.CFrame
	local err = TankDrive.wrapAngle(
		TankDrive.hullYaw(hullCFrame, toTarget) - TankDrive.hullYaw(hullCFrame, tank.muzzle.WorldCFrame.LookVector)
	)
	local maxSpeed = Config.Tank.TurretTraverseSpeed
	tank.hinge.AngularVelocity = math.clamp(err * Config.Tank.TurretGain, -maxSpeed, maxSpeed)
end

-- Pitch is measured in the turret-side trunnion frame (forward -Z, up +Y), so it stays
-- correct when the hull is tilted.
local function aimBarrel(tank: Refs, target: Vector3)
	local pivot = (tank.barrelHinge.Attachment0 :: Attachment).WorldCFrame
	local toTarget = pivot:PointToObjectSpace(target)
	local horizontal = math.sqrt(toTarget.X ^ 2 + toTarget.Z ^ 2)
	if horizontal < 2 then
		tank.barrelHinge.AngularVelocity = 0
		return
	end
	local cfg = Config.Tank
	local desired = math.clamp(math.atan2(toTarget.Y, horizontal), cfg.BarrelMinElevation, cfg.BarrelMaxElevation)
	local look = pivot:VectorToObjectSpace(tank.muzzle.WorldCFrame.LookVector)
	local pitch = math.atan2(look.Y, math.sqrt(look.X ^ 2 + look.Z ^ 2))
	local maxSpeed = cfg.BarrelElevationSpeed
	tank.barrelHinge.AngularVelocity = math.clamp((desired - pitch) * cfg.BarrelGain, -maxSpeed, maxSpeed)
end

-- Swing the turret and barrel toward a world point at their capped speeds.
function TankDrive.aim(tank: Refs, target: Vector3)
	aimTurret(tank, target)
	aimBarrel(tank, target)
end

return TankDrive
