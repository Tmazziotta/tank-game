--!strict
-- Shows the match client only while this player is in a match (see LocationGate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocationGate = require(ReplicatedStorage.Shared.LocationGate)

local gate = LocationGate.new("Match")

return {
	inMatch = gate.active,
	mount = gate.mount,
	-- Fires (inMatch: boolean) when the player enters or leaves a match.
	changed = gate.changed,
	start = gate.start,
}
