--!strict
-- The toy lines, their tanks (Config.Tanks), the mod trees and effective stats. A tank's
-- stats are its class's base stats x its line's Mods x TierScale x the tank's own Mods x
-- its equipped stat mods. Shared so the server (spawning, combat) and the client (driving,
-- garage UI) compute identical numbers.

local Config = require(script.Parent.Config)
local TankClass = require(script.Parent.TankClass)

export type Mods = {
	Health: number?,
	Damage: number?,
	Reload: number?,
	Speed: number?,
	Turret: number?,
	Armor: number?,
}

export type TankDef = {
	Line: string,
	Class: string,
	Tier: number,
	Parent: string?, -- the tank whose elite unlocks this one (nil for a starter)
	DisplayName: string,
	Cost: number,
	Mods: Mods,
	ModRows: { { string } }, -- rows 3+ of its mod tree
}

export type LineDef = {
	DisplayName: string,
	Color: Color3,
	Blurb: string,
	Mods: Mods,
}

export type ModDef = {
	DisplayName: string,
	Blurb: string,
	Stats: Mods?,
	Behavior: string?,
}

local TankCatalog = {}

-- Attributes on a tank model: which tank it is and its equipped mods (comma-separated).
TankCatalog.IdAttribute = "TankId"
TankCatalog.ModsAttribute = "Mods"

TankCatalog.order = Config.TankOrder :: { string }
TankCatalog.lineOrder = Config.Lines.Order :: { string }

local defs: { [string]: TankDef } = Config.Tanks :: any
local lines: { [string]: LineDef } = Config.Lines.Defs :: any
local mods: { [string]: ModDef } = Config.Mods.Defs :: any
local commonRows: { { string } } = Config.Mods.CommonRows :: any

function TankCatalog.isValid(id: unknown): boolean
	return type(id) == "string" and defs[id] ~= nil
end

function TankCatalog.get(id: unknown): TankDef
	if type(id) == "string" and defs[id] then
		return defs[id]
	end
	return defs[Config.DefaultTank]
end

function TankCatalog.normalize(id: unknown): string
	return if TankCatalog.isValid(id) then id :: string else Config.DefaultTank
end

function TankCatalog.isLine(line: unknown): boolean
	return type(line) == "string" and lines[line] ~= nil
end

function TankCatalog.line(line: string): LineDef
	return lines[line] or lines[TankCatalog.lineOrder[1]]
end

-- The tier 1 starter of `line`.
function TankCatalog.starterOf(line: string): string
	for _, id in TankCatalog.order do
		local def = defs[id]
		if def.Line == line and not def.Parent then
			return id
		end
	end
	return Config.DefaultTank
end

-- Tanks of `line`, in catalog order.
function TankCatalog.ofLine(line: string): { string }
	local list = {}
	for _, id in TankCatalog.order do
		if defs[id].Line == line then
			table.insert(list, id)
		end
	end
	return list
end

-- Tanks whose Parent is `id` (unlocked by its elite).
function TankCatalog.children(id: string): { string }
	local list = {}
	for _, other in TankCatalog.order do
		if defs[other].Parent == id then
			table.insert(list, other)
		end
	end
	return list
end

-- Mod ---------------------------------------------------------------------------------

function TankCatalog.isMod(id: unknown): boolean
	return type(id) == "string" and mods[id] ~= nil
end

function TankCatalog.mod(id: string): ModDef
	return mods[id] or { DisplayName = id, Blurb = "" }
end

-- The mod tree of tank `id`: Config.Mods.Rows rows of 2 mod ids.
function TankCatalog.modRows(id: string): { { string } }
	local rows = table.clone(commonRows)
	for _, row in TankCatalog.get(id).ModRows do
		table.insert(rows, row)
	end
	return rows
end

-- Which row of tank `id`'s tree holds mod `modId` (nil if it isn't in the tree).
function TankCatalog.rowOf(id: string, modId: string): number?
	for index, row in TankCatalog.modRows(id) do
		if table.find(row, modId) then
			return index
		end
	end
	return nil
end

function TankCatalog.encodeMods(list: { string }): string
	local kept = {}
	for _, modId in list do
		if mods[modId] then
			table.insert(kept, modId)
		end
	end
	return table.concat(kept, ",")
end

function TankCatalog.decodeMods(text: unknown): { string }
	local list = {}
	if type(text) == "string" then
		for _, modId in string.split(text, ",") do
			if mods[modId] then
				table.insert(list, modId)
			end
		end
	end
	return list
end

-- Stats --------------------------------------------------------------------------------

local function applyMods(spec: TankClass.Spec, m: Mods)
	spec.MaxHealth *= m.Health or 1
	spec.Damage *= m.Damage or 1
	spec.Cooldown *= m.Reload or 1
	local speed = m.Speed or 1
	spec.MaxForwardSpeed *= speed
	spec.MaxReverseSpeed *= speed
	spec.DriveAcceleration *= speed
	spec.TurnRate *= math.sqrt(speed) -- turning improves, but less than straight-line speed
	spec.TurretTraverseSpeed *= m.Turret or 1
	local armor = m.Armor or 1
	spec.FrontArmor *= armor
	spec.SideArmor *= armor
	spec.RearArmor *= armor
end

-- Effective stats of tank `id` with the given equipped mods.
function TankCatalog.spec(id: string, equipped: { string }?): TankClass.Spec
	local def = TankCatalog.get(id)
	local spec = table.clone(TankClass.get(def.Class))
	spec.DisplayName = def.DisplayName
	applyMods(spec, TankCatalog.line(def.Line).Mods)
	local scale = Config.TierScale[def.Tier] or 1
	applyMods(spec, { Health = scale, Damage = scale })
	applyMods(spec, def.Mods)
	local list: { string } = equipped or {}
	for _, modId in list do
		local stats = TankCatalog.mod(modId).Stats
		if stats and TankCatalog.rowOf(id, modId) then
			applyMods(spec, stats)
		end
	end
	spec.MaxHealth = math.round(spec.MaxHealth)
	return spec
end

-- Equipped mods stored on a tank model.
function TankCatalog.modsOfModel(model: Instance): { string }
	-- The toy line of a tank model ("Brick" | "Plush" | "Foam").
function TankCatalog.lineOfModel(model: Instance): string
	return TankCatalog.get(TankCatalog.normalize(model:GetAttribute(TankCatalog.IdAttribute))).Line
end

return TankCatalog.decodeMods(model:GetAttribute(TankCatalog.ModsAttribute))
end

-- Behavior mods equipped on a tank model (behavior name -> true).
function TankCatalog.behaviorsOfModel(model: Instance): { [string]: boolean }
	local out = {}
	for _, modId in TankCatalog.modsOfModel(model) do
		local behavior = TankCatalog.mod(modId).Behavior
		if behavior then
			out[behavior] = true
		end
	end
	return out
end

-- Effective stats of a live tank model, from its attributes.
function TankCatalog.ofModel(model: Instance): TankClass.Spec
	-- The toy line of a tank model ("Brick" | "Plush" | "Foam").
function TankCatalog.lineOfModel(model: Instance): string
	return TankCatalog.get(TankCatalog.normalize(model:GetAttribute(TankCatalog.IdAttribute))).Line
end

return TankCatalog.spec(TankCatalog.normalize(model:GetAttribute(TankCatalog.IdAttribute)), TankCatalog.modsOfModel(model))
end

-- The toy line of a tank model ("Brick" | "Plush" | "Foam").
function TankCatalog.lineOfModel(model: Instance): string
	return TankCatalog.get(TankCatalog.normalize(model:GetAttribute(TankCatalog.IdAttribute))).Line
end

return TankCatalog
