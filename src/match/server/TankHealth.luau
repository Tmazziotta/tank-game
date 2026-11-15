--!strict
-- Hit points, spawn protection and last attacker for every live tank, keyed by tank
-- model. Health and protection are mirrored to model attributes for clients to draw.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combatant = require(script.Parent.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local TankSchema = require(ReplicatedStorage.Shared.TankSchema)

export type DepletedHandler = (model: Model, killer: Combatant.Combatant?) -> ()

type State = {
	health: number,
	protectedUntil: number,
	lastAttacker: Combatant.Combatant?,
	lastAttackedAt: number,
	depleted: boolean,
	engaged: boolean, -- has fired or taken damage since spawning
}

local TankHealth = {}

local states: { [Model]: State } = {}
local enabled = true
local depletedHandler: DepletedHandler? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

function TankHealth.register(model: Model, maxHealth: number, protection: number)
	local protectedUntil = now() + protection
	states[model] = {
		health = maxHealth,
		protectedUntil = protectedUntil,
		lastAttacker = nil,
		lastAttackedAt = -math.huge,
		depleted = false,
		engaged = false,
	}
	model:SetAttribute(TankSchema.MaxHealthAttribute, maxHealth)
	model:SetAttribute(TankSchema.HealthAttribute, maxHealth)
	model:SetAttribute(TankSchema.ProtectedUntilAttribute, protectedUntil)
end

function TankHealth.unregister(model: Model)
	states[model] = nil
end

-- The registered tank model that `instance` belongs to, if any.
function TankHealth.findTank(instance: Instance): Model?
	local node: Instance? = instance
	while node do
		if node:IsA("Model") and states[node] then
			return node
		end
		node = node.Parent
	end
	return nil
end

function TankHealth.isProtected(model: Model): boolean
	local state = states[model]
	return state ~= nil and now() < state.protectedUntil
end

function TankHealth.endProtection(model: Model)
	local state = states[model]
	if state and now() < state.protectedUntil then
		state.protectedUntil = 0
		model:SetAttribute(TankSchema.ProtectedUntilAttribute, 0)
	end
end

-- The tank has fired: it is now in the fight (see isEngaged).
function TankHealth.markEngaged(model: Model)
	local state = states[model]
	if state then
		state.engaged = true
	end
end

-- Whether the tank has fired or taken damage since it spawned. An unengaged tank can be
-- swapped for another class at no cost.
function TankHealth.isEngaged(model: Model): boolean
	local state = states[model]
	return state ~= nil and state.engaged
end

-- Globally switch damage on/off (off between rounds).
function TankHealth.setEnabled(on: boolean)
	enabled = on
end

-- Called (deferred, once per tank) when a tank's health reaches zero.
function TankHealth.isEnabled(): boolean
	return enabled
end

function TankHealth.onDepleted(handler: DepletedHandler)
	depletedHandler = handler
end

-- Who gets credit if this tank dies now: its last attacker, if recent enough.
function TankHealth.killerOf(model: Model): Combatant.Combatant?
	local state = states[model]
	if state and now() - state.lastAttackedAt <= Config.Combat.KillCreditWindow then
		return state.lastAttacker
	end
	return nil
end

-- Applies damage and returns how much was dealt (0 if protected, disabled or dead).
function TankHealth.damage(model: Model, amount: number, attacker: Combatant.Combatant?): number
	local state = states[model]
	if not enabled or not state or state.depleted or amount <= 0 or now() < state.protectedUntil then
		return 0
	end
	local dealt = math.min(amount, state.health)
	state.health -= dealt
	state.engaged = true
	if attacker then
		state.lastAttacker = attacker
		state.lastAttackedAt = now()
	end
	model:SetAttribute(TankSchema.HealthAttribute, state.health)
	if state.health <= 0 then
		state.depleted = true
		local handler = depletedHandler
		if handler then
			-- Deferred so the shot that did this is reported before the explosion.
			task.defer(handler, model, attacker)
		end
	end
	return dealt
end

return TankHealth
