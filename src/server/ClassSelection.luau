--!strict
--!nolint DeprecatedApi
-- (LoadCharacter is flagged in favour of LoadCharacterAsync, which our type definitions
-- don't declare yet.)
-- Tank class choice. A player's pick is stored as a Player attribute and used for their
-- next spawn. If switching costs nothing (outside an active round, or their current tank
-- hasn't fired or been hit yet) they respawn in the new class immediately.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local TankClass = require(ReplicatedStorage.Shared.TankClass)
local TankHealth = require(script.Parent.TankHealth)
local TankService = require(script.Parent.TankService)

local ClassSelection = {}

local lastRespawn: { [Player]: number } = {}

local function canSwitchNow(player: Player): boolean
	local tank = TankService.getTank(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tank or not humanoid or humanoid.Health <= 0 then
		return false -- dead: the choice simply applies at the respawn
	end
	local last = lastRespawn[player]
	if last and os.clock() - last < Config.Combat.ClassSwitchCooldown then
		return false
	end
	local active = ReplicatedStorage:GetAttribute(RoundSchema.PhaseAttribute) == "Active"
	return not active or not TankHealth.isEngaged(tank.model)
end

local function onSelect(player: Player, name: unknown)
	if not TankClass.isValid(name) then
		return
	end
	local className = name :: string
	player:SetAttribute(TankClass.Attribute, className)
	local tank = TankService.getTank(player)
	if tank and tank.className ~= className and canSwitchNow(player) then
		lastRespawn[player] = os.clock()
		task.spawn(player.LoadCharacter, player)
	end
end

function ClassSelection.start()
	local function setup(player: Player)
		if not TankClass.isValid(player:GetAttribute(TankClass.Attribute)) then
			player:SetAttribute(TankClass.Attribute, Config.DefaultClass)
		end
	end
	-- Runs before TankService.start so the attribute exists before the first spawn.
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRespawn[player] = nil
	end)
	Remotes.SelectClass.OnServerEvent:Connect(onSelect)
end

return ClassSelection
