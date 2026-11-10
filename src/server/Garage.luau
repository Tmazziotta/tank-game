--!strict
--!nolint DeprecatedApi
-- (LoadCharacter is flagged in favour of LoadCharacterAsync, which our type definitions
-- don't declare yet.)
-- Garage: buy tanks, buy upgrades, choose which tank to drive. The client asks through
-- Remotes.GarageRequest; the server validates everything against the player's saved data
-- and Config. A new choice (or upgrade) applies at the next round's spawn - immediately
-- during the pre-round countdown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankService = require(script.Parent.TankService)

local Garage = {}

local lastRespawn: { [Player]: number } = {}

local function canRespawnNow(player: Player): boolean
	local tank = TankService.getTank(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tank or not humanoid or humanoid.Health <= 0 then
		return false -- dead: the choice simply applies at the respawn
	end
	local last = lastRespawn[player]
	if last and os.clock() - last < Config.Combat.TankSwitchCooldown then
		return false
	end
	-- Swaps are free during the countdown (or with no match running); once a round is on,
	-- the choice waits for the next round.
	local phase = ReplicatedStorage:GetAttribute(RoundSchema.PhaseAttribute)
	return phase == "PreRound" or phase == "Waiting"
end

-- Respawn into the saved choice if the live tank no longer matches it and that's free.
local function refreshTank(player: Player)
	local data = PlayerData.get(player)
	local tank = TankService.getTank(player)
	if not data or not tank then
		return
	end
	local wanted = PlayerData.upgradesFor(data, data.SelectedTank)
	local current = TankCatalog.upgradesOfModel(tank.model)
	local same = tank.tankId == data.SelectedTank
	for _, track in TankCatalog.trackOrder do
		if (wanted :: any)[track] ~= (current :: any)[track] then
			same = false
		end
	end
	if not same and canRespawnNow(player) then
		lastRespawn[player] = os.clock()
		task.spawn(player.LoadCharacter, player)
	end
end

local function buy(player: Player, id: string): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Data not loaded"
	end
	if data.OwnedTanks[id] then
		return false, "Already owned"
	end
	local def = TankCatalog.get(id)
	if Progression.levelForXP(data.XP) < Progression.levelForTier(def.Tier) then
		return false, `Reach level {Progression.levelForTier(def.Tier)}`
	end
	if data.Coins < def.Cost then
		return false, "Not enough coins"
	end
	PlayerData.update(player, function(d)
		d.Coins -= def.Cost
		d.OwnedTanks[id] = true
		d.SelectedTank = id
	end)
	return true, nil
end

local function upgrade(player: Player, id: string, track: unknown): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Data not loaded"
	end
	if type(track) ~= "string" or not table.find(TankCatalog.trackOrder, track) then
		return false, "Unknown upgrade"
	end
	if not data.OwnedTanks[id] then
		return false, "Tank not owned"
	end
	local levels = PlayerData.upgradesFor(data, id)
	local level = (levels :: any)[track] :: number
	local cost = Progression.upgradeCost(id, level)
	if not cost then
		return false, "Already maxed"
	end
	if data.Coins < cost then
		return false, "Not enough coins"
	end
	PlayerData.update(player, function(d)
		d.Coins -= cost;
		(levels :: any)[track] = level + 1
		d.Upgrades[id] = levels
	end)
	return true, nil
end

local function select(player: Player, id: string): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Data not loaded"
	end
	if not data.OwnedTanks[id] then
		return false, "Tank not owned"
	end
	PlayerData.update(player, function(d)
		d.SelectedTank = id
	end)
	return true, nil
end

local function onRequest(player: Player, action: unknown, id: unknown, track: unknown): (boolean, string?)
	if not TankCatalog.isValid(id) then
		return false, "Unknown tank"
	end
	local tankId = id :: string
	local ok, message
	if action == "Buy" then
		ok, message = buy(player, tankId)
	elseif action == "Upgrade" then
		ok, message = upgrade(player, tankId, track)
	elseif action == "Select" then
		ok, message = select(player, tankId)
	else
		return false, "Unknown action"
	end
	if ok then
		refreshTank(player)
	end
	return ok, message
end

function Garage.start()
	Players.PlayerRemoving:Connect(function(player)
		lastRespawn[player] = nil
	end)
	Remotes.GarageRequest.OnServerInvoke = onRequest
end

return Garage
