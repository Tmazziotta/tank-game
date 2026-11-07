--!strict
-- Tank lifecycle: one tank per player, spawned with their character, player seated as
-- driver and given network ownership of the tank so driving is responsive.

local Players = game:GetService("Players")

local MapLayout = require(script.Parent.MapLayout)
local TankBuilder = require(script.Parent.TankBuilder)
local TankSchema = require(game:GetService("ReplicatedStorage").Shared.TankSchema)

local TankService = {}

local BODY_COLORS = {
	Color3.fromRGB(90, 200, 120), -- mint
	Color3.fromRGB(255, 120, 110), -- coral
	Color3.fromRGB(100, 160, 255), -- sky
	Color3.fromRGB(255, 200, 70), -- sunflower
	Color3.fromRGB(190, 120, 255), -- grape
}

local tanks: { [Player]: TankBuilder.Tank } = {}
local spawnCursor = 0

local function tanksFolder(): Folder
	local existing = workspace:FindFirstChild("Tanks")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Tanks"
	folder.Parent = workspace
	return folder
end

local function nextSpawn(): CFrame
	spawnCursor = spawnCursor % #MapLayout.SpawnPoints + 1
	return MapLayout.SpawnPoints[spawnCursor]
end

local function colorFor(player: Player): Color3
	return BODY_COLORS[player.UserId % #BODY_COLORS + 1]
end

local function despawn(player: Player)
	local tank = tanks[player]
	if tank then
		tanks[player] = nil
		tank.model:Destroy()
	end
end

local function giveOwnership(tank: TankBuilder.Tank, player: Player)
	for _, part in { tank.hull, tank.turret, tank.barrel } do
		if part:CanSetNetworkOwnership() then
			part:SetNetworkOwner(player)
		end
	end
end

-- Seat with retries: Sit can silently fail if called the instant a character spawns.
local function seatDriver(tank: TankBuilder.Tank, humanoid: Humanoid): boolean
	for _ = 1, 10 do
		if tank.seat.Occupant == humanoid then
			return true
		end
		if humanoid.Health <= 0 or not tank.model.Parent then
			return false
		end
		tank.seat:Sit(humanoid)
		task.wait(0.2)
	end
	return tank.seat.Occupant == humanoid
end

local function spawnTank(player: Player, character: Model)
	despawn(player)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:WaitForChild("HumanoidRootPart")
	-- No jumping: jumping is how a seated humanoid leaves its seat.
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0

	local tank = TankBuilder.build(nextSpawn(), colorFor(player))
	tank.model.Name = "Tank_" .. player.Name
	tank.model:SetAttribute(TankSchema.OwnerAttribute, player.UserId)
	tank.model.Parent = tanksFolder()
	tanks[player] = tank

	if not seatDriver(tank, humanoid) then
		warn(`[TankService] could not seat {player.Name}`)
	end
	TankBuilder.sizeForces(tank)
	giveOwnership(tank, player)

	-- If the driver gets knocked out of the seat, put them back.
	tank.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if tank.seat.Occupant == nil and tanks[player] == tank and humanoid.Health > 0 then
			task.delay(0.3, function()
				if tanks[player] == tank and humanoid.Health > 0 and seatDriver(tank, humanoid) then
					giveOwnership(tank, player)
				end
			end)
		end
	end)

	humanoid.Died:Connect(function()
		task.delay(1, function()
			if tanks[player] == tank then
				despawn(player)
			end
		end)
	end)
end

function TankService.getTank(player: Player): TankBuilder.Tank?
	return tanks[player]
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		spawnTank(player, character)
	end)
	if player.Character then
		task.spawn(spawnTank, player, player.Character)
	end
end

function TankService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(despawn)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return TankService
