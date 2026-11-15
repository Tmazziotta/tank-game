--!strict
-- PLAY: start a match with the selected tank. The server checks the player is in the
-- Garage with their data loaded and drives a loadout tank (PlayerData keeps that true).
-- Dev mode moves them into this server's arena; on the live Garage place `travel` sends
-- them to a match server (set by Travel).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Location = require(ReplicatedStorage.Shared.Location)
local PlayerData = require(ServerScriptService.Core.PlayerData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)

export type Ticket = { tankId: string, tier: number }

local PlayService = {}

local busy: { [Player]: boolean } = {}

local travel: (player: Player, ticket: Ticket) -> (boolean, string?) = function(player, _ticket)
	Location.set(player, "Match")
	return true, nil
end

local function onPlay(player: Player): (boolean, string?)
	if busy[player] then
		return false, "Already starting"
	end
	if Location.get(player) ~= "Garage" then
		return false, "Already in a match"
	end
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading your garage"
	end
	local tankId = data.SelectedTank
	if not TankCatalog.isValid(tankId) or not data.OwnedTanks[tankId] or not table.find(data.Loadout, tankId) then
		return false, "Pick a tank from your loadout"
	end
	busy[player] = true
	local ok, result, message = pcall(travel, player, { tankId = tankId, tier = TankCatalog.get(tankId).Tier })
	busy[player] = nil
	if not ok then
		warn(`[PlayService] {player.Name}: {result}`)
		return false, "Couldn't start the match. Try again."
	end
	return result, message
end

-- Replace how a player gets to a match (the live Garage teleports them).
function PlayService.setTravel(fn: (player: Player, ticket: Ticket) -> (boolean, string?))
	travel = fn
end

function PlayService.start()
	Remotes.PlayRequest.OnServerInvoke = onPlay
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return PlayService
