--!strict
-- Where a player is: the Garage (lobby) or a Match (arena). The server sets it as a player
-- attribute; match code only counts players in the Match, and each client shows the UI for
-- where it is. On the live places it never changes (each place is one location); in dev
-- mode PLAY and the end of a match move players between the two in one server.

local Location = {}

export type Place = "Garage" | "Match"

Location.Attribute = "Location"

function Location.get(player: Player): Place?
	local value = player:GetAttribute(Location.Attribute)
	if value == "Garage" or value == "Match" then
		return value
	end
	return nil
end

-- Server only.
function Location.set(player: Player, place: Place)
	player:SetAttribute(Location.Attribute, place)
end

function Location.changed(player: Player): RBXScriptSignal
	return player:GetAttributeChangedSignal(Location.Attribute)
end

return Location
