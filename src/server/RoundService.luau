--!strict
-- Free-for-all round loop: Waiting (too few players) -> Intermission -> Active (timed,
-- kills count) -> Results -> Intermission ... Each round starts on a freshly rebuilt map
-- with everyone respawned and scores zeroed. State is published as attributes on
-- ReplicatedStorage (see RoundSchema).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotService = require(script.Parent.BotService)
local Config = require(ReplicatedStorage.Shared.Config)
local MapService = require(script.Parent.MapService)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local ScoreService = require(script.Parent.ScoreService)
local TankHealth = require(script.Parent.TankHealth)
local TankService = require(script.Parent.TankService)

local RoundService = {}

local function setPhase(phase: RoundSchema.Phase, duration: number?)
	ReplicatedStorage:SetAttribute(RoundSchema.PhaseAttribute, phase)
	ReplicatedStorage:SetAttribute(
		RoundSchema.EndsAtAttribute,
		if duration then workspace:GetServerTimeNow() + duration else 0
	)
end

-- Bots count, so a solo player with a bot gets real rounds.
local function enoughPlayers(): boolean
	return #Players:GetPlayers() + BotService.count() >= Config.Round.MinPlayers
end

-- Waits `seconds`, returning false early if `abort` becomes true.
local function countdown(seconds: number, abort: () -> boolean): boolean
	local endsAt = os.clock() + seconds
	while os.clock() < endsAt do
		if abort() then
			return false
		end
		task.wait(0.25)
	end
	return true
end

local function startRound()
	TankService.clearWrecks()
	MapService.RoundReset()
	ScoreService.reset()
	TankHealth.setEnabled(true)
	for _, player in Players:GetPlayers() do
		task.spawn(player.LoadCharacter, player)
	end
	BotService.respawnAll()
end

local function endRound()
	ScoreService.setCounting(false)
	TankHealth.setEnabled(false)
	local winner, kills = ScoreService.winner()
	ReplicatedStorage:SetAttribute(RoundSchema.WinnerAttribute, winner or "")
	ReplicatedStorage:SetAttribute(RoundSchema.WinnerKillsAttribute, kills)
	setPhase("Results", Config.Round.Results)
	task.wait(Config.Round.Results)
	TankHealth.setEnabled(true)
end

local function loop()
	while true do
		if not enoughPlayers() then
			setPhase("Waiting")
			repeat
				task.wait(1)
			until enoughPlayers()
		end

		setPhase("Intermission", Config.Round.Intermission)
		if countdown(Config.Round.Intermission, function()
			return not enoughPlayers()
		end) then
			startRound()
			setPhase("Active", Config.Round.Duration)
			ScoreService.setCounting(true)
			countdown(Config.Round.Duration, function()
				return #Players:GetPlayers() == 0
			end)
			endRound()
		end
	end
end

function RoundService.start()
	task.spawn(loop)
end

return RoundService
