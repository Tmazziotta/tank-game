--!strict
-- Fire input and reload state. Clicking only *requests* a shot; the reload timer starts
-- when the server confirms it via ShotFired, so the HUD reflects what really happened.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankSchema = require(ReplicatedStorage.Shared.TankSchema)
local Hud = require(script.Parent.Hud)
local MouseLock = require(script.Parent.MouseLock)
local ShotEffects = require(script.Parent.ShotEffects)
local TankController = require(script.Parent.TankController)

local WeaponClient = {}

local localPlayer = Players.LocalPlayer
local REQUEST_TIMEOUT = 0.5 -- don't spam requests while waiting for confirmation
local HIT_COLOR = Color3.fromRGB(255, 220, 90)
local RICOCHET_COLOR = Color3.fromRGB(200, 220, 255)
local SHIELD_COLOR = Color3.fromRGB(120, 200, 255)

local lastConfirmed = -math.huge
local lastRequested = -math.huge

local function reloadProgress(): number
	local tank = TankController.getTank()
	local cooldown = if tank then tank.spec.Cooldown else 1
	return math.clamp((os.clock() - lastConfirmed) / cooldown, 0, 1)
end

local function tryFire()
	if not TankController.getTank() or MouseLock.isReleased() then
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

-- Feedback for the shooter on what their shell did to a tank.
local function showShotResult(report: CombatTypes.ShotReport)
	local zone = string.upper(report.zone or "")
	if report.kind == "Hit" then
		Hud.showHitMarker(`-{report.damage or 0} {zone}`, HIT_COLOR)
	elseif report.kind == "Ricochet" then
		Hud.showHitMarker("RICOCHET", RICOCHET_COLOR)
	elseif report.kind == "Shielded" then
		Hud.showHitMarker("SPAWN SHIELD", SHIELD_COLOR)
	end
end

local function updateHealth(model: Model)
	local health = model:GetAttribute(TankSchema.HealthAttribute)
	local maxHealth = model:GetAttribute(TankSchema.MaxHealthAttribute)
	if type(health) == "number" and type(maxHealth) == "number" then
		Hud.setHealth(health, maxHealth)
	end
end

function WeaponClient.start()
	Hud.mount()
	ShotEffects.mount()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			tryFire()
		end
	end)

	Remotes.ShotFired.OnClientEvent:Connect(function(shooter: Player, report: CombatTypes.ShotReport)
		ShotEffects.play(report)
		if shooter == localPlayer then
			lastConfirmed = os.clock()
			showShotResult(report)
		elseif report.victim == localPlayer and report.kind == "Hit" then
			local tank = TankController.getTank()
			local maxHealth = if tank then tank.model:GetAttribute(TankSchema.MaxHealthAttribute) else nil
			Hud.flashDamage((report.damage or 0) / (if type(maxHealth) == "number" then maxHealth else 100))
		end
	end)

	Remotes.TankDestroyed.OnClientEvent:Connect(function(report: CombatTypes.DestroyedReport)
		if report.position then
			ShotEffects.tankExplosion(report.position)
		end
	end)

	RunService.RenderStepped:Connect(function()
		-- The tank HUD steps aside while a menu (class picker) has the mouse.
		local inTank = TankController.getTank() ~= nil and not MouseLock.isReleased()
		Hud.setVisible(inTank)
		if inTank then
			Hud.setReload(reloadProgress())
			Hud.update(barrelScreenPoint())
			local tank = TankController.getTank()
			if tank then
				updateHealth(tank.model)
			end
		end
	end)
end

return WeaponClient
