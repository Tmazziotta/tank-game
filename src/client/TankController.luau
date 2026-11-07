--!strict
-- Drives the local player's tank. The client owns the tank's physics, so setting the
-- constraint targets locally is what moves it. W/S throttle, A/D rotate the hull.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local TankSchema = require(ReplicatedStorage.Shared.TankSchema)
local TankCamera = require(script.Parent.TankCamera)

export type TankRefs = {
	model: Model,
	hull: BasePart,
	turret: BasePart,
	drive: LinearVelocity,
	steer: AngularVelocity,
	hinge: HingeConstraint,
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
	local muzzle = barrel:FindFirstChild(TankSchema.Muzzle)
	if
		not (
			drive
			and drive:IsA("LinearVelocity")
			and steer
			and steer:IsA("AngularVelocity")
			and hinge
			and hinge:IsA("HingeConstraint")
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
		muzzle = muzzle,
	}
end

local function step(_dt: number)
	local tank = current
	if not tank then
		return
	end
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
