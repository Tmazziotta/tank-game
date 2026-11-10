--!strict
-- Team lookups shared by server and client.

local Config = require(script.Parent.Config)

export type Team = { DisplayName: string, Color: Color3 }

local TeamInfo = {}

-- Attribute on tank models: the team ("Red" / "Blue") the tank fights for.
TeamInfo.Attribute = "Team"

TeamInfo.order = Config.Teams.Order :: { string }

local teams: { [string]: Team } = Config.Teams :: any

function TeamInfo.get(name: string): Team?
	if table.find(TeamInfo.order, name) then
		return teams[name]
	end
	return nil
end

function TeamInfo.color(name: string?): Color3
	local team = if name then TeamInfo.get(name) else nil
	return if team then team.Color else Color3.new(1, 1, 1)
end

function TeamInfo.other(name: string): string
	return if name == TeamInfo.order[1] then TeamInfo.order[2] else TeamInfo.order[1]
end

return TeamInfo
