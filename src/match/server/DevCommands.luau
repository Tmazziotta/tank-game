--!strict
-- Studio-only test hooks, reachable from the command bar / MCP via
-- ServerStorage.DevCommands:Invoke(name, ...). Never created in live servers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Combatant = require(script.Parent.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local Location = require(ReplicatedStorage.Shared.Location)
local MapService = require(script.Parent.MapService)
local PlayerData = require(ServerScriptService.Core.PlayerData)
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
	-- loadMap(id): switch arena now ("Town", "Dockyard", "Orchard"). Tanks stay where they
	-- are until the next round spawns everyone on the new map.
	loadMap = function(id: string)
		assert(MapService.load(id), `unknown map {id}`)
		-- Takes effect for the next round (the round reset rebuilds the current map).
		return nil
	end,
	-- setLocation(playerName, "Garage" | "Match"): move a player in dev mode, as PLAY does.
	setLocation = function(playerName: string, place: string)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), `no player {playerName}`)
		assert(place == "Garage" or place == "Match", `bad place {place}`)
		Location.set(player, place)
		return nil
	end,
	-- testRelease(playerName): what a failed teleport does to a save: release the session
	-- (as before a teleport), then reacquire it. Returns (releasedCleanly, coinsAfter).
	testRelease = function(playerName: string)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), `no player {playerName}`)
		PlayerData.release(player)
		local released = PlayerData.get(player) == nil
		PlayerData.reacquire(player)
		local data = PlayerData.get(player)
		return released, if data then data.Coins else nil
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
