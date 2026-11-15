--!strict
-- Garage client bootstrap: the desk scene and lobby HUD. Runs on the Garage place, and
-- alongside the Match client in dev mode (see Places).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Places = require(ReplicatedStorage.Shared.Places)
if not Places.runsGarage() then
	return
end

local GarageCamera = require(script.GarageCamera)
local GarageGate = require(script.GarageGate)
local GarageScene = require(script.GarageScene)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Turntable = require(script.Turntable)

local scene = GarageScene.build()
Turntable.start(scene)

local function showSelected()
	local data = ProfileClient.get()
	if data then
		Turntable.show(data.SelectedTank, data.Upgrades[data.SelectedTank])
	end
end

local function onLocation(inGarage: boolean)
	GarageCamera.setActive(inGarage, scene.center)
	Turntable.setEnabled(inGarage)
	if inGarage then
		showSelected()
	end
end

GarageGate.start()
GarageGate.changed:Connect(onLocation)
ProfileClient.changed:Connect(showSelected)
ProfileClient.start()
onLocation(GarageGate.active())
