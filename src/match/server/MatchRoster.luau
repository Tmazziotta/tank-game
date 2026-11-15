--!strict
-- The players taking part in matches: everyone whose Location is "Match". On the Match
-- place that's every player (set on join); in dev mode, only those who pressed PLAY.
-- Match code asks this module instead of Players:GetPlayers(), and hears about players
-- joining and leaving the match through onJoined / onLeft.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Location = require(ReplicatedStorage.Shared.Location)
local Places = require(ReplicatedStorage.Shared.Places)

local MatchRoster = {}

local members: { [Player]: boolean } = {}
local joinedCallbacks: { (Player) -> () } = {}
local leftCallbacks: { (Player) -> () } = {}

local function fire(callbacks: { (Player) -> () }, player: Player)
	for _, callback in callbacks do
		task.spawn(callback, player)
	end
end

local function update(player: Player)
	local inMatch = player.Parent == Players and Location.get(player) == "Match"
	if inMatch and not members[player] then
		members[player] = true
		fire(joinedCallbacks, player)
	elseif not inMatch and members[player] then
		members[player] = nil
		fire(leftCallbacks, player)
	end
end

local function track(player: Player)
	if Places.role() == "Match" then
		Location.set(player, "Match")
	end
	Location.changed(player):Connect(function()
		update(player)
	end)
	update(player)
end

-- Players in the match, in join order of the server's player list.
function MatchRoster.players(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if members[player] then
			table.insert(list, player)
		end
	end
	return list
end

function MatchRoster.has(player: Player): boolean
	return members[player] == true
end

function MatchRoster.count(): number
	return #MatchRoster.players()
end

function MatchRoster.onJoined(callback: (Player) -> ())
	table.insert(joinedCallbacks, callback)
end

function MatchRoster.onLeft(callback: (Player) -> ())
	table.insert(leftCallbacks, callback)
end

-- Call after the other match modules have registered their callbacks.
function MatchRoster.start()
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		-- Still parented to Players while this fires, so remove explicitly.
		if members[player] then
			members[player] = nil
			fire(leftCallbacks, player)
		end
	end)
	for _, player in Players:GetPlayers() do
		track(player)
	end
end

return MatchRoster
