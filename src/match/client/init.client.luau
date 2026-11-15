--!strict
-- Match client bootstrap: tank controls, combat HUDs and effects. Runs on the Match place,
-- and alongside the Garage client in dev mode (see Places).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Places = require(ReplicatedStorage.Shared.Places)
if not Places.runsMatch() then
	return
end

local GarageMenu = require(script.GarageMenu)
local HazardEffects = require(script.HazardEffects)
local ProfileClient = require(script.ProfileClient)
local ProgressHud = require(script.ProgressHud)
local RoundHud = require(script.RoundHud)
local Scope = require(script.Scope)
local Spectator = require(script.Spectator)
local TankController = require(script.TankController)
local TankOverlays = require(script.TankOverlays)
local TouchControls = require(script.TouchControls)
local WeaponClient = require(script.WeaponClient)

ProfileClient.start()
TankController.start()
WeaponClient.start()
RoundHud.start()
HazardEffects.start()
Spectator.start()
Scope.start()
task.spawn(ProgressHud.start)
task.spawn(GarageMenu.start)
task.spawn(TouchControls.start)
task.spawn(TankOverlays.start)
