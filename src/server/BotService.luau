--!strict
-- AI tanks that fill empty team slots. At the start of every round, `fillTeams` gives each
-- team enough bots to reach Config.Round.TeamSize, all on fresh tanks. Like players, a
-- destroyed bot stays out until the next round. Brains step every frame, except while the
-- round is frozen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BotBrain = require(script.Parent.BotBrain)
local Combatant = require(script.Parent.Combatant)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankBuilder = require(script.Parent.TankBuilder)
local TankDrive = require(ReplicatedStorage.Shared.TankDrive)
local TankService = require(script.Parent.TankService)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local TeamService = require(script.Parent.TeamService)

type Bot = {
	combatant: Combatant.Combatant,
	tank: TankBuilder.Tank?,
	brain: BotBrain.Brain?,
}

local BotService = {}

local bots: { Bot } = {}
local rng = Random.new()
local frozen = false

local function clearTank(bot: Bot)
	local tank = bot.tank
	bot.tank = nil
	bot.brain = nil
	if tank then
		TankService.remove(tank.model)
	end
end

local function spawnBot(bot: Bot)
	-- A random tank each round, so solo testing meets every class and tier.
	local tankId = TankCatalog.order[rng:NextInteger(1, #TankCatalog.order)]
	local tank = TankService.spawnBot(bot.combatant, tankId)
	bot.tank = tank
	bot.brain = BotBrain.new(tank, bot.combatant)
end

local function step(dt: number)
	for _, bot in bots do
		local brain = bot.brain
		local tank = bot.tank
		if brain and tank then
			if not tank.hull:IsDescendantOf(workspace) then
				clearTank(bot) -- fell out of the world: out for the round
			elseif frozen then
				TankDrive.aim(brain.refs, tank.hull.Position + tank.hull.CFrame.LookVector * 50)
			else
				BotBrain.step(brain, dt)
			end
		end
	end
end

-- Remove every bot and its tank.
function BotService.clear()
	for _, bot in bots do
		clearTank(bot)
	end
	table.clear(bots)
end

-- New round: replace all bots with exactly enough per team to fill the open slots.
function BotService.fillTeams()
	BotService.clear()
	for _, team in TeamInfo.order do
		for _ = 1, TeamService.openSlots(team) do
			local bot: Bot = {
				combatant = Combatant.bot(`Bot {#bots + 1}`, team),
				tank = nil,
				brain = nil,
			}
			table.insert(bots, bot)
			spawnBot(bot)
		end
	end
end

function BotService.count(): number
	return #bots
end

function BotService.setFrozen(on: boolean)
	frozen = on
end

function BotService.start()
	TankService.onDestroyed(function(victim: Combatant.Combatant)
		for _, bot in bots do
			if bot.combatant == victim then
				-- The wreck belongs to TankService now; the bot sits out the rest of the round.
				bot.tank = nil
				bot.brain = nil
			end
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return BotService
