--!strict
-- Drives the local player's tank. The client owns the tank's physics, so setting the
-- constraint targets locally is what moves it. W/S throttle, A/D rotate the hull, and the
-- turret (yaw) and barrel (pitch) hinge motors steer toward the mouse at capped speeds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local TankDrive = require(ReplicatedStorage.Shared.TankDrive)
local TankSchema = require(ReplicatedStorage.Shared.TankSchema)
local AimTarget = require(script.Parent.AimTarget)
local TankCamera = require(script.Parent.TankCamera)

export type TankRefs = TankDrive.Refs

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

local function aim(tank: TankRefs)
	local ignore: { Instance } = { tank.model }
	local character = localPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	TankDrive.aim(tank, AimTarget.getPoint(ignore, tank.muzzle.WorldPosition.Y))
end

local function step(dt: number)
	local tank = current
	if not tank then
		return
	end
	aim(tank)
	TankDrive.drive(tank, axis(Enum.KeyCode.W, Enum.KeyCode.S), axis(Enum.KeyCode.D, Enum.KeyCode.A), dt)
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
	local refs = TankDrive.resolve(model)
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
