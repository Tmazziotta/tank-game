--!strict
-- Per-round kills and deaths, kept in leaderstats so the default player list shows them.

local Players = game:GetService("Players")

local ScoreService = {}

local counting = false

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

function ScoreService.recordDeath(victim: Player?, killer: Player?)
	if not counting then
		return
	end
	if victim then
		bump(victim, "Deaths")
	end
	if killer and killer ~= victim and killer.Parent then
		bump(killer, "Kills")
	end
end

function ScoreService.reset()
	for _, player in Players:GetPlayers() do
		for _, name in { "Kills", "Deaths" } do
			local value = stat(player, name)
			if value then
				value.Value = 0
			end
		end
	end
end

-- Most kills wins; fewer deaths breaks a tie. Returns nil (a draw) if still tied or
-- nobody scored.
function ScoreService.winner(): (Player?, number)
	local best: Player? = nil
	local bestKills, bestDeaths = 0, math.huge
	local tied = false
	for _, player in Players:GetPlayers() do
		local kills = stat(player, "Kills")
		local deaths = stat(player, "Deaths")
		if kills and deaths and kills.Value > 0 then
			if kills.Value > bestKills or (kills.Value == bestKills and deaths.Value < bestDeaths) then
				best, bestKills, bestDeaths, tied = player, kills.Value, deaths.Value, false
			elseif kills.Value == bestKills and deaths.Value == bestDeaths then
				tied = true
			end
		end
	end
	if tied then
		return nil, bestKills
	end
	return best, bestKills
end

function ScoreService.start()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return ScoreService
