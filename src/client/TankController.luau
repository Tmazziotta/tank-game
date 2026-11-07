--!strict
-- Drives the local player's tank. The client owns the tank's physics, so setting the
-- constraint targets locally is what moves it. W/S throttle, A/D rotate the hull, and the
-- turret (yaw) and barrel (pitch) hinge motors steer toward the mouse at capped speeds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local TankSchema = require(ReplicatedStorage.Shared.TankSchema)
local AimTarget = require(script.Parent.AimTarget)
local TankCamera = require(script.Parent.TankCamera)

export type TankRefs = {
	model: Model,
	hull: BasePart,
	turret: BasePart,
	drive: LinearVelocity,
	steer: AngularVelocity,
	hinge: HingeConstraint,
	barrelHinge: HingeConstraint,
	muzzle: Attachment,
}

local TankController = {}

local localPlayer = Players.LocalPlayer
local BIND_NAME = "TankDrive"
local current: TankRefs? = nil

local function axis(positive: Enum.KeyCode, negative: Enum.KeyCode): number
	local value = 0
	if UserInputService:IsKeyDown(positive) then
		value += 1
	end
	if UserInputService:IsKeyDown(negative) then
		value -= 1
	end
	return value
end

local function resolve(model: Model): TankRefs?
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
			and steer:IsA("AngularVelocity")
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

local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- Yaw (about hull up) of a world direction, measured from hull forward.
-- Positive = counter-clockwise from above, matching the hinge's positive direction.
local function hullYaw(hullCFrame: CFrame, worldDir: Vector3): number
	local d = hullCFrame:VectorToObjectSpace(worldDir)
	return math.atan2(-d.X, -d.Z)
end

local function aimTurret(tank: TankRefs, target: Vector3)
	local toTarget = target - tank.turret.Position
	if Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude < 2 then
		tank.hinge.AngularVelocity = 0
		return
	end
	local hullCFrame = tank.hull.CFrame
	local err = wrapAngle(hullYaw(hullCFrame, toTarget) - hullYaw(hullCFrame, tank.muzzle.WorldCFrame.LookVector))
	local maxSpeed = Config.Tank.TurretTraverseSpeed
	tank.hinge.AngularVelocity = math.clamp(err * Config.Tank.TurretGain, -maxSpeed, maxSpeed)
end

-- Pitch is measured in the turret-side trunnion frame (forward -Z, up +Y), so it stays
-- correct when the hull is tilted.
local function aimBarrel(tank: TankRefs, target: Vector3)
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

local function aim(tank: TankRefs)
	local ignore: { Instance } = { tank.model }
	local character = localPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	local target = AimTarget.getPoint(ignore, tank.muzzle.WorldPosition.Y)
	aimTurret(tank, target)
	aimBarrel(tank, target)
end

local function step(_dt: number)
	local tank = current
	if not tank then
		return
	end
	aim(tank)
	local throttle = axis(Enum.KeyCode.W, Enum.KeyCode.S)
	local turn = axis(Enum.KeyCode.D, Enum.KeyCode.A)
	local speed = if throttle >= 0 then Config.Tank.MaxForwardSpeed else Config.Tank.MaxReverseSpeed
	-- Attachment space: -Z is forward. Positive world Y spin is counter-clockwise, so D = negative.
	tank.drive.VectorVelocity = Vector3.new(0, 0, -throttle * speed)
	tank.steer.AngularVelocity = Vector3.new(0, -turn * Config.Tank.TurnRate, 0)
end

local function unbind()
	if current then
		RunService:UnbindFromRenderStep(BIND_NAME)
		current = nil
	end
	TankCamera.unbind()
end

local function bind(model: Model)
	unbind()
	local refs = resolve(model)
	if not refs then
		warn("[TankController] tank model is missing parts")
		return
	end
	current = refs
	TankCamera.bind(refs.hull)
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Input.Value + 1, step)
end

local function isMyTank(model: Instance?): boolean
	return model ~= nil and model:IsA("Model") and model:GetAttribute(TankSchema.OwnerAttribute) == localPlayer.UserId
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- Belt and braces with the server's JumpPower = 0: jumping would unseat the driver.
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	humanoid.Seated:Connect(function(active: boolean, seatPart: BasePart?)
		local model = if seatPart then seatPart.Parent else nil
		if active and isMyTank(model) then
			bind(model :: Model)
		else
			unbind()
		end
	end)
	local seatPart = humanoid.SeatPart
	if seatPart and isMyTank(seatPart.Parent) then
		bind(seatPart.Parent :: Model)
	end
	humanoid.Died:Connect(unbind)
end

-- The current tank (if any), for other client modules such as weapons and HUD.
function TankController.getTank(): TankRefs?
	return current
end

function TankController.start()
	-- Default character controls would fight our WASD handling. Some places don't ship
	-- the default PlayerModule at all, in which case there is nothing to disable.
	local playerModule = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 3)
	if playerModule and playerModule:IsA("ModuleScript") then
		(require(playerModule) :: any):GetControls():Disable()
	end

	localPlayer.CharacterAdded:Connect(onCharacter)
	if localPlayer.Character then
		task.spawn(onCharacter, localPlayer.Character)
	end
end

return TankController
