--!strict
-- Tank ownership and choice: pick a toy line (first join), buy tanks, unlock and equip mods
-- (spending tank XP), pick which loadout tank to drive and what goes in each loadout slot.
-- Clients ask through Remotes.GarageRequest(action, id, extra); everything is validated
-- against saved data and Config (rules in Progression). One handler serves both places:
--   * In the Garage, everything is allowed. "Select" on a tank outside the loadout puts it
--     in the slot of the currently selected tank.
--   * In a Match (Location "Match"), only "Select" between loadout tanks is allowed, plus
--     whatever extra rule the match sets (setMatchRule: e.g. same tier as the match).
-- onChanged callbacks hear about every successful change (the match respawns into it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Location = require(ReplicatedStorage.Shared.Location)
local PlayerData = require(script.Parent.PlayerData)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)

type Data = PlayerDataTypes.Data
export type Rule = (player: Player, tankId: string) -> (boolean, string?)

local Hangar = {}

-- Requests a player may make while in a match (counter-pick only).
local MATCH_ACTIONS: { [string]: boolean } = { Select = true }

local matchRule: Rule? = nil
local changedCallbacks: { (Player) -> () } = {}
local started = false

local function pickLine(player: Player, data: Data, line: unknown): (boolean, string?)
	if data.Line ~= "" then
		return false, "You already picked a line"
	end
	if not TankCatalog.isLine(line) then
		return false, "Unknown toy line"
	end
	local starter = TankCatalog.starterOf(line :: string)
	PlayerData.update(player, function(d)
		d.Line = line :: string
		d.OwnedTanks[starter] = true
		d.Loadout = { starter }
		d.SelectedTank = starter
	end)
	return true, nil
end

local function buy(player: Player, data: Data, id: string): (boolean, string?)
	local ok, message = Progression.canBuy(data, id)
	if not ok then
		return false, message
	end
	local cost = Progression.tankCost(id)
	PlayerData.update(player, function(d)
		d.Coins -= cost
		d.OwnedTanks[id] = true
		if #d.Loadout < Config.Garage.LoadoutSlots then
			table.insert(d.Loadout, id)
		end
	end)
	return true, nil
end

local function treeOf(d: Data, id: string): PlayerDataTypes.TankMods
	local tree = d.Mods[id]
	if not tree then
		local equipped = {}
		for row = 1, Config.Mods.Rows do
			equipped[row] = ""
		end
		tree = { Unlocked = {}, Equipped = equipped }
		d.Mods[id] = tree
	end
	return tree
end

local function unlockMod(player: Player, data: Data, id: string, modId: unknown): (boolean, string?)
	if not TankCatalog.isMod(modId) then
		return false, "Unknown mod"
	end
	local mod = modId :: string
	local ok, message, cost = Progression.canUnlockMod(data, id, mod)
	if not ok then
		return false, message
	end
	local row = TankCatalog.rowOf(id, mod) :: number
	PlayerData.update(player, function(d)
		d.TankXP[id] = (d.TankXP[id] or 0) - cost
		local tree = treeOf(d, id)
		tree.Unlocked[mod] = true
		if tree.Equipped[row] == "" then
			tree.Equipped[row] = mod -- a row's first mod goes straight on
		end
	end)
	return true, nil
end

local function equipMod(player: Player, data: Data, id: string, modId: unknown): (boolean, string?)
	if not TankCatalog.isMod(modId) then
		return false, "Unknown mod"
	end
	local mod = modId :: string
	if not Progression.isUnlocked(data, id, mod) then
		return false, "Mod not unlocked"
	end
	local row = TankCatalog.rowOf(id, mod) :: number
	PlayerData.update(player, function(d)
		treeOf(d, id).Equipped[row] = mod
	end)
	return true, nil
end

-- Put `id` in loadout slot `slot`; if it's already in another slot, the two swap.
local function setSlot(player: Player, data: Data, slot: unknown, id: string): (boolean, string?)
	if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > #data.Loadout then
		return false, "Unknown slot"
	end
	if not data.OwnedTanks[id] then
		return false, "Tank not owned"
	end
	PlayerData.update(player, function(d)
		local previous = d.Loadout[slot]
		local existing = table.find(d.Loadout, id)
		if existing then
			d.Loadout[existing] = previous
		end
		d.Loadout[slot] = id
		if d.SelectedTank == previous then
			d.SelectedTank = id -- the selected slot keeps being the selected one
		end
	end)
	return true, nil
end

local function select(player: Player, data: Data, id: string, inMatch: boolean): (boolean, string?)
	if not data.OwnedTanks[id] then
		return false, "Tank not owned"
	end
	if not table.find(data.Loadout, id) then
		if inMatch then
			return false, "Not in your loadout"
		end
		-- Garage: drive it from the currently selected slot.
		local slot = table.find(data.Loadout, data.SelectedTank) or 1
		local ok, message = setSlot(player, data, slot, id)
		if not ok then
			return ok, message
		end
	end
	if inMatch and matchRule then
		local ok, message = matchRule(player, id)
		if not ok then
			return ok, message
		end
	end
	PlayerData.update(player, function(d)
		d.SelectedTank = id
	end)
	return true, nil
end

local function onRequest(player: Player, action: unknown, id: unknown, extra: unknown): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Data not loaded"
	end
	local inMatch = Location.get(player) == "Match"
	if inMatch and not (type(action) == "string" and MATCH_ACTIONS[action]) then
		return false, "Do that in the Garage"
	end
	if action == "PickLine" then
		return pickLine(player, data, id) -- id is the line name
	end
	if not TankCatalog.isValid(id) then
		return false, "Unknown tank"
	end
	local tankId = id :: string
	local ok, message
	if action == "Buy" then
		ok, message = buy(player, data, tankId)
	elseif action == "UnlockMod" then
		ok, message = unlockMod(player, data, tankId, extra)
	elseif action == "EquipMod" then
		ok, message = equipMod(player, data, tankId, extra)
	elseif action == "Select" then
		ok, message = select(player, data, tankId, inMatch)
	elseif action == "SetSlot" then
		ok, message = setSlot(player, data, extra, tankId)
	else
		return false, "Unknown action"
	end
	if ok then
		for _, callback in changedCallbacks do
			task.spawn(callback, player)
		end
	end
	return ok, message
end

-- Extra check for "Select" during a match (the match's tier rule).
function Hangar.setMatchRule(rule: Rule)
	matchRule = rule
end

function Hangar.onChanged(callback: (Player) -> ())
	table.insert(changedCallbacks, callback)
end

-- Safe to call from every bootstrap.
function Hangar.start()
	if started then
		return
	end
	started = true
	Remotes.GarageRequest.OnServerInvoke = onRequest
end

return Hangar
