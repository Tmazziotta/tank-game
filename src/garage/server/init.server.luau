--!strict
-- Garage server bootstrap: the lobby where players pick tanks and press PLAY. Runs on the
-- Garage (start) place, and alongside the Match in dev mode (see Places).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Places = require(ReplicatedStorage.Shared.Places)
if not Places.runsGarage() then
	return
end

local Location = require(ReplicatedStorage.Shared.Location)
local Hangar = require(ServerScriptService.Core.Hangar)
local PlayService = require(script.PlayService)
local PlayerData = require(ServerScriptService.Core.PlayerData)
local Travel = require(ServerScriptService.Core.Travel)

PlayerData.start()
Hangar.start()
PlayService.start()
if Places.role() == "Garage" then
	-- Live: PLAY teleports to a reserved Match server (dev mode stays in this server).
	Travel.start()
	PlayService.setTravel(Travel.toMatch)
end

-- Everyone arrives in the Garage.
local function onPlayerAdded(player: Player)
	Location.set(player, "Garage")
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
