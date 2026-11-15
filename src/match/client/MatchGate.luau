--!strict
-- Shows the match client only while this player is in a match (Location "Match"). Match
-- GUIs mount through here: they're parented to PlayerGui in a match and unparented in the
-- garage, so modules can keep toggling Enabled without caring where the player is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Location = require(ReplicatedStorage.Shared.Location)

local MatchGate = {}

local localPlayer = Players.LocalPlayer
local mounted: { ScreenGui } = {}
local changedEvent = Instance.new("BindableEvent")

-- Fires (inMatch: boolean) when the player enters or leaves a match.
MatchGate.changed = changedEvent.Event

function MatchGate.inMatch(): boolean
	return Location.get(localPlayer) == "Match"
end

local function place(gui: ScreenGui)
	gui.Parent = if MatchGate.inMatch() then localPlayer:WaitForChild("PlayerGui") else nil
end

-- Parent `gui` to PlayerGui whenever the player is in a match.
function MatchGate.mount(gui: ScreenGui)
	table.insert(mounted, gui)
	place(gui)
end

function MatchGate.start()
	Location.changed(localPlayer):Connect(function()
		for _, gui in mounted do
			place(gui)
		end
		changedEvent:Fire(MatchGate.inMatch())
	end)
end

return MatchGate
