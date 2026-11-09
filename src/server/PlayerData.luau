--!strict
-- Saved player progress via ProfileStore (session-locked, autosaved, saved on leave).
-- Every change goes through this module, which mirrors the data to the owning client
-- (Remotes.ProfileSync) so the HUD and garage stay current. When Studio has no API access
-- ProfileStore falls back to an in-memory mock: everything works but nothing persists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local Progression = require(ReplicatedStorage.Shared.Progression)
local ProfileStore = require(ServerScriptService.Vendor.ProfileStore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)

type Data = PlayerDataTypes.Data
type Profile = ProfileStore.Profile<Data>

local PlayerData = {}

-- Player attribute mirroring their level, for overlays/leaderboards that don't need full data.
PlayerData.LevelAttribute = "Level"

local function template(): Data
	local owned = {}
	for _, id in TankCatalog.starters() do
		owned[id] = true
	end
	return {
		Coins = 0,
		XP = 0,
		OwnedTanks = owned,
		Upgrades = {},
		SelectedTank = Config.DefaultTank,
		Stats = { Kills = 0, Deaths = 0, Wins = 0, Rounds = 0 },
	}
end

local store = ProfileStore.New(Config.Data.StoreName, template() :: any)

local profiles: { [Player]: Profile } = {}
local loadedSignals: { [Player]: BindableEvent } = {}

local function dataOf(profile: Profile): Data
	return profile.Data :: any
end

local function sync(player: Player)
	local profile = profiles[player]
	if profile then
		local data = dataOf(profile)
		player:SetAttribute(PlayerData.LevelAttribute, Progression.levelForXP(data.XP))
		Remotes.ProfileSync:FireClient(player, data)
	end
end

-- Repair anything a data change (removed tank, renamed track) could have left invalid.
local function sanitize(data: Data)
	for id in data.OwnedTanks do
		if not TankCatalog.isValid(id) then
			data.OwnedTanks[id] = nil
		end
	end
	for _, id in TankCatalog.starters() do
		data.OwnedTanks[id] = true
	end
	if not data.OwnedTanks[data.SelectedTank] then
		data.SelectedTank = Config.DefaultTank
	end
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		-- Give up if they leave while the load is still waiting on another server's lock.
		Cancel = function()
			return player.Parent ~= Players
		end,
	} :: any)
	if not profile then
		player:Kick("Couldn't load your save data. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId) -- GDPR
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save data was opened on another server. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	sanitize(dataOf(profile))
	profiles[player] = profile
	sync(player)
	local signal = loadedSignals[player]
	if signal then
		loadedSignals[player] = nil
		signal:Fire()
		signal:Destroy()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile then
		profile:EndSession()
	end
	local signal = loadedSignals[player]
	if signal then
		loadedSignals[player] = nil
		signal:Fire()
		signal:Destroy()
	end
end

-- The player's data, or nil if not loaded (yet). Read-only: mutate via `update`.
function PlayerData.get(player: Player): Data?
	local profile = profiles[player]
	return if profile then dataOf(profile) else nil
end

-- Yields until the player's data is loaded; nil if they left first.
function PlayerData.waitFor(player: Player): Data?
	while player.Parent == Players and not profiles[player] do
		local signal = loadedSignals[player]
		if not signal then
			signal = Instance.new("BindableEvent")
			loadedSignals[player] = signal
		end
		signal.Event:Wait()
	end
	return PlayerData.get(player)
end

-- Apply `mutate` to the player's data and push the result to their client.
-- Returns false if the data isn't loaded.
function PlayerData.update(player: Player, mutate: (Data) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutate(dataOf(profile))
	sync(player)
	return true
end

function PlayerData.upgradesFor(data: Data, tankId: string): PlayerDataTypes.UpgradeLevels
	local levels = TankCatalog.noUpgrades()
	local saved = data.Upgrades[tankId]
	if saved then
		for _, track in TankCatalog.trackOrder do
			local value = (saved :: any)[track]
			if type(value) == "number" then
				(levels :: any)[track] = value
			end
		end
	end
	return levels
end

-- Whether saves persist (false in Studio without API access: ProfileStore's mock).
function PlayerData.isPersistent(): boolean
	return ProfileStore.DataStoreState == "Access"
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	-- The client asks once its listener is connected, so the first sync is never missed.
	Remotes.ProfileRequest.OnServerEvent:Connect(sync)
end

return PlayerData
