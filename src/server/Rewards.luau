--!strict
-- Coins and XP: for kills, for winning a round, for finishing and winning a match, and a
-- trickle for time played. Kill rewards only pay out during an active round. Each payout
-- also tells the client (Remotes.Reward) so it can pop up "+25 coins".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local TeamService = require(script.Parent.TeamService)

local Rewards = {}

local function roundActive(): boolean
	return ReplicatedStorage:GetAttribute(RoundSchema.PhaseAttribute) == "Active"
end

-- Give coins and XP; `stat` (optional) is a lifetime Stats counter to bump.
function Rewards.grant(player: Player, coins: number, xp: number, reason: string, stat: string?)
	local levelBefore, levelAfter = 0, 0
	local ok = PlayerData.update(player, function(data)
		levelBefore = Progression.levelForXP(data.XP)
		data.Coins += coins
		data.XP += xp
		if stat then
			(data.Stats :: any)[stat] += 1
		end
		levelAfter = Progression.levelForXP(data.XP)
	end)
	if ok and (coins > 0 or xp > 0) then
		Remotes.Reward:FireClient(player, {
			reason = reason,
			coins = coins,
			xp = xp,
			levelUp = if levelAfter > levelBefore then levelAfter else nil,
		})
	end
end

-- A tank was destroyed. Only players (not bots) are paid, and only in an active round.
function Rewards.onDestroyed(victim: Player?, killer: Player?)
	if not roundActive() then
		return
	end
	if killer and killer ~= victim then
		local e = Config.Economy
		Rewards.grant(killer, e.KillCoins, e.KillXP, "Kill", "Kills")
	end
	if victim then
		PlayerData.update(victim, function(data)
			data.Stats.Deaths += 1
		end)
	end
end

-- Each player on the team that won a round.
function Rewards.onRoundWon(team: string)
	local e = Config.Economy
	for _, player in TeamService.players(team) do
		Rewards.grant(player, e.RoundWinCoins, e.RoundWinXP, "Round won")
	end
end

-- Match over: everyone present gets the participation reward; the winners get more.
-- `winner` is nil for a drawn match. Stats: Rounds counts matches played, Wins matches won.
function Rewards.onMatchEnded(winner: string?)
	local e = Config.Economy
	for _, player in Players:GetPlayers() do
		Rewards.grant(player, e.MatchCoins, e.MatchXP, "Match complete", "Rounds")
	end
	if winner then
		for _, player in TeamService.players(winner) do
			Rewards.grant(player, e.MatchWinCoins, e.MatchWinXP, "Match won", "Wins")
		end
	end
end

function Rewards.start()
	task.spawn(function()
		local e = Config.Economy
		while true do
			task.wait(e.PlaytimeInterval)
			for _, player in Players:GetPlayers() do
				Rewards.grant(player, e.PlaytimeCoins, e.PlaytimeXP, "Playtime")
			end
		end
	end)
end

return Rewards
