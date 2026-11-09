--!strict
-- Studio-only test hooks, reachable from the command bar / MCP via
-- ServerStorage.DevCommands:Invoke(name, ...). Never created in live servers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BotService = require(script.Parent.BotService)
local Combatant = require(script.Parent.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local MapService = require(script.Parent.MapService)
local PlayerData = require(script.Parent.PlayerData)
local TankHealth = require(script.Parent.TankHealth)
local TankService = require(script.Parent.TankService)

local DevCommands = {}

local commands: { [string]: (...any) -> any } = {
	-- spawnDummy(cframe): an undriven tank to shoot at. Returns its model.
	spawnDummy = function(cframe: CFrame)
		return TankService.spawnDummy(cframe)
	end,
	-- damage(model, amount, attackerName?): hurt a tank as if shot.
	damage = function(model: Model, amount: number, attackerName: string?)
		local attacker = if attackerName then Players:FindFirstChild(attackerName) else nil
		local combatant = if attacker and attacker:IsA("Player") then Combatant.forPlayer(attacker) else nil
		return TankHealth.damage(model, amount, combatant)
	end,
	-- setBots(count): add or remove AI tanks.
	setBots = function(count: number)
		BotService.setCount(count)
		return BotService.count()
	end,
	-- grant(playerName, coins, xp): add currency/XP to a player's save. Returns their data.
	grant = function(playerName: string, coins: number, xp: number)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), `no player {playerName}`)
		PlayerData.update(player, function(data)
			data.Coins += coins
			data.XP += xp
		end)
		return PlayerData.get(player)
	end,
	-- resetData(playerName): wipe a player's saved progress to a fresh profile.
	resetData = function(playerName: string)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), `no player {playerName}`)
		PlayerData.reset(player)
		return PlayerData.get(player)
	end,
	-- loadMap(id): switch arena now ("Town", "Dockyard", "Orchard") and respawn everyone.
	loadMap = function(id: string)
		assert(MapService.load(id), `unknown map {id}`)
		TankService.clearWrecks()
		for _, player in Players:GetPlayers() do
			task.spawn(player.LoadCharacter, player)
		end
		BotService.respawnAll()
		return nil
	end,
	-- setRound(key, value): tweak a Config.Round value live, e.g. ("MinPlayers", 1).
	setRound = function(key: string, value: number)
		(Config.Round :: any)[key] = value
		return nil
	end,
}

function DevCommands.start()
	if not RunService:IsStudio() then
		return
	end
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "DevCommands"
	bindable.OnInvoke = function(name: string, ...: any): any
		local command = commands[name]
		assert(command, `unknown dev command {name}`)
		return command(...)
	end
	bindable.Parent = ServerStorage
end

return DevCommands
