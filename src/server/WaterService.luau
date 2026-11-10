--!strict
-- Deep water: a tank whose hull is over a DeepWater zone sinks and is destroyed. Whoever
-- last damaged it (within the kill-credit window) gets the kill, so shoving or chasing
-- someone into the river counts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Surfaces = require(ReplicatedStorage.Shared.Surfaces)
local TankHealth = require(script.Parent.TankHealth)
local TankService = require(script.Parent.TankService)

local WaterService = {}

local function check()
	if not TankHealth.isEnabled() then
		return
	end
	for _, entry in TankService.liveTanks() do
		local hull = entry.tank.hull
		local under = Surfaces.ground(hull.Position, Config.Surfaces.ProbeDepth)
		if under and under.Instance:GetAttribute(Surfaces.HazardAttribute) == "DeepWater" then
			local model = entry.tank.model
			TankHealth.endProtection(model)
			if TankHealth.damage(model, math.huge, TankHealth.killerOf(model)) > 0 then
				Remotes.HazardEvent:FireAllClients("Sink", hull.Position)
			end
		end
	end
end

function WaterService.start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= Config.Hazards.WaterCheckInterval then
			elapsed = 0
			check()
		end
	end)
end

return WaterService
