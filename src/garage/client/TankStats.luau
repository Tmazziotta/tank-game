--!strict
-- Tank stats as pip counts for the garage cards: firepower (damage per second), armor
-- (effective front HP) and speed, each scored against the best fully-upgraded tank in the
-- catalog so upgrades visibly add pips.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankClass = require(ReplicatedStorage.Shared.TankClass)

export type Stat = { label: string, value: (TankClass.Spec) -> number }

local TankStats = {}

TankStats.list = {
	{
		label = "Firepower",
		value = function(spec: TankClass.Spec): number
			return spec.Damage / spec.Cooldown
		end,
	},
	{
		label = "Armor",
		value = function(spec: TankClass.Spec): number
			return spec.MaxHealth / spec.FrontArmor
		end,
	},
	{
		label = "Speed",
		value = function(spec: TankClass.Spec): number
			return spec.MaxForwardSpeed
		end,
	},
} :: { Stat }

local best: { number } = {}
do
	local maxed: PlayerDataTypes.UpgradeLevels =
		{ Gun = Config.Upgrades.MaxLevel, Armor = Config.Upgrades.MaxLevel, Engine = Config.Upgrades.MaxLevel }
	for index, stat in TankStats.list do
		local top = 0
		for _, id in TankCatalog.order do
			top = math.max(top, stat.value(TankCatalog.spec(id, maxed)))
		end
		best[index] = top
	end
end

-- Pips (1..Config.Garage.StatPips) for each stat of `tankId` with `upgrades`.
function TankStats.pips(tankId: string, upgrades: PlayerDataTypes.UpgradeLevels?): { number }
	local spec = TankCatalog.spec(tankId, upgrades)
	local out = {}
	for index, stat in TankStats.list do
		local fraction = stat.value(spec) / best[index]
		out[index] = math.clamp(math.ceil(fraction * Config.Garage.StatPips), 1, Config.Garage.StatPips)
	end
	return out
end

return TankStats
