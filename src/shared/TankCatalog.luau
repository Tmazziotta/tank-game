--!strict
-- The ownable tanks (Config.Tanks) and their effective stats. A tank's stats are its
-- class's base stats x the tank's own Mods x its upgrade levels. Shared so the server
-- (spawning, combat) and the client (driving, garage UI) compute identical numbers.

local Config = require(script.Parent.Config)
local PlayerDataTypes = require(script.Parent.PlayerDataTypes)
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
	Class: string,
	Tier: number,
	DisplayName: string,
	Cost: number,
	Mods: Mods,
}

local TankCatalog = {}

-- Attributes on a tank model: which tank it is and its upgrade levels.
TankCatalog.IdAttribute = "TankId"
TankCatalog.UpgradeAttributes = { Gun = "GunLevel", Armor = "ArmorLevel", Engine = "EngineLevel" } :: { [string]: string }

TankCatalog.order = Config.TankOrder :: { string }
TankCatalog.trackOrder = Config.Upgrades.TrackOrder :: { string }

local defs: { [string]: TankDef } = Config.Tanks :: any
local tracks: { [string]: { DisplayName: string, PerLevel: Mods } } = Config.Upgrades.Tracks :: any

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

function TankCatalog.trackName(track: string): string
	local def = tracks[track]
	return if def then def.DisplayName else track
end

-- Tanks every player owns from the start (cost 0).
function TankCatalog.starters(): { string }
	local list = {}
	for _, id in TankCatalog.order do
		if defs[id].Cost <= 0 then
			table.insert(list, id)
		end
	end
	return list
end

function TankCatalog.noUpgrades(): PlayerDataTypes.UpgradeLevels
	return { Gun = 0, Armor = 0, Engine = 0 }
end

local function applyMods(spec: TankClass.Spec, mods: Mods, times: number)
	if times <= 0 then
		return
	end
	local function m(value: number?): number
		return (value or 1) ^ times
	end
	spec.MaxHealth *= m(mods.Health)
	spec.Damage *= m(mods.Damage)
	spec.Cooldown *= m(mods.Reload)
	local speed = m(mods.Speed)
	spec.MaxForwardSpeed *= speed
	spec.MaxReverseSpeed *= speed
	spec.DriveAcceleration *= speed
	spec.TurnRate *= math.sqrt(speed) -- turning improves, but less than straight-line speed
	spec.TurretTraverseSpeed *= m(mods.Turret)
	local armor = m(mods.Armor)
	spec.FrontArmor *= armor
	spec.SideArmor *= armor
	spec.RearArmor *= armor
end

-- Effective stats of tank `id` with the given upgrade levels.
function TankCatalog.spec(id: string, upgrades: PlayerDataTypes.UpgradeLevels?): TankClass.Spec
	local def = TankCatalog.get(id)
	local spec = table.clone(TankClass.get(def.Class))
	spec.DisplayName = def.DisplayName
	applyMods(spec, def.Mods, 1)
	if upgrades then
		for _, track in TankCatalog.trackOrder do
			local trackDef = tracks[track]
			local level = (upgrades :: any)[track]
			if trackDef and type(level) == "number" then
				applyMods(spec, trackDef.PerLevel, level)
			end
		end
	end
	spec.MaxHealth = math.round(spec.MaxHealth)
	return spec
end

-- Upgrade levels stored on a tank model.
function TankCatalog.upgradesOfModel(model: Instance): PlayerDataTypes.UpgradeLevels
	local levels = TankCatalog.noUpgrades()
	for track, attribute in TankCatalog.UpgradeAttributes do
		local value = model:GetAttribute(attribute)
		if type(value) == "number" then
			(levels :: any)[track] = value
		end
	end
	return levels
end

-- Effective stats of a live tank model, from its attributes.
function TankCatalog.ofModel(model: Instance): TankClass.Spec
	return TankCatalog.spec(TankCatalog.normalize(model:GetAttribute(TankCatalog.IdAttribute)), TankCatalog.upgradesOfModel(model))
end

return TankCatalog
