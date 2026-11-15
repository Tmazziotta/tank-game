--!strict
-- Fire input and reload state. Clicking only *requests* a shot; the reload timer starts
-- when the server confirms the launch via ShellFired, so the HUD reflects what really
-- happened. Hit feedback arrives with ShotFired when the shell lands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Ballistics = require(ReplicatedStorage.Shared.Ballistics)
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local DartClip = require(ReplicatedStorage.Shared.DartClip)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
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
local mouseHeld = false

-- Foam Force tanks fire from a clip: darts left, or nil for every other tank.
local function clip(): (number?, number)
	local tank = TankController.getTank()
	if not tank or TankCatalog.lineOfModel(tank.model) ~= "Foam" then
		return nil, 1
	end
	return DartClip.read(tank.model, tank.spec, workspace:GetServerTimeNow())
end

local function reloadProgress(): number
	local ammo, clipProgress = clip()
	if ammo then
		return if ammo > 0 then 1 else clipProgress
	end
	local tank = TankController.getTank()
	local cooldown = if tank then tank.spec.Cooldown else 1
	return math.clamp((os.clock() - lastConfirmed) / cooldown, 0, 1)
end

local function tryFire()
	if not TankController.getTank() or MouseLock.isReleased() then
		return
	end
	local now = os.clock()
	local ammo = clip()
	-- Darts: wait out the gap between darts (and one request per gap while unconfirmed).
	local wait = if ammo then DartClip.interval() else REQUEST_TIMEOUT
	if reloadProgress() < 1 or now - lastRequested < wait or (ammo ~= nil and now - lastConfirmed < wait) then
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
	-- Where a shell fired now would land, following its drop.
	local velocity = Ballistics.launchVelocity(muzzle.LookVector)
	local result = Ballistics.trace(muzzle.Position, velocity, params)
	local point = if result then result.Position else Ballistics.positionAt(muzzle.Position, velocity, Ballistics.maxFlightTime())
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

-- 0..1 reload progress of the local tank's gun (1 = ready).
function WeaponClient.reloadProgress(): number
	return reloadProgress()
end

-- Fire if possible (used by the touch FIRE button; held = keeps trying as reload completes).
function WeaponClient.fire()
	tryFire()
end

function WeaponClient.start()
	Hud.mount()
	ShotEffects.mount()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseHeld = true
			tryFire()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseHeld = false
		end
	end)

	Remotes.ShellFired.OnClientEvent:Connect(function(shooter: Player?, launch: CombatTypes.ShellLaunch)
		ShotEffects.launch(launch)
		if shooter == localPlayer then
			lastConfirmed = os.clock()
		end
	end)

	Remotes.ShotFired.OnClientEvent:Connect(function(shooter: Player?, report: CombatTypes.ShotReport)
		ShotEffects.land(report)
		if shooter == localPlayer then
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
			-- Holding the mouse keeps firing as the gun reloads (as the touch FIRE button does).
			if mouseHeld then
				tryFire()
			end
			local ammo = clip()
			Hud.setAmmo(ammo, DartClip.size())
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
