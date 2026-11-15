--!strict
-- Garage requests to the server (Remotes.GarageRequest -> Hangar), one at a time. A refusal
-- is shown as a toast. The server validates everything; this is just the client's door.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Requests = {}

local busy = false
local toast: (string) -> () = function(_message: string) end

function Requests.setToast(fn: (string) -> ())
	toast = fn
end

-- Send `action` (e.g. "Buy", "UnlockMod"); yields. Returns whether it worked.
function Requests.send(action: string, id: string, extra: string?): boolean
	if busy then
		return false
	end
	busy = true
	local ok, message = Remotes.GarageRequest:InvokeServer(action, id, extra)
	busy = false
	if not ok then
		toast(`Can't do that: {message or "unknown error"}`)
	end
	return ok == true
end

return Requests
