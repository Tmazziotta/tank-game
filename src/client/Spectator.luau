--!strict
-- While you have no tank (destroyed, or joined mid-round), the camera follows a living
-- teammate's tank - or anyone's, once your team is wiped out. E cycles between them.
-- Hands the camera back the moment your own tank arrives.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local TankCamera = require(script.Parent.TankCamera)
local TankController = require(script.Parent.TankController)
local TankDrive = require(ReplicatedStorage.Shared.TankDrive)
local TankSchema = require(ReplicatedStorage.Shared.TankSchema)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)

local Spectator = {}

local localPlayer = Players.LocalPlayer
local watching: Model? = nil
local cycle = 0

local function myTeamName(): string?
	local team = localPlayer.Team
	if not team then
		return nil
	end
	for _, name in TeamInfo.order do
		local info = TeamInfo.get(name)
		if info and info.DisplayName == team.Name then
			return name
		end
	end
	return nil
end

-- Live tanks worth watching: teammates first; everyone if no teammate is left.
local function candidates(): { Model }
	local folder = workspace:FindFirstChild(TankSchema.TanksFolder)
	if not folder then
		return {}
	end
	local mine = myTeamName()
	local allies, all = {}, {}
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:FindFirstChild(TankSchema.Hull) then
			table.insert(all, model)
			if mine and model:GetAttribute(TeamInfo.Attribute) == mine then
				table.insert(allies, model)
			end
		end
	end
	return if #allies > 0 then allies else all
end

local function watch(model: Model?)
	if model == watching then
		return
	end
	watching = model
	if model then
		local refs = TankDrive.resolve(model)
		if refs then
			TankCamera.bind(refs)
			return
		end
		watching = nil
	end
	TankCamera.unbind()
end

local function update()
	if TankController.getTank() then
		watching = nil -- TankController owns the camera now
		return
	end
	if watching and watching.Parent and watching.Parent.Name == TankSchema.TanksFolder then
		return
	end
	local list = candidates()
	watch(if #list > 0 then list[cycle % #list + 1] else nil)
end

function Spectator.start()
	RunService.RenderStepped:Connect(update)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.E and watching then
			cycle += 1
			local list = candidates()
			if #list > 0 then
				watch(list[cycle % #list + 1])
			end
		end
	end)
end

return Spectator
