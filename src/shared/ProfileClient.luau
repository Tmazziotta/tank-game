--!strict
-- Client: the local player's saved data as last sent by the server (read-only mirror).
-- Shared so the Garage and Match clients both use it; start() is safe to call from both.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ProfileClient = {}

local data: PlayerDataTypes.Data? = nil
local changed = Instance.new("BindableEvent")

-- nil until the server's first sync arrives.
function ProfileClient.get(): PlayerDataTypes.Data?
	return data
end

-- Fires with the new data on every sync.
ProfileClient.changed = changed.Event

local started = false

function ProfileClient.start()
	if started then
		return
	end
	started = true
	Remotes.ProfileSync.OnClientEvent:Connect(function(newData: PlayerDataTypes.Data)
		data = newData
		changed:Fire(newData)
	end)
	Remotes.ProfileRequest:FireServer()
end

return ProfileClient
