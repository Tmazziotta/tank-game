--!strict
-- Level, price and unlock rules (pure). Shared so the garage UI shows exactly what the
-- server (Hangar) enforces.

local Config = require(script.Parent.Config)
local PlayerDataTypes = require(script.Parent.PlayerDataTypes)
local TankCatalog = require(script.Parent.TankCatalog)

type Data = PlayerDataTypes.Data

local Progression = {}

-- Total XP needed to reach `level`.
function Progression.xpForLevel(level: number): number
	return Config.Progression.XPPerLevelStep * level * (level - 1) / 2
end

function Progression.levelForXP(xp: number): number
	local level = 1
	while level < Config.Progression.MaxLevel and xp >= Progression.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

-- Progress through the current level: (xp into level, xp the level spans). Span is 0 at max level.
function Progression.levelProgress(xp: number): (number, number)
	local level = Progression.levelForXP(xp)
	if level >= Config.Progression.MaxLevel then
		return 0, 0
	end
	local floor = Progression.xpForLevel(level)
	return xp - floor, Progression.xpForLevel(level + 1) - floor
end

-- Mods ---------------------------------------------------------------------------------

-- Tank XP to unlock a mod in `row` of tank `id`'s tree.
function Progression.modCost(id: string, row: number): number
	local base = Config.Mods.RowXP[row] or math.huge
	return math.round(base * (Config.Mods.TierXPFactor[TankCatalog.get(id).Tier] or 1))
end

function Progression.tankXP(data: Data, id: string): number
	return data.TankXP[id] or 0
end

function Progression.isUnlocked(data: Data, id: string, modId: string): boolean
	local tree = data.Mods[id]
	return tree ~= nil and tree.Unlocked[modId] == true
end

-- Whether `row` of tank `id` has a mod unlocked.
function Progression.rowDone(data: Data, id: string, row: number): boolean
	local entry = TankCatalog.modRows(id)[row]
	if not entry then
		return false
	end
	for _, modId in entry do
		if Progression.isUnlocked(data, id, modId) then
			return true
		end
	end
	return false
end

-- Rows done, counting from the top (a row only opens once the one above is done).
function Progression.rowsDone(data: Data, id: string): number
	local done = 0
	for row = 1, Config.Mods.Rows do
		if not Progression.rowDone(data, id, row) then
			break
		end
		done = row
	end
	return done
end

-- Elite: every row of the tank's tree has a mod unlocked.
function Progression.isElite(data: Data, id: string): boolean
	return Progression.rowsDone(data, id) >= Config.Mods.Rows
end

-- The mods tank `id` drives with: each row's equipped mod, if it's unlocked.
function Progression.equipped(data: Data, id: string): { string }
	local list = {}
	local tree = data.Mods[id]
	if tree then
		local rows = TankCatalog.modRows(id)
		for row, modId in tree.Equipped do
			if modId ~= "" and rows[row] and table.find(rows[row], modId) and tree.Unlocked[modId] then
				table.insert(list, modId)
			end
		end
	end
	return list
end

-- Can the player unlock `modId` on tank `id`? Returns (ok, reason if not, tank XP cost).
function Progression.canUnlockMod(data: Data, id: string, modId: string): (boolean, string?, number)
	local row = TankCatalog.rowOf(id, modId)
	if not row then
		return false, "Not in this tank's tree", 0
	end
	local cost = Progression.modCost(id, row)
	if not data.OwnedTanks[id] then
		return false, "Tank not owned", cost
	end
	if Progression.isUnlocked(data, id, modId) then
		return false, "Already unlocked", cost
	end
	if row > 1 and not Progression.rowDone(data, id, row - 1) then
		return false, "Unlock a mod in the row above first", cost
	end
	if Progression.tankXP(data, id) < cost then
		return false, "Not enough tank XP", cost
	end
	return true, nil, cost
end

-- Tanks ---------------------------------------------------------------------------------

-- Coins to buy tank `id` (another line's starter costs Config.StarterCost).
function Progression.tankCost(id: string): number
	local def = TankCatalog.get(id)
	return if def.Parent then def.Cost else Config.StarterCost
end

-- Can the player buy tank `id`? Returns (ok, reason if not).
function Progression.canBuy(data: Data, id: string): (boolean, string?)
	local def = TankCatalog.get(id)
	if data.OwnedTanks[id] then
		return false, "Already owned"
	end
	if data.Line == "" then
		return false, "Pick a toy line first"
	end
	if def.Parent then
		if not (data.OwnedTanks[def.Parent] and Progression.isElite(data, def.Parent)) then
			return false, `Make {TankCatalog.get(def.Parent).DisplayName} elite first`
		end
	elseif Progression.levelForXP(data.XP) < Config.StarterLevel then
		return false, `Reach level {Config.StarterLevel}`
	end
	if data.Coins < Progression.tankCost(id) then
		return false, "Not enough coins"
	end
	return true, nil
end

return Progression
