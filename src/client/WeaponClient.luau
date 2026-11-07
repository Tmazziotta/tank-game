--!strict
-- Fire input and reload state. Clicking only *requests* a shot; the reload timer starts
-- when the server confirms it via ShotFired, so the HUD reflects what really happened.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)
local ShotEffects = require(script.Parent.ShotEffects)
local TankController = require(script.Parent.TankController)

local WeaponClient = {}

local localPlayer = Players.LocalPlayer
local REQUEST_TIMEOUT = 0.5 -- don't spam requests while waiting for confirmation

local lastConfirmed = -math.huge
local lastRequested = -math.huge

local function reloadProgress(): number
	return math.clamp((os.clock() - lastConfirmed) / Config.Weapon.Cooldown, 0, 1)
end

local function tryFire()
	if not TankController.getTank() then
		return
	end
	local now = os.clock()
	if reloadProgress() < 1 or now - lastRequested < REQUEST_TIMEOUT then
		return
	end
	lastRequested = now
	Remotes.FireRequest:FireServer()
end

local function barrelScreenPoint(): Vector2?
	local tank = TankController.getTank()
	if not tank then
		return nil
	end
	local muzzle = tank.muzzle.WorldCFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { tank.model }
	if localPlayer.Character then
		table.insert(ignore, localPlayer.Character :: Model)
	end
	params.FilterDescendantsInstances = ignore
	local direction = muzzle.LookVector * Config.Weapon.Range
	local result = workspace:Raycast(muzzle.Position, direction, params)
	local point = if result then result.Position else muzzle.Position + direction
	local screen, onScreen = workspace.CurrentCamera:WorldToViewportPoint(point)
	return if onScreen then Vector2.new(screen.X, screen.Y) else nil
end

function WeaponClient.start()
	Hud.mount()
	ShotEffects.mount()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			tryFire()
		end
	end)

	Remotes.ShotFired.OnClientEvent:Connect(function(shooter: Player, origin: Vector3, hitPosition: Vector3, didHit: boolean)
		ShotEffects.play(origin, hitPosition, didHit)
		if shooter == localPlayer then
			lastConfirmed = os.clock()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local inTank = TankController.getTank() ~= nil
		Hud.setVisible(inTank)
		if inTank then
			Hud.setReload(reloadProgress())
			Hud.update(barrelScreenPoint())
		end
	end)
end

return WeaponClient
