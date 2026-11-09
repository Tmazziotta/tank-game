--!strict
-- Tank class picker: three cards (Light / Medium / Heavy) with stat bars. Opens on join
-- and when your tank is destroyed; C toggles it, 1/2/3 or a click picks. The server
-- decides whether the switch happens now or at your next respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local TankClass = require(ReplicatedStorage.Shared.TankClass)
local MouseLock = require(script.Parent.MouseLock)
local TankController = require(script.Parent.TankController)

local ClassPicker = {}

local CARD_WIDTH = 220
local CARD_HEIGHT = 250
local GAP = 16
local GOLD = Color3.fromRGB(255, 215, 90)
local CARD_COLOR = Color3.fromRGB(28, 30, 42)
local BAR_COLOR = Color3.fromRGB(120, 200, 255)
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

local localPlayer = Players.LocalPlayer

type Stat = { label: string, value: (TankClass.Spec) -> number }

-- Bars are relative to the best class on each stat.
local STATS: { Stat } = {
	{
		label = "Armor",
		value = function(spec)
			return spec.MaxHealth / spec.FrontArmor -- effective front HP
		end,
	},
	{
		label = "Speed",
		value = function(spec)
			return spec.MaxForwardSpeed
		end,
	},
	{
		label = "Damage",
		value = function(spec)
			return spec.Damage
		end,
	},
	{
		label = "Reload",
		value = function(spec)
			return 1 / spec.Cooldown
		end,
	},
}

local gui = Instance.new("ScreenGui")
gui.Name = "ClassPicker"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Enabled = false

local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.6) -- below the death banner
root.Size = UDim2.fromOffset(CARD_WIDTH * 3 + GAP * 2, CARD_HEIGHT + 90)
root.BackgroundTransparency = 1
root.Parent = gui

local function text(parent: Instance, value: string, size: number, position: UDim2, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Position = position
	label.Size = UDim2.new(1, 0, 0, height)
	label.Text = value
	label.Parent = parent
	return label
end

text(root, "CHOOSE YOUR TANK", 32, UDim2.fromOffset(0, 0), 36)
local footer = text(root, "", 18, UDim2.new(0, 0, 1, -24), 24)

local cards: { [string]: { stroke: UIStroke } } = {}
local autoOpened = false
local lastTank: TankController.TankRefs? = nil
local pending: string? = nil -- picked locally, not yet reflected in the attribute

local function chosenClass(): string
	return pending or TankClass.normalize(localPlayer:GetAttribute(TankClass.Attribute))
end

local function refresh()
	local chosen = chosenClass()
	for name, card in cards do
		local selected = name == chosen
		card.stroke.Color = if selected then GOLD else Color3.fromRGB(70, 74, 96)
		card.stroke.Thickness = if selected then 4 else 2
	end
	local phase = ReplicatedStorage:GetAttribute(RoundSchema.PhaseAttribute)
	footer.Text = if phase == "Active"
		then "Switches now if your tank hasn't fired or been hit; otherwise on respawn.   [C] close"
		else "Switches now (not in a round).   [C] close"
end

local function open(auto: boolean)
	autoOpened = auto
	gui.Enabled = true
	MouseLock.setReleased(true)
	refresh()
end

local function close()
	autoOpened = false
	gui.Enabled = false
	MouseLock.setReleased(false)
end

local function pick(name: string)
	pending = name
	Remotes.SelectClass:FireServer(name)
	refresh()
	-- Alive: back to the fight. Dead: keep showing the choice until the respawn.
	if TankController.getTank() then
		close()
	end
end

local function makeCard(index: number, name: string)
	local spec = TankClass.get(name)
	local card = Instance.new("TextButton")
	card.Name = name
	card.AutoButtonColor = false
	card.Text = ""
	card.BackgroundColor3 = CARD_COLOR
	card.BackgroundTransparency = 0.1
	card.Position = UDim2.fromOffset((index - 1) * (CARD_WIDTH + GAP), 46)
	card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	card.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	text(card, `[{index}]  {string.upper(spec.DisplayName)}`, 26, UDim2.fromOffset(0, 12), 30)
	local role = text(card, spec.Role, 15, UDim2.new(0, 14, 0, 46), 40)
	role.Size = UDim2.new(1, -28, 0, 40)
	role.TextWrapped = true
	role.TextColor3 = Color3.fromRGB(200, 205, 225)

	for row, stat in STATS do
		local best = 0
		for _, other in TankClass.order do
			best = math.max(best, stat.value(TankClass.get(other)))
		end
		local y = 96 + (row - 1) * 36
		local label = text(card, stat.label, 16, UDim2.new(0, 14, 0, y), 16)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Size = UDim2.new(1, -28, 0, 16)
		local track = Instance.new("Frame")
		track.Position = UDim2.new(0, 14, 0, y + 19)
		track.Size = UDim2.new(1, -28, 0, 9)
		track.BackgroundColor3 = Color3.fromRGB(55, 58, 76)
		track.BorderSizePixel = 0
		track.Parent = card
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(0.5, 0)
		trackCorner.Parent = track
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(if best > 0 then stat.value(spec) / best else 0, 1)
		fill.BackgroundColor3 = BAR_COLOR
		fill.BorderSizePixel = 0
		fill.Parent = track
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0.5, 0)
		fillCorner.Parent = fill
	end

	card.Activated:Connect(function()
		pick(name)
	end)
	cards[name] = { stroke = stroke }
end

for index, name in TankClass.order do
	makeCard(index, name)
end

-- Open when the tank is lost; close an auto-opened picker when a new tank arrives.
local function watchTank()
	local tank = TankController.getTank()
	if tank == lastTank then
		return
	end
	lastTank = tank
	if tank then
		pending = nil
		if autoOpened then
			close()
		end
	elseif not gui.Enabled then
		open(true)
	end
end

function ClassPicker.start()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	localPlayer:GetAttributeChangedSignal(TankClass.Attribute):Connect(function()
		pending = nil
		refresh()
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			if gui.Enabled then
				close()
			else
				open(false)
			end
		elseif gui.Enabled then
			local index = table.find(KEYS, input.KeyCode)
			if index and TankClass.order[index] then
				pick(TankClass.order[index])
			end
		end
	end)
	RunService.RenderStepped:Connect(watchTank)
	-- First join: pick a tank (manual open, so it stays until you choose or press C).
	open(false)
end

return ClassPicker
