--!strict
-- Server bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local Config = require(ReplicatedStorage.Shared.Config)
local DebrisService = require(script.DebrisService)
local Destruction = require(script.Destruction)
local DevCommands = require(script.DevCommands)
local MapService = require(script.MapService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundService = require(script.RoundService)
local ScoreService = require(script.ScoreService)
local TankService = require(script.TankService)
local WeaponService = require(script.WeaponService)

local function blast(position: Vector3, radius: number)
	local roots: { Instance } = { DebrisService.getFolder() }
	local buildings = MapService.getBuildingsFolder()
	if buildings then
		table.insert(roots, buildings)
	end
	Destruction.blast(position, radius, roots)
end

MapService.RoundReset()
ScoreService.start()
TankService.start()
DevCommands.start()

WeaponService.start(function(position: Vector3, _shooter: Player)
	blast(position, Config.Weapon.BlastRadius)
end)

TankService.onDestroyed(function(victim: Player?, victimName: string, killer: Player?, position: Vector3?)
	ScoreService.recordDeath(victim, killer)
	if position then
		blast(position, Config.Combat.WreckBlastRadius)
	end
	local report: CombatTypes.DestroyedReport = {
		victimName = victimName,
		victim = victim,
		killer = killer,
		position = position,
	}
	Remotes.TankDestroyed:FireAllClients(report)
end)

RoundService.start()
