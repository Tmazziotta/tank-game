--!strict
-- Who drives what in a match, and getting players home afterwards.
--   * Arrival: a player's tank comes from their saved profile. On the Match place the
--     teleport's TeleportData names the tank they picked, but it's only a hint: it is used
--     only if that tank is valid, owned and in their saved loadout.
--   * Tier: the match plays at one tank tier, set from the first player when it starts
--     (published as RoundSchema.MatchTierAttribute). Anyone else is moved onto a loadout
--     tank of that tier when they have one; counter-picks must stay in it.
--   * Departure: after the result screen everyone returns to the Garage (dev mode: just
--     their Location; live: a teleport, see Travel).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Hangar = require(ServerScriptService.Core.Hangar)
local Location = require(ReplicatedStorage.Shared.Location)
local MatchRoster = require(script.Parent.MatchRoster)
local PlayerData = require(ServerScriptService.Core.PlayerData)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local Places = require(ReplicatedStorage.Shared.Places)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)

type Data = PlayerDataTypes.Data

local MatchEntry = {}

local sendHome: (players: { Player }) -> () = function(players)
	for _, player in players do
		Location.set(player, "Garage")
	end
end

local function usable(data: Data, id: unknown): boolean
	return TankCatalog.isValid(id) and data.OwnedTanks[id :: string] == true and table.find(data.Loadout, id :: string) ~= nil
end

-- The tank the player asked for in their teleport, if any (untrusted).
local function teleportHint(player: Player): unknown
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local teleportData: any = if ok and type(joinData) == "table" then (joinData :: any).TeleportData else nil
	return if type(teleportData) == "table" then teleportData.tankId else nil
end

function MatchEntry.tier(): number
	local value = ReplicatedStorage:GetAttribute(RoundSchema.MatchTierAttribute)
	return if type(value) == "number" then value else 0
end

-- Put the player on a loadout tank of the match tier, if they own one.
local function conform(player: Player)
	local tier = MatchEntry.tier()
	local data = PlayerData.get(player)
	if tier == 0 or not data or TankCatalog.get(data.SelectedTank).Tier == tier then
		return
	end
	for _, id in data.Loadout do
		if TankCatalog.get(id).Tier == tier then
			PlayerData.update(player, function(d)
				d.SelectedTank = id
			end)
			return
		end
	end
end

local function onJoined(player: Player)
	local data = PlayerData.waitFor(player)
	if not data or not MatchRoster.has(player) then
		return
	end
	if Places.role() == "Match" then
		local hint = teleportHint(player)
		if hint ~= nil and hint ~= data.SelectedTank and usable(data, hint) then
			PlayerData.update(player, function(d)
				d.SelectedTank = hint :: string
			end)
		end
	end
	conform(player)
end

-- Match start: the tier comes from the first player's tank; everyone else conforms.
function MatchEntry.beginMatch()
	local tier = 0
	for _, player in MatchRoster.players() do
		local data = PlayerData.get(player)
		if data then
			tier = TankCatalog.get(data.SelectedTank).Tier
			break
		end
	end
	ReplicatedStorage:SetAttribute(RoundSchema.MatchTierAttribute, tier)
	for _, player in MatchRoster.players() do
		conform(player)
	end
end

-- Match over (after the result screen): everyone in it goes back to the Garage.
function MatchEntry.endMatch()
	ReplicatedStorage:SetAttribute(RoundSchema.MatchTierAttribute, 0)
	sendHome(MatchRoster.players())
end

-- Replace how players are sent home (the live Match place teleports them).
function MatchEntry.setSendHome(send: (players: { Player }) -> ())
	sendHome = send
end

function MatchEntry.start()
	ReplicatedStorage:SetAttribute(RoundSchema.MatchTierAttribute, 0)
	MatchRoster.onJoined(onJoined)
	Hangar.setMatchRule(function(_player: Player, tankId: string): (boolean, string?)
		local tier = MatchEntry.tier()
		if tier ~= 0 and TankCatalog.get(tankId).Tier ~= tier then
			return false, `This match is Tier {tier}`
		end
		return true, nil
	end)
end

return MatchEntry
