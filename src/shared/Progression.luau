--!strict
-- Level and price math (pure). Shared so the garage UI shows exactly what the server enforces.

local Config = require(script.Parent.Config)
local TankCatalog = require(script.Parent.TankCatalog)

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

function Progression.levelForTier(tier: number): number
	return Config.Progression.TierLevel[tier] or math.huge
end

-- Coins for the next level of `track` on tank `id`, or nil if already maxed.
function Progression.upgradeCost(id: string, currentLevel: number): number?
	local cfg = Config.Upgrades
	if currentLevel >= cfg.MaxLevel then
		return nil
	end
	local tier = TankCatalog.get(id).Tier
	return math.round(cfg.Costs[currentLevel + 1] * (cfg.TierCostFactor[tier] or 1))
end

return Progression
