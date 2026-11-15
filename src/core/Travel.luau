--!strict
-- Teleports between the Garage and Match places (live servers; Studio uses dev mode, which
-- moves players inside one server, since a Studio teleport loads the published places).
--   * toMatch: reserve a fresh Match server, save + release the player's profile, and
--     teleport them with TeleportData { tankId, tier } (a hint the Match re-validates).
--   * toGarage: save + release everyone's profile and teleport them to the Garage.
-- Every teleport is retried once (Config.Places.TeleportAttempts); after that toMatch
-- reloads the profile and tells the player, and toGarage kicks with a rejoin message
-- (their rewards are already saved).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Ticket = { tankId: string, tier: number }

type Job = {
	placeId: number,
	options: TeleportOptions,
	giveUp: (player: Player, reason: string) -> (),
}

local Travel = {}

local jobs: { [Player]: Job } = {} -- teleports in flight
local attempts: { [Player]: number } = {}
local started = false

local function giveUp(player: Player, reason: string)
	local job = jobs[player]
	jobs[player] = nil
	attempts[player] = nil
	if job and player.Parent == Players then
		warn(`[Travel] gave up teleporting {player.Name}: {reason}`)
		job.giveUp(player, reason)
	end
end

-- Teleport `players` (who all share `job`); failures retry per player.
local function attempt(players: { Player }, job: Job)
	local live = {}
	for _, player in players do
		if player.Parent == Players then
			jobs[player] = job
			attempts[player] = (attempts[player] or 0) + 1
			table.insert(live, player)
		end
	end
	if #live == 0 then
		return
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(job.placeId, live, job.options)
	end)
	if not ok then
		for _, player in live do
			task.spawn(Travel.retry, player, tostring(err))
		end
	end
end

-- A teleport for `player` failed: try again, or give up after the last attempt.
function Travel.retry(player: Player, reason: string)
	local job = jobs[player]
	if not job then
		return
	end
	if (attempts[player] or 0) >= Config.Places.TeleportAttempts then
		giveUp(player, reason)
		return
	end
	task.wait(Config.Places.TeleportRetryDelay)
	if jobs[player] == job then
		attempt({ player }, job)
	end
end

-- PLAY on the live Garage: send `player` to a new reserved Match server.
function Travel.toMatch(player: Player, ticket: Ticket): (boolean, string?)
	local placeId = Config.Places.MatchPlaceId
	local code: string? = nil
	for _ = 1, Config.Places.TeleportAttempts do
		local ok, result = pcall(function()
			return (TeleportService:ReserveServer(placeId))
		end)
		if ok and type(result) == "string" then
			code = result
			break
		end
		warn(`[Travel] ReserveServer failed: {result}`)
		task.wait(Config.Places.TeleportRetryDelay)
	end
	if not code then
		return false, "Couldn't find a match server. Try again."
	end

	-- (Typed as any: our type definitions lack the real ReservedServerAccessCode property.)
	local options: any = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ tankId = ticket.tankId, tier = ticket.tier })
	PlayerData.release(player)
	attempt({ player }, {
		placeId = placeId,
		options = options,
		giveUp = function(p: Player, _reason: string)
			task.spawn(PlayerData.reacquire, p)
			Remotes.Toast:FireClient(p, "Couldn't start the match. Try again.", "PlayFailed")
		end,
	})
	return true, nil
end

-- End of a live match: send everyone back to the Garage (together, in one call).
function Travel.toGarage(players: { Player })
	for _, player in players do
		PlayerData.release(player)
	end
	attempt(players, {
		placeId = Config.Places.GaragePlaceId,
		options = Instance.new("TeleportOptions"),
		giveUp = function(p: Player, _reason: string)
			p:Kick("Match over! Rejoin to return to the Garage. Your rewards are saved.")
		end,
	})
end

function Travel.start()
	if started then
		return
	end
	started = true
	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
		if jobs[player] then
			Travel.retry(player, `{result.Name}: {message}`)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- Leaving mid-teleport means it worked (or they quit): either way, stop tracking.
		jobs[player] = nil
		attempts[player] = nil
	end)
end

return Travel
