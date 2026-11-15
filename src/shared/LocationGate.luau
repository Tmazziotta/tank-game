--!strict
-- Client: shows one half of the game (Garage or Match) only while the local player is
-- there (see Location). GUIs mount through a gate: parented to PlayerGui while active and
-- unparented otherwise, so modules can keep toggling Enabled without caring where the
-- player is. `changed` fires (active: boolean) when the player arrives or leaves.

local Players = game:GetService("Players")

local Location = require(script.Parent.Location)

export type Gate = {
	active: () -> boolean,
	mount: (ScreenGui) -> (),
	changed: RBXScriptSignal,
	start: () -> (),
}

local LocationGate = {}

function LocationGate.new(place: Location.Place): Gate
	local localPlayer = Players.LocalPlayer
	local mounted: { ScreenGui } = {}
	local changedEvent = Instance.new("BindableEvent")
	local started = false

	local function active(): boolean
		return Location.get(localPlayer) == place
	end

	local function placeGui(gui: ScreenGui)
		gui.Parent = if active() then localPlayer:WaitForChild("PlayerGui") else nil
	end

	local function mount(gui: ScreenGui)
		table.insert(mounted, gui)
		placeGui(gui)
	end

	local function start()
		if started then
			return
		end
		started = true
		Location.changed(localPlayer):Connect(function()
			for _, gui in mounted do
				placeGui(gui)
			end
			changedEvent:Fire(active())
		end)
	end

	return {
		active = active,
		mount = mount,
		changed = changedEvent.Event,
		start = start,
	}
end

return LocationGate
