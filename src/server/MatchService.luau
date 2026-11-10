--!strict
--!nolint DeprecatedApi
-- (LoadCharacter is flagged in favour of LoadCharacterAsync, which our type definitions
-- don't declare yet.)
-- 3v3 elimination, best of 5. A match: shuffle teams, then rounds until one team has
-- Config.Round.RoundsToWin wins (or MaxRounds have been played). A round: rebuild the map,
-- swap sides, fill empty slots with bots, spawn everyone frozen for a countdown, then fight
-- until a team is wiped out or the time cap hits, where the higher team health % wins.
-- State is published as attributes on ReplicatedStorage (see RoundSchema).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotService = require(script.Parent.BotService)
local Config = require(ReplicatedStorage.Shared.Config)
local MapService = require(script.Parent.MapService)
local Rewards = require(script.Parent.Rewards)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local ScoreService = require(script.Parent.ScoreService)
local TankHealth = require(script.Parent.TankHealth)
local TankSchema = require(ReplicatedStorage.Shared.TankSchema)
local TankService = require(script.Parent.TankService)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local TeamService = require(script.Parent.TeamService)
local WeaponService = require(script.Parent.WeaponService)

local MatchService = {}

type Participant = { model: Model, team: string, maxHealth: number }

local participants: { Participant } = {} -- every tank that started this round

local function setPhase(phase: RoundSchema.Phase, duration: number?)
	ReplicatedStorage:SetAttribute(RoundSchema.PhaseAttribute, phase)
	ReplicatedStorage:SetAttribute(
		RoundSchema.EndsAtAttribute,
		if duration then workspace:GetServerTimeNow() + duration else 0
	)
end

local function setTeamAttribute(prefix: string, team: string, value: number)
	ReplicatedStorage:SetAttribute(prefix .. team, value)
end

local function enoughPlayers(): boolean
	return #Players:GetPlayers() >= Config.Round.MinPlayers
end

-- Waits `seconds`, returning false early if `abort` becomes true.
local function countdown(seconds: number, abort: () -> boolean): boolean
	local endsAt = os.clock() + seconds
	while os.clock() < endsAt do
		if abort() then
			return false
		end
		task.wait(0.1)
	end
	return true
end

-- Freeze/unfreeze the whole arena: hulls anchored, guns and damage off, bots idle.
local function setFrozen(on: boolean)
	TankService.setFrozen(on)
	BotService.setFrozen(on)
	WeaponService.setEnabled(not on)
	TankHealth.setEnabled(not on)
end

-- Live tanks per team, and team health fraction (remaining / max over everyone who
-- started the round; destroyed or departed tanks count 0).
local function teamStatus(team: string): (number, number)
	local alive, health, maxHealth = 0, 0, 0
	for _, p in participants do
		if p.team == team then
			maxHealth += p.maxHealth
			local live = TankService.combatantOf(p.model) ~= nil
			if live then
				alive += 1
				local value = p.model:GetAttribute(TankSchema.HealthAttribute)
				health += if type(value) == "number" then math.max(value, 0) else 0
			end
		end
	end
	return alive, if maxHealth > 0 then health / maxHealth else 0
end

local function publishStatus()
	for _, team in TeamInfo.order do
		local alive, health = teamStatus(team)
		setTeamAttribute(RoundSchema.AlivePrefix, team, alive)
		setTeamAttribute(RoundSchema.HealthPrefix, team, health)
	end
end

-- Track every live team tank as a participant of this round (idempotent: also picks up
-- tanks that spawned late, e.g. a garage swap at the very end of the countdown).
local function recordParticipants()
	for _, entry in TankService.liveTanks() do
		local team = entry.combatant.team
		local model = entry.tank.model
		local known = false
		for _, p in participants do
			if p.model == model then
				known = true
				break
			end
		end
		if team and not known then
			table.insert(participants, { model = model, team = team, maxHealth = entry.tank.spec.MaxHealth })
		end
	end
end

-- Spawn every player and bot for a round. Waits (briefly) for player tanks to exist.
local function spawnEveryone()
	TankService.despawnAll()
	for _, player in Players:GetPlayers() do
		task.spawn(player.LoadCharacter, player)
	end
	BotService.fillTeams()
	local deadline = os.clock() + 5
	while os.clock() < deadline do
		local missing = false
		for _, player in Players:GetPlayers() do
			if TeamService.teamOf(player) and not TankService.getTank(player) then
				missing = true
			end
		end
		if not missing then
			break
		end
		task.wait(0.1)
	end
end

-- Play one round. Returns the winning team (nil = draw) and how it was decided.
local function playRound(round: number): (string?, RoundSchema.EndReason)
	ReplicatedStorage:SetAttribute(RoundSchema.RoundNumberAttribute, round)
	TankService.clearWrecks()
	MapService.RoundReset()
	TeamService.setRound(round)
	setFrozen(true)
	spawnEveryone()

	local preRound = if round == 1 then Config.Round.FirstPreRound else Config.Round.PreRound
	setPhase("PreRound", preRound)
	-- Players may swap tanks during the countdown (Garage respawns them, still frozen).
	countdown(preRound, function()
		table.clear(participants)
		recordParticipants()
		publishStatus()
		return false
	end)

	table.clear(participants)
	recordParticipants()
	setFrozen(false)
	setPhase("Active", Config.Round.Duration)

	local a, b = TeamInfo.order[1], TeamInfo.order[2]
	local endsAt = os.clock() + Config.Round.Duration
	while true do
		recordParticipants()
		publishStatus()
		local aliveA, healthA = teamStatus(a)
		local aliveB, healthB = teamStatus(b)
		if aliveA == 0 and aliveB == 0 then
			return nil, "Draw"
		elseif aliveA == 0 then
			return b, "Wipe"
		elseif aliveB == 0 then
			return a, "Wipe"
		elseif os.clock() >= endsAt then
			-- Compare to the nearest tenth of a percent, as the HUD shows it.
			local pa, pb = math.round(healthA * 1000), math.round(healthB * 1000)
			if pa == pb then
				return nil, "Draw"
			end
			return (if pa > pb then a else b), "Health"
		elseif #Players:GetPlayers() == 0 then
			return nil, "Draw"
		end
		task.wait(Config.Round.LiveInterval)
	end
end

local function playMatch(first: boolean)
	if not first then
		MapService.advance()
	end
	TeamService.balance()
	ScoreService.reset()
	ScoreService.setCounting(true)
	local wins: { [string]: number } = {}
	for _, team in TeamInfo.order do
		wins[team] = 0
		setTeamAttribute(RoundSchema.WinsPrefix, team, 0)
	end
	ReplicatedStorage:SetAttribute(RoundSchema.MatchWinnerAttribute, "")

	local cfg = Config.Round
	local round = 0
	while round < cfg.MaxRounds do
		round += 1
		local winner, reason = playRound(round)
		if winner then
			wins[winner] += 1
			setTeamAttribute(RoundSchema.WinsPrefix, winner, wins[winner])
			Rewards.onRoundWon(winner)
		end
		ReplicatedStorage:SetAttribute(RoundSchema.RoundWinnerAttribute, winner or "")
		ReplicatedStorage:SetAttribute(RoundSchema.RoundReasonAttribute, reason)
		-- Freeze the survivors so nothing happens on the result screen.
		setFrozen(true)
		setPhase("RoundOver", cfg.RoundOver)
		task.wait(cfg.RoundOver)
		if (winner and wins[winner] >= cfg.RoundsToWin) or #Players:GetPlayers() == 0 then
			break
		end
	end

	local a, b = TeamInfo.order[1], TeamInfo.order[2]
	local matchWinner = if wins[a] > wins[b] then a elseif wins[b] > wins[a] then b else nil
	ReplicatedStorage:SetAttribute(RoundSchema.MatchWinnerAttribute, matchWinner or "")
	ScoreService.setCounting(false)
	Rewards.onMatchEnded(matchWinner)
	setPhase("MatchOver", cfg.MatchOver)
	task.wait(cfg.MatchOver)
end

local function loop()
	local first = true
	while true do
		if not enoughPlayers() then
			setFrozen(false)
			BotService.clear()
			setPhase("Waiting")
			repeat
				task.wait(1)
			until enoughPlayers()
		end
		playMatch(first)
		first = false
	end
end

function MatchService.start()
	task.spawn(loop)
end

return MatchService
