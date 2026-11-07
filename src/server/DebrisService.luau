--!strict
-- Owns loose debris: fades and deletes each piece after a lifetime, and caps the total
-- count so physics stays cheap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local DebrisService = {}

local FOLDER_NAME = "Debris"

-- Oldest first. Entries may already be destroyed (e.g. by a round reset).
local live: { BasePart } = {}
local tracked: { [BasePart]: boolean } = {}

-- Looked up each call so a reset from any context can't leave a stale reference.
function DebrisService.getFolder(): Folder
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	return folder
end

local function forget(part: BasePart)
	if not tracked[part] then
		return
	end
	tracked[part] = nil
	local index = table.find(live, part)
	if index then
		table.remove(live, index)
	end
end

local function expire(part: BasePart, fadeTime: number)
	forget(part)
	if not part.Parent then
		return
	end
	if fadeTime <= 0 then
		part:Destroy()
		return
	end
	local tween = TweenService:Create(part, TweenInfo.new(fadeTime), { Transparency = 1 })
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

-- Hand a detached part to the debris system.
function DebrisService.add(part: BasePart)
	if tracked[part] then
		return
	end
	tracked[part] = true
	table.insert(live, part)
	part.Parent = DebrisService.getFolder()

	task.delay(Config.Destruction.DebrisLifetime, function()
		if tracked[part] then
			expire(part, Config.Destruction.DebrisFadeTime)
		end
	end)

	while #live > Config.Destruction.MaxDebris do
		expire(live[1], 0)
	end
end

function DebrisService.count(): number
	return #live
end

function DebrisService.clear()
	for _, part in live do
		part:Destroy()
	end
	table.clear(live)
	table.clear(tracked)
	local folder = workspace:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
end

return DebrisService
