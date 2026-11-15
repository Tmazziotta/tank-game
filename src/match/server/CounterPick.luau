--!strict
--!nolint DeprecatedApi
-- (LoadCharacter is flagged in favour of LoadCharacterAsync, which our type definitions
-- don't declare yet.)
-- Counter-pick: when a player changes tanks mid-match (Hangar validates the request), the
-- new choice applies at the next round's spawn - immediately during the pre-round
-- countdown, by respawning them into it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Hangar = require(ServerScriptService.Core.Hangar)
local MatchRoster = require(script.Parent.MatchRoster)
local PlayerData = require(ServerScriptService.Core.PlayerData)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankService = require(script.Parent.TankService)

local CounterPick = {}

local lastRespawn: { [Player]: number } = {}

local function canRespawnNow(player: Player): boolean
	local tank = TankService.getTank(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tank or not humanoid or humanoid.Health <= 0 then
		return false -- dead: the choice simply applies at the respawn
	end
	local last = lastRespawn[player]
	if last and os.clock() - last < Config.Combat.TankSwitchCooldown then
		return false
	end
	-- Swaps are free during the countdown (or with no match running); once a round is on,
	-- the choice waits for the next round.
	local phase = ReplicatedStorage:GetAttribute(RoundSchema.PhaseAttribute)
	return phase == "PreRound" or phase == "Waiting"
end

-- Respawn into the saved choice if the live tank no longer matches it and that's free.
local function refreshTank(player: Player)
	local data = PlayerData.get(player)
	local tank = TankService.getTank(player)
	if not data or not tank then
		return
	end
	local wanted = PlayerData.upgradesFor(data, data.SelectedTank)
	local current = TankCatalog.upgradesOfModel(tank.model)
	local same = tank.tankId == data.SelectedTank
	for _, track in TankCatalog.trackOrder do
		if (wanted :: any)[track] ~= (current :: any)[track] then
			same = false
		end
	end
	if not same and canRespawnNow(player) then
		lastRespawn[player] = os.clock()
		task.spawn(player.LoadCharacter, player)
	end
end

function CounterPick.start()
	Players.PlayerRemoving:Connect(function(player)
		lastRespawn[player] = nil
	end)
	Hangar.onChanged(function(player)
		if MatchRoster.has(player) then
			refreshTank(player)
		end
	end)
	Hangar.start()
end

return CounterPick
