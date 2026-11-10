--!strict
-- Per-match kills and deaths. Players' scores live in leaderstats so the default player
-- list shows them; bots' scores are kept here.

local Players = game:GetService("Players")

local Combatant = require(script.Parent.Combatant)

local ScoreService = {}

type Score = { kills: number, deaths: number }

local counting = false
local botScores: { [string]: Score } = {}

local function stat(player: Player, name: string): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	return if value and value:IsA("IntValue") then value else nil
end

local function setupPlayer(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Kills", "Deaths" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
end

local function bump(player: Player, name: string)
	local value = stat(player, name)
	if value then
		value.Value += 1
	end
end

-- Only deaths during an active round count.
function ScoreService.setCounting(on: boolean)
	counting = on
end

local function botScore(name: string): Score
	local score = botScores[name]
	if not score then
		score = { kills = 0, deaths = 0 }
		botScores[name] = score
	end
	return score
end

local function addDeath(who: Combatant.Combatant)
	if who.player then
		bump(who.player, "Deaths")
	else
		botScore(who.name).deaths += 1
	end
end

local function addKill(who: Combatant.Combatant)
	local player = who.player
	if player then
		if player.Parent then
			bump(player, "Kills")
		end
	else
		botScore(who.name).kills += 1
	end
end

function ScoreService.recordDeath(victim: Combatant.Combatant, killer: Combatant.Combatant?)
	if not counting then
		return
	end
	addDeath(victim)
	if killer and killer ~= victim then
		addKill(killer)
	end
end

function ScoreService.reset()
	table.clear(botScores)
	for _, player in Players:GetPlayers() do
		for _, name in { "Kills", "Deaths" } do
			local value = stat(player, name)
			if value then
				value.Value = 0
			end
		end
	end
end

function ScoreService.start()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return ScoreService
