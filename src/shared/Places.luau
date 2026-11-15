--!strict
-- Which half of the game this server runs: the Garage (lobby), the Match (arena), or
-- both in dev mode (Studio). Every bootstrap checks this before starting anything.

local Config = require(script.Parent.Config)

export type Role = "Garage" | "Match" | "Dev"

local Places = {}

function Places.role(): Role
	if Config.Places.DevMode then
		return "Dev"
	elseif game.PlaceId == Config.Places.MatchPlaceId then
		return "Match"
	end
	return "Garage"
end

function Places.runsGarage(): boolean
	return Places.role() ~= "Match"
end

function Places.runsMatch(): boolean
	return Places.role() ~= "Garage"
end

return Places
