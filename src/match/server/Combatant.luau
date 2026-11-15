--!strict
-- Who is fighting: a player or a bot. Damage, kill credit, scores and shot cooldowns are
-- keyed by Combatant so bots take part in combat exactly like players.

export type Combatant = {
	name: string, -- shown in the kill feed and results
	player: Player?, -- nil for bots and test dummies
	team: string?, -- "Red" / "Blue"; nil = not on a team (spectator, dummy). Set by TeamService.
}

local Combatant = {}

local byPlayer: { [Player]: Combatant } = setmetatable({}, { __mode = "k" }) :: any

-- The same table every time for a given player, so it can be used as a key.
function Combatant.forPlayer(player: Player): Combatant
	local existing = byPlayer[player]
	if existing then
		return existing
	end
	local created: Combatant = { name = player.DisplayName, player = player, team = nil }
	byPlayer[player] = created
	return created
end

function Combatant.bot(name: string, team: string?): Combatant
	return { name = name, player = nil, team = team }
end

return Combatant
