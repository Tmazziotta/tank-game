--!strict
-- Studio-only test hooks, reachable from the command bar / MCP via
-- ServerStorage.DevCommands:Invoke(name, ...). Never created in live servers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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
		return TankHealth.damage(model, amount, if attacker and attacker:IsA("Player") then attacker else nil)
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
