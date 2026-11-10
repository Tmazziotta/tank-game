--!strict
-- Red vs Blue. Players are put on the team with fewer players (new joiners) or shuffled
-- evenly at the start of each match. Teams also own a map side per round: side 1 or 2,
-- swapped every round so asymmetric maps are fair.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Combatant = require(script.Parent.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)

local TeamService = {}

local teamObjects: { [string]: Team } = {}
local sideOfTeam: { [string]: number } = {}

local function setTeam(player: Player, name: string)
	Combatant.forPlayer(player).team = name
	player.Team = teamObjects[name]
end

-- Players currently on `name`.
function TeamService.players(name: string): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if Combatant.forPlayer(player).team == name then
			table.insert(list, player)
		end
	end
	return list
end

function TeamService.teamOf(player: Player): string?
	return Combatant.forPlayer(player).team
end

-- Put a player on the team with fewer players (ties: random).
function TeamService.assign(player: Player)
	local a, b = TeamInfo.order[1], TeamInfo.order[2]
	local countA, countB = #TeamService.players(a), #TeamService.players(b)
	local pick = if countA < countB then a elseif countB < countA then b elseif math.random() < 0.5 then a else b
	setTeam(player, pick)
end

-- Shuffle all players into two even teams (match start).
function TeamService.balance()
	local players = Players:GetPlayers()
	for i = #players, 2, -1 do
		local j = math.random(i)
		players[i], players[j] = players[j], players[i]
	end
	for i, player in players do
		setTeam(player, TeamInfo.order[(i - 1) % 2 + 1])
	end
end

-- Map side (1 or 2) for each team this round: swaps every round.
function TeamService.setRound(round: number)
	local flip = round % 2 == 0
	sideOfTeam[TeamInfo.order[1]] = if flip then 2 else 1
	sideOfTeam[TeamInfo.order[2]] = if flip then 1 else 2
end

function TeamService.sideOf(team: string): number
	return sideOfTeam[team] or (if team == TeamInfo.order[1] then 1 else 2)
end

-- Empty slots per team (filled by bots).
function TeamService.openSlots(team: string): number
	return math.max(0, Config.Round.TeamSize - #TeamService.players(team))
end

function TeamService.start()
	for _, name in TeamInfo.order do
		local info = TeamInfo.get(name) :: TeamInfo.Team
		local team = Instance.new("Team")
		team.Name = info.DisplayName
		team.TeamColor = BrickColor.new(info.Color)
		team.AutoAssignable = false
		team.Parent = Teams
		teamObjects[name] = team
	end
	Players.PlayerAdded:Connect(TeamService.assign)
	for _, player in Players:GetPlayers() do
		TeamService.assign(player)
	end
end

return TeamService
