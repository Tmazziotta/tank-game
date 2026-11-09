--!strict
-- Server bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotService = require(script.BotService)
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local Combatant = require(script.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local DebrisService = require(script.DebrisService)
local Destruction = require(script.Destruction)
local DevCommands = require(script.DevCommands)
local Garage = require(script.Garage)
local MapService = require(script.MapService)
local PlayerData = require(script.PlayerData)
local PropCrusher = require(script.PropCrusher)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(script.Rewards)
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
	PropCrusher.blast(position, radius)
end

MapService.RoundReset()
ScoreService.start()
PlayerData.start()
Rewards.start()
Garage.start()
TankService.start()
PropCrusher.start()
DevCommands.start()

WeaponService.start(function(position: Vector3, radius: number, _shooter: Combatant.Combatant)
	blast(position, radius)
end)

TankService.onDestroyed(function(victim: Combatant.Combatant, killer: Combatant.Combatant?, position: Vector3?)
	ScoreService.recordDeath(victim, killer)
	Rewards.onDestroyed(victim.player, if killer then killer.player else nil)
	if position then
		blast(position, Config.Combat.WreckBlastRadius)
	end
	local report: CombatTypes.DestroyedReport = {
		victimName = victim.name,
		victim = victim.player,
		killerName = if killer then killer.name else nil,
		killer = if killer then killer.player else nil,
		position = position,
	}
	Remotes.TankDestroyed:FireAllClients(report)
end)

BotService.start()
RoundService.start()
