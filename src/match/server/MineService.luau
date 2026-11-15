--!strict
-- Minefields. A tank driving over a mine sets it off: heavy damage nearby (any team), a
-- blast that breaks walls and props, and any other mine in the blast goes off a moment
-- later. Shells and explosions set mines off too, so players can clear a path (and whoever
-- cleared it gets credit for enemies caught in the blast).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combatant = require(script.Parent.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local MapSchema = require(ReplicatedStorage.Shared.MapSchema)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankHealth = require(script.Parent.TankHealth)
local TankService = require(script.Parent.TankService)

export type BlastHandler = (position: Vector3, radius: number) -> ()

local MineService = {}

local onBlast: BlastHandler? = nil

local function mines(): { BasePart }
	local list = {}
	local map = workspace:FindFirstChild(MapSchema.MapFolder)
	local fields = map and map:FindFirstChild(MapSchema.MinefieldsFolder)
	if fields then
		for _, part in fields:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute(MapSchema.MineAttribute) then
				table.insert(list, part)
			end
		end
	end
	return list
end

local detonate: (mine: BasePart, cause: Combatant.Combatant?) -> ()

-- Set off every mine within `radius` of `position` (after a short chain delay).
local function chain(position: Vector3, radius: number, cause: Combatant.Combatant?)
	for _, mine in mines() do
		if (mine.Position - position).Magnitude <= radius and not mine:GetAttribute("Triggered") then
			mine:SetAttribute("Triggered", true)
			task.delay(Config.Hazards.MineChainDelay, detonate, mine, cause)
		end
	end
end

function detonate(mine: BasePart, cause: Combatant.Combatant?)
	if not mine.Parent then
		return -- map rebuilt meanwhile
	end
	local cfg = Config.Hazards
	local position = mine.Position
	mine:Destroy()
	Remotes.HazardEvent:FireAllClients("Mine", position)
	for _, entry in TankService.liveTanks() do
		local distance = (entry.tank.hull.Position - position).Magnitude
		if distance <= cfg.MineBlastRadius then
			local damage = cfg.MineDamage * (1 - 0.5 * distance / cfg.MineBlastRadius)
			-- Credit the player who set it off, unless they caught a teammate.
			local credit = if cause and cause.team ~= entry.combatant.team then cause else nil
			TankHealth.damage(entry.tank.model, damage, credit)
		end
	end
	local handler = onBlast
	if handler then
		handler(position, cfg.MineBlastRadius * 0.6)
	end
	chain(position, cfg.MineChainRadius, cause)
end

-- An explosion elsewhere (shell impact, tank wreck) sets off mines it reaches.
function MineService.blast(position: Vector3, radius: number, cause: Combatant.Combatant?)
	chain(position, radius + 1.5, cause)
end

local function checkTriggers()
	if not TankHealth.isEnabled() then
		return
	end
	local live = TankService.liveTanks()
	if #live == 0 then
		return
	end
	local r = Config.Hazards.MineTriggerRadius
	for _, mine in mines() do
		if not mine:GetAttribute("Triggered") then
			local p = mine.Position
			for _, entry in live do
				local h = entry.tank.hull.Position
				if math.abs(h.Y - p.Y) < 8 and Vector2.new(h.X - p.X, h.Z - p.Z).Magnitude <= r then
					mine:SetAttribute("Triggered", true)
					detonate(mine, nil)
					break
				end
			end
		end
	end
end

function MineService.start(blastHandler: BlastHandler)
	onBlast = blastHandler
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= Config.Hazards.MineCheckInterval then
			elapsed = 0
			checkTriggers()
		end
	end)
end

return MineService
