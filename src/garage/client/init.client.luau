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
local LobbyHud = require(script.LobbyHud)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
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
		LobbyHud.setPlayBusy(false)
		showSelected()
	end
end

LobbyHud.onPlay(function()
	LobbyHud.setPlayBusy(true, "STARTING...")
	local ok, message = Remotes.PlayRequest:InvokeServer()
	if not ok then
		LobbyHud.setPlayBusy(false)
		LobbyHud.toast(message or "Couldn't start the match")
	end
	-- On success the player leaves the Garage (dev mode) or is teleported (live); the
	-- button resets when they come back.
end)

GarageGate.start()
GarageGate.mount(LobbyHud.gui())
LobbyHud.start()
Remotes.Toast.OnClientEvent:Connect(function(message: string, kind: string?)
	LobbyHud.toast(message)
	if kind == "PlayFailed" then
		LobbyHud.setPlayBusy(false)
	end
end)
GarageGate.changed:Connect(onLocation)
ProfileClient.changed:Connect(showSelected)
ProfileClient.start()
onLocation(GarageGate.active())
