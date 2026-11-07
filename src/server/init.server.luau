--!strict
-- Server bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DebrisService = require(script.DebrisService)
local Destruction = require(script.Destruction)
local MapService = require(script.MapService)
local TankService = require(script.TankService)
local WeaponService = require(script.WeaponService)

MapService.RoundReset()
TankService.start()

WeaponService.start(function(position: Vector3, _shooter: Player)
	local roots: { Instance } = { DebrisService.getFolder() }
	local buildings = MapService.getBuildingsFolder()
	if buildings then
		table.insert(roots, buildings)
	end
	Destruction.blast(position, Config.Weapon.BlastRadius, roots)
end)
