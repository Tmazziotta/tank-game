--!strict
-- Garage server bootstrap: the lobby where players pick tanks and press PLAY. Runs on the
-- Garage (start) place, and alongside the Match in dev mode (see Places).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Places = require(ReplicatedStorage.Shared.Places)
if not Places.runsGarage() then
	return
end

local PlayerData = require(ServerScriptService.Core.PlayerData)

PlayerData.start()
