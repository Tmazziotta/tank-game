--!strict
-- AI tank lifecycle: keeps the configured number of bots in the arena, respawns them after
-- they are destroyed (same delay as players), and steps their brains every frame. In Studio
-- it defaults to Config.Bots.StudioCount so solo playtests have an opponent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BotBrain = require(script.Parent.BotBrain)
local Combatant = require(script.Parent.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local TankBuilder = require(script.Parent.TankBuilder)
local TankService = require(script.Parent.TankService)

type Bot = {
	combatant: Combatant.Combatant,
	tank: TankBuilder.Tank?,
	brain: BotBrain.Brain?,
	active: boolean, -- false once removed by setCount
}

local BotService = {}

local bots: { Bot } = {}

local function spawnBot(bot: Bot)
	if not bot.active or bot.tank then
		return
	end
	local tank = TankService.spawnBot(bot.combatant, Config.Bots.Color)
	bot.tank = tank
	bot.brain = BotBrain.new(tank, bot.combatant)
end

local function clearTank(bot: Bot)
	local tank = bot.tank
	bot.tank = nil
	bot.brain = nil
	if tank then
		TankService.remove(tank.model)
	end
end

local function scheduleRespawn(bot: Bot)
	task.delay(Config.Respawn.Delay, spawnBot, bot)
end

local function findBot(combatant: Combatant.Combatant): Bot?
	for _, bot in bots do
		if bot.combatant == combatant then
			return bot
		end
	end
	return nil
end

local function step(dt: number)
	for _, bot in bots do
		local brain = bot.brain
		local tank = bot.tank
		if brain and tank then
			if tank.hull:IsDescendantOf(workspace) then
				BotBrain.step(brain, dt)
			else
				-- Fell out of the world: no wreck, just come back.
				clearTank(bot)
				scheduleRespawn(bot)
			end
		end
	end
end

function BotService.count(): number
	return #bots
end

-- Add or remove bots until there are `count`.
function BotService.setCount(count: number)
	while #bots < count do
		local bot: Bot = {
			combatant = Combatant.bot(`Bot {#bots + 1}`),
			tank = nil,
			brain = nil,
			active = true,
		}
		table.insert(bots, bot)
		spawnBot(bot)
	end
	while #bots > count do
		local bot = table.remove(bots) :: Bot
		bot.active = false
		clearTank(bot)
	end
end

-- Fresh tanks for every bot (round start).
function BotService.respawnAll()
	for _, bot in bots do
		clearTank(bot)
		spawnBot(bot)
	end
end

function BotService.start()
	TankService.onDestroyed(function(victim: Combatant.Combatant)
		local bot = findBot(victim)
		if bot then
			-- The wreck belongs to TankService now; forget it and come back later.
			bot.tank = nil
			bot.brain = nil
			scheduleRespawn(bot)
		end
	end)
	RunService.Heartbeat:Connect(step)
	BotService.setCount(if RunService:IsStudio() then Config.Bots.StudioCount else Config.Bots.Count)
end

return BotService
