--!strict
-- Coins, level and XP bar (top left), plus "+25 coins +50 XP" popups for rewards and a
-- level-up banner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local Progression = require(ReplicatedStorage.Shared.Progression)
local ProfileClient = require(script.Parent.ProfileClient)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type RewardInfo = { reason: string, coins: number, xp: number, levelUp: number? }

local ProgressHud = {}

local GOLD = Color3.fromRGB(255, 215, 90)
local XP_COLOR = Color3.fromRGB(140, 220, 255)
local POPUP_LIFETIME = 2.5

local gui = Instance.new("ScreenGui")
gui.Name = "ProgressHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2

local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(16, 16)
panel.Size = UDim2.fromOffset(220, 62)
panel.BackgroundColor3 = Color3.fromRGB(28, 30, 42)
panel.BackgroundTransparency = 0.25
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local function label(parent: Instance, position: UDim2, size: UDim2, textSize: number, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = textSize
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.6
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Position = position
	text.Size = size
	text.Parent = parent
	return text
end

local levelText = label(panel, UDim2.fromOffset(12, 6), UDim2.fromOffset(100, 24), 22, Color3.new(1, 1, 1))
local coinsText = label(panel, UDim2.fromOffset(110, 6), UDim2.fromOffset(100, 24), 22, GOLD)
coinsText.TextXAlignment = Enum.TextXAlignment.Right

local barTrack = Instance.new("Frame")
barTrack.Position = UDim2.fromOffset(12, 36)
barTrack.Size = UDim2.new(1, -24, 0, 14)
barTrack.BackgroundColor3 = Color3.fromRGB(55, 58, 76)
barTrack.BorderSizePixel = 0
barTrack.Parent = panel
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0.5, 0)
trackCorner.Parent = barTrack
local barFill = Instance.new("Frame")
barFill.BackgroundColor3 = XP_COLOR
barFill.BorderSizePixel = 0
barFill.Size = UDim2.fromScale(0, 1)
barFill.Parent = barTrack
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0.5, 0)
fillCorner.Parent = barFill
local xpText = label(barTrack, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 12, Color3.new(1, 1, 1))
xpText.TextXAlignment = Enum.TextXAlignment.Center
xpText.ZIndex = 2

local popups = Instance.new("Frame")
popups.BackgroundTransparency = 1
popups.Position = UDim2.fromOffset(16, 86)
popups.Size = UDim2.fromOffset(300, 200)
popups.Parent = gui
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = popups

local levelBanner = Instance.new("TextLabel")
levelBanner.AnchorPoint = Vector2.new(0.5, 0)
levelBanner.Position = UDim2.fromScale(0.5, 0.22)
levelBanner.Size = UDim2.fromOffset(500, 50)
levelBanner.BackgroundTransparency = 1
levelBanner.Font = Enum.Font.FredokaOne
levelBanner.TextSize = 40
levelBanner.TextColor3 = XP_COLOR
levelBanner.TextStrokeTransparency = 0.3
levelBanner.Visible = false
levelBanner.Parent = gui

local popupCount = 0

local function render(data: PlayerDataTypes.Data)
	local level = Progression.levelForXP(data.XP)
	levelText.Text = `Level {level}`
	coinsText.Text = `{data.Coins} coins`
	local into, span = Progression.levelProgress(data.XP)
	barFill.Size = UDim2.fromScale(if span > 0 then into / span else 1, 1)
	xpText.Text = if span > 0 then `{into} / {span} XP` else "MAX"
end

local function showPopup(info: RewardInfo)
	popupCount += 1
	local parts = {}
	if info.coins > 0 then
		table.insert(parts, `+{info.coins} coins`)
	end
	if info.xp > 0 then
		table.insert(parts, `+{info.xp} XP`)
	end
	local text = label(popups, UDim2.new(), UDim2.fromOffset(300, 22), 20, GOLD)
	text.LayoutOrder = popupCount
	text.Text = `{info.reason}  {table.concat(parts, "  ")}`
	task.delay(POPUP_LIFETIME, function()
		local tween = TweenService:Create(text, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween:Play()
		tween.Completed:Once(function()
			text:Destroy()
		end)
	end)

	local levelUp = info.levelUp
	if levelUp then
		levelBanner.Text = `LEVEL UP!  Level {levelUp}`
		levelBanner.Visible = true
		task.delay(3, function()
			if levelBanner.Text == `LEVEL UP!  Level {levelUp}` then
				levelBanner.Visible = false
			end
		end)
	end
end

function ProgressHud.start()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local current = ProfileClient.get()
	if current then
		render(current)
	end
	ProfileClient.changed:Connect(render)
	Remotes.Reward.OnClientEvent:Connect(showPopup)
end

return ProgressHud
