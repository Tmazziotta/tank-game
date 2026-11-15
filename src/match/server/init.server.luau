--!strict
-- Match server bootstrap: the arena, rounds, tanks and bots. Runs on the Match place, and
-- alongside the Garage in dev mode (see Places).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Places = require(ReplicatedStorage.Shared.Places)
if not Places.runsMatch() then
	return
end

local BotService = require(script.BotService)
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local Combatant = require(script.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local DebrisService = require(script.DebrisService)
local Destruction = require(script.Destruction)
local DevCommands = require(script.DevCommands)
local Garage = require(script.Garage)
local MapService = require(script.MapService)
local MineService = require(script.MineService)
local PlayerData = require(ServerScriptService.Core.PlayerData)
local PropCrusher = require(script.PropCrusher)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(script.Rewards)
local MatchRoster = require(script.MatchRoster)
local MatchService = require(script.MatchService)
local ScoreService = require(script.ScoreService)
local TeamService = require(script.TeamService)
local TankService = require(script.TankService)
local WaterService = require(script.WaterService)
local WeaponService = require(script.WeaponService)

-- Breaks walls and props (not mines: MineService chains those itself).
local function breakThings(position: Vector3, radius: number)
	local roots: { Instance } = { DebrisService.getFolder() }
	local buildings = MapService.getBuildingsFolder()
	if buildings then
		table.insert(roots, buildings)
	end
	Destruction.blast(position, radius, roots)
	PropCrusher.blast(position, radius)
end

-- Any explosion: breaks things and sets off mines it reaches (credited to `cause`).
local function blast(position: Vector3, radius: number, cause: Combatant.Combatant?)
	breakThings(position, radius)
	MineService.blast(position, radius, cause)
end

MapService.RoundReset()
ScoreService.start()
PlayerData.start()
Rewards.start()
Garage.start()
TeamService.start()
TankService.start()
PropCrusher.start()
DevCommands.start()

WeaponService.start(function(position: Vector3, radius: number, shooter: Combatant.Combatant)
	blast(position, radius, shooter)
end)
MineService.start(breakThings)
WaterService.start()

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
		victimTeam = victim.team,
		killerTeam = if killer then killer.team else nil,
		position = position,
	}
	Remotes.TankDestroyed:FireAllClients(report)
end)

BotService.start()
MatchRoster.start() -- after TeamService/TankService registered their roster callbacks
MatchService.start()
