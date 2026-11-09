--!strict
-- Typed access to the tank classes defined in Config.Classes.

local Config = require(script.Parent.Config)

export type Trim = "None" | "Antenna" | "Skirts"

export type Spec = {
	DisplayName: string,
	Role: string,
	MaxHealth: number,
	FrontArmor: number,
	SideArmor: number,
	RearArmor: number,
	MaxForwardSpeed: number,
	MaxReverseSpeed: number,
	DriveAcceleration: number,
	TurnRate: number,
	TurretTraverseSpeed: number,
	Damage: number,
	Cooldown: number,
	BlastRadius: number,
	Scale: number,
	BarrelLength: number,
	BarrelWidth: number,
	Trim: string,
}

local TankClass = {}

-- Attribute holding the class name: on a tank model (what it is) and on a Player (what
-- they picked for their next spawn).
TankClass.Attribute = "TankClass"

-- Class names in menu order.
TankClass.order = Config.ClassOrder :: { string }

local classes = Config.Classes :: { [string]: Spec }

function TankClass.isValid(name: unknown): boolean
	return type(name) == "string" and classes[name] ~= nil
end

-- The named class, or the default class for anything unknown.
function TankClass.get(name: unknown): Spec
	if type(name) == "string" and classes[name] then
		return classes[name]
	end
	return classes[Config.DefaultClass]
end

-- Validated class name (falls back to the default).
function TankClass.normalize(name: unknown): string
	return if TankClass.isValid(name) then name :: string else Config.DefaultClass
end

-- Class of a tank model, from its attribute.
function TankClass.ofModel(model: Instance): Spec
	return TankClass.get(model:GetAttribute(TankClass.Attribute))
end

return TankClass
