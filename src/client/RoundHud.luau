--!strict
-- Round UI: phase + timer at the top, center banners (round start, results, your own
-- death), and a kill feed. Reads round state from ReplicatedStorage attributes and the
-- TankDestroyed broadcast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)

local RoundHud = {}

local FEED_SIZE = 5
local FEED_LIFETIME = 6
local GOLD = Color3.fromRGB(255, 215, 90)
local RED = Color3.fromRGB(255, 110, 100)
local WHITE = Color3.new(1, 1, 1)

local localPlayer = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "RoundHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2

local function label(name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Size = size
	text.Position = position
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = textSize
	text.TextColor3 = WHITE
	text.TextStrokeTransparency = 0.4
	text.Parent = gui
	return text
end

local timer = label("Timer", UDim2.fromOffset(400, 40), UDim2.new(0.5, 0, 0, 6), 34)
local status = label("Status", UDim2.fromOffset(500, 24), UDim2.new(0.5, 0, 0, 44), 20)
local banner = label("Banner", UDim2.fromOffset(700, 120), UDim2.fromScale(0.5, 0.12), 52)
banner.TextWrapped = true
banner.Visible = false

local feed = Instance.new("Frame")
feed.Name = "KillFeed"
feed.AnchorPoint = Vector2.new(1, 0)
feed.Position = UDim2.new(1, -16, 0, 60)
feed.Size = UDim2.fromOffset(340, 200)
feed.BackgroundTransparency = 1
feed.Parent = gui
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.Padding = UDim.new(0, 4)
layout.Parent = feed

local bannerToken = 0
local feedOrder = 0
local deathBannerUntil = 0
local lastPhase: string? = nil

local function phase(): string
	local value = ReplicatedStorage:GetAttribute(RoundSchema.PhaseAttribute)
	return if type(value) == "string" then value else "Waiting"
end

local function secondsLeft(): number
	local endsAt = ReplicatedStorage:GetAttribute(RoundSchema.EndsAtAttribute)
	if type(endsAt) ~= "number" or endsAt <= 0 then
		return 0
	end
	return math.max(0, endsAt - workspace:GetServerTimeNow())
end

-- Show `text` in the middle of the screen; `duration` nil keeps it until replaced.
local function showBanner(text: string, color: Color3, duration: number?)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	if duration then
		task.delay(duration, function()
			if bannerToken == token then
				banner.Visible = false
			end
		end)
	end
end

local function hideBanner()
	bannerToken += 1
	banner.Visible = false
end

local function resultsText(): string
	local winner = ReplicatedStorage:GetAttribute(RoundSchema.WinnerAttribute)
	local kills = ReplicatedStorage:GetAttribute(RoundSchema.WinnerKillsAttribute)
	if type(winner) == "string" and winner ~= "" then
		local suffix = if kills == 1 then "kill" else "kills"
		return `{winner} WINS!\n{kills} {suffix}`
	end
	return "DRAW!"
end

local function onPhaseChanged(current: string)
	if current == "Active" then
		showBanner("FIGHT!", GOLD, 2)
	elseif current == "Results" then
		showBanner(resultsText(), GOLD, nil)
	elseif lastPhase == "Results" then
		hideBanner()
	end
	lastPhase = current
end

local function formatTime(seconds: number): string
	local whole = math.ceil(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function update()
	local current = phase()
	if current ~= lastPhase then
		onPhaseChanged(current)
	end
	local left = secondsLeft()
	local mapName = ReplicatedStorage:GetAttribute(RoundSchema.MapAttribute)
	local mapSuffix = if type(mapName) == "string" and mapName ~= "" then ` - {string.upper(mapName)}` else ""
	if current == "Waiting" then
		timer.Text = ""
		status.Text = `WAITING FOR PLAYERS ({#Players:GetPlayers()}/{Config.Round.MinPlayers}) - WARM UP!`
	elseif current == "Intermission" then
		timer.Text = ""
		status.Text = `ROUND STARTS IN {math.ceil(left)}{mapSuffix}`
	elseif current == "Active" then
		timer.Text = formatTime(left)
		timer.TextColor3 = if left <= 30 then RED else WHITE
		status.Text = `FREE-FOR-ALL{mapSuffix} - MOST KILLS WINS`
	else
		timer.Text = ""
		status.Text = `NEXT ROUND IN {math.ceil(left)}`
	end
	if deathBannerUntil > 0 then
		local respawnIn = deathBannerUntil - os.clock()
		if respawnIn > 0 and banner.Visible then
			banner.Text = string.gsub(banner.Text, "%d+$", tostring(math.ceil(respawnIn)))
		else
			deathBannerUntil = 0
		end
	end
end

local function addFeedEntry(report: CombatTypes.DestroyedReport)
	feedOrder += 1
	local killerName = report.killerName
	local text = if killerName then `{killerName}  >  {report.victimName}` else `{report.victimName} was destroyed`
	local involved = (report.killer ~= nil and report.killer == localPlayer) or report.victim == localPlayer

	local entry = Instance.new("TextLabel")
	entry.LayoutOrder = feedOrder
	entry.AutomaticSize = Enum.AutomaticSize.X
	entry.Size = UDim2.fromOffset(0, 26)
	entry.BackgroundColor3 = if involved then Color3.fromRGB(120, 80, 20) else Color3.fromRGB(20, 22, 32)
	entry.BackgroundTransparency = 0.35
	entry.Font = Enum.Font.FredokaOne
	entry.TextSize = 18
	entry.TextColor3 = WHITE
	entry.Text = `  {text}  `
	entry.Parent = feed
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = entry

	local entries = {}
	for _, child in feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(entries, child)
		end
	end
	table.sort(entries, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #entries - FEED_SIZE do
		entries[i]:Destroy()
	end

	task.delay(FEED_LIFETIME, function()
		if entry.Parent then
			local tween = TweenService:Create(entry, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
			tween.Completed:Once(function()
				entry:Destroy()
			end)
			tween:Play()
		end
	end)
end

local function onTankDestroyed(report: CombatTypes.DestroyedReport)
	addFeedEntry(report)
	if report.victim == localPlayer and phase() ~= "Results" then
		local by = if report.killerName then `by {report.killerName}` else ""
		deathBannerUntil = os.clock() + Config.Respawn.Delay
		showBanner(`DESTROYED {by}\nRespawning in {Config.Respawn.Delay}`, RED, Config.Respawn.Delay)
	elseif report.killer == localPlayer and report.victim ~= localPlayer then
		showBanner(`DESTROYED {report.victimName}!`, GOLD, 1.5)
	end
end

function RoundHud.start()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	Remotes.TankDestroyed.OnClientEvent:Connect(onTankDestroyed)
	RunService.RenderStepped:Connect(update)
end

return RoundHud
