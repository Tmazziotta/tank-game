--!strict
-- Match UI. Top center: Red's alive pips and health %, the round score, Blue's health %
-- and pips, with the timer and round/map below. Center banners for round start, round and
-- match results and your own death. Kill feed in team colors. Everything is read from
-- ReplicatedStorage attributes (RoundSchema) and the TankDestroyed broadcast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundSchema = require(ReplicatedStorage.Shared.RoundSchema)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)

local RoundHud = {}

local FEED_SIZE = 5
local FEED_LIFETIME = 6
local GOLD = Color3.fromRGB(255, 215, 90)
local RED = Color3.fromRGB(255, 110, 100)
local WHITE = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(70, 74, 96)

local localPlayer = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "RoundHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2

local function label(parent: Instance, size: UDim2, position: UDim2, textSize: number, anchor: Vector2?): TextLabel
	local text = Instance.new("TextLabel")
	text.AnchorPoint = anchor or Vector2.new(0.5, 0)
	text.Size = size
	text.Position = position
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = textSize
	text.TextColor3 = WHITE
	text.TextStrokeTransparency = 0.4
	text.Parent = parent
	return text
end

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

-- Scoreboard ---------------------------------------------------------------------

local board = Instance.new("Frame")
board.AnchorPoint = Vector2.new(0.5, 0)
board.Position = UDim2.new(0.5, 0, 0, 8)
board.Size = UDim2.fromOffset(560, 54)
board.BackgroundColor3 = Color3.fromRGB(28, 30, 42)
board.BackgroundTransparency = 0.3
board.Parent = gui
corner(board, UDim.new(0, 12))

local score = label(board, UDim2.fromOffset(120, 50), UDim2.new(0.5, 0, 0, 2), 40)

type TeamPanel = { pips: { Frame }, fill: Frame, percent: TextLabel }
local panels: { [string]: TeamPanel } = {}

for index, team in TeamInfo.order do
	local color = TeamInfo.color(team)
	local left = index == 1
	local x = if left then 12 else 560 - 12 - 200
	local name = label(board, UDim2.fromOffset(200, 18), UDim2.fromOffset(x, 5), 16, Vector2.zero)
	name.Text = string.upper((TeamInfo.get(team) :: TeamInfo.Team).DisplayName)
	name.TextColor3 = color
	name.TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right

	-- Alive pips beside the name.
	local pips = {}
	for i = 1, Config.Round.TeamSize do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(12, 12)
		local offset = 60 + (i - 1) * 16
		pip.Position = UDim2.fromOffset(if left then x + offset else x + 200 - offset - 12, 8)
		pip.BorderSizePixel = 0
		pip.BackgroundColor3 = color
		pip.Parent = board
		corner(pip, UDim.new(0.5, 0))
		pips[i] = pip
	end

	-- Team health bar (the tiebreak).
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(x, 30)
	track.Size = UDim2.fromOffset(160, 14)
	if not left then
		track.Position = UDim2.fromOffset(x + 40, 30)
	end
	track.BackgroundColor3 = Color3.fromRGB(55, 58, 76)
	track.BorderSizePixel = 0
	track.Parent = board
	corner(track, UDim.new(0.5, 0))
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.AnchorPoint = if left then Vector2.zero else Vector2.new(1, 0)
	fill.Position = if left then UDim2.fromScale(0, 0) else UDim2.fromScale(1, 0)
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	corner(fill, UDim.new(0.5, 0))
	local percent = label(board, UDim2.fromOffset(40, 14), UDim2.fromOffset(if left then x + 164 else x, 30), 14, Vector2.zero)
	percent.TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right

	panels[team] = { pips = pips, fill = fill, percent = percent }
end

local timer = label(gui, UDim2.fromOffset(200, 30), UDim2.new(0.5, 0, 0, 64), 28)
local status = label(gui, UDim2.fromOffset(600, 22), UDim2.new(0.5, 0, 0, 94), 18)

-- Below the scoreboard and status line, above the garage panel.
local banner = label(gui, UDim2.fromOffset(800, 56), UDim2.new(0.5, 0, 0, 124), 48)
local subBanner = label(gui, UDim2.fromOffset(800, 28), UDim2.new(0.5, 0, 0, 180), 24)
banner.Visible = false
subBanner.Visible = false

local feed = Instance.new("Frame")
feed.Name = "KillFeed"
feed.AnchorPoint = Vector2.new(1, 0)
feed.Position = UDim2.new(1, -16, 0, 16)
feed.Size = UDim2.fromOffset(340, 200)
feed.BackgroundTransparency = 1
feed.Parent = gui
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.Padding = UDim.new(0, 4)
layout.Parent = feed

-- State ------------------------------------------------------------------------------

local bannerToken = 0
local feedOrder = 0
local lastPhase: string? = nil

local function attr(name: string): any
	return ReplicatedStorage:GetAttribute(name)
end

local function phase(): string
	local value = attr(RoundSchema.PhaseAttribute)
	return if type(value) == "string" then value else "Waiting"
end

local function secondsLeft(): number
	local endsAt = attr(RoundSchema.EndsAtAttribute)
	if type(endsAt) ~= "number" or endsAt <= 0 then
		return 0
	end
	return math.max(0, endsAt - workspace:GetServerTimeNow())
end

local function teamNumber(prefix: string, team: string): number
	local value = attr(prefix .. team)
	return if type(value) == "number" then value else 0
end

local function teamName(team: string?): string
	local info = if team then TeamInfo.get(team) else nil
	return if info then string.upper(info.DisplayName) else "?"
end

local function myTeam(): string?
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

-- Show a banner; `duration` nil keeps it until replaced or hidden.
local function showBanner(text: string, sub: string, color: Color3, duration: number?)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	subBanner.Text = sub
	subBanner.Visible = sub ~= ""
	if duration then
		task.delay(duration, function()
			if bannerToken == token then
				banner.Visible = false
				subBanner.Visible = false
			end
		end)
	end
end

local function hideBanner()
	bannerToken += 1
	banner.Visible = false
	subBanner.Visible = false
end

local function percentText(fraction: number): string
	return `{math.round(fraction * 100)}%`
end

local function roundResult()
	local winner = attr(RoundSchema.RoundWinnerAttribute)
	local reason = attr(RoundSchema.RoundReasonAttribute)
	if type(winner) ~= "string" or winner == "" then
		showBanner("ROUND DRAW", "", GOLD, nil)
		return
	end
	local loser = TeamInfo.other(winner)
	local sub = if reason == "Wipe"
		then `{teamName(loser)} eliminated`
		else `on team health  {percentText(teamNumber(RoundSchema.HealthPrefix, winner))} - {percentText(
			teamNumber(RoundSchema.HealthPrefix, loser)
		)}`
	showBanner(`{teamName(winner)} WINS THE ROUND`, sub, TeamInfo.color(winner), nil)
end

local function matchResult()
	local winner = attr(RoundSchema.MatchWinnerAttribute)
	local a, b = TeamInfo.order[1], TeamInfo.order[2]
	local tally = `{teamNumber(RoundSchema.WinsPrefix, a)} - {teamNumber(RoundSchema.WinsPrefix, b)}`
	if type(winner) == "string" and winner ~= "" then
		local mine = winner == myTeam()
		showBanner(`{teamName(winner)} WINS THE MATCH`, if mine then `Victory!  {tally}` else `Defeat  {tally}`, TeamInfo.color(winner), nil)
	else
		showBanner("MATCH DRAWN", tally, GOLD, nil)
	end
end

local function onPhaseChanged(current: string)
	if current == "PreRound" then
		local round = attr(RoundSchema.RoundNumberAttribute) or 1
		local team = myTeam()
		showBanner(`ROUND {round}`, "", if team then TeamInfo.color(team) else WHITE, nil)
	elseif current == "Active" then
		showBanner("FIGHT!", "", GOLD, 1.5)
	elseif current == "RoundOver" then
		roundResult()
	elseif current == "MatchOver" then
		matchResult()
	else
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

	local a, b = TeamInfo.order[1], TeamInfo.order[2]
	score.Text = `{teamNumber(RoundSchema.WinsPrefix, a)} : {teamNumber(RoundSchema.WinsPrefix, b)}`
	for team, panel in panels do
		local alive = teamNumber(RoundSchema.AlivePrefix, team)
		local health = teamNumber(RoundSchema.HealthPrefix, team)
		for i, pip in panel.pips do
			pip.BackgroundColor3 = if i <= alive then TeamInfo.color(team) else DIM
		end
		panel.fill.Size = UDim2.fromScale(math.clamp(health, 0, 1), 1)
		panel.percent.Text = percentText(health)
	end

	local mapName = attr(RoundSchema.MapAttribute)
	local round = attr(RoundSchema.RoundNumberAttribute) or 1
	local where = `ROUND {round} OF {Config.Round.MaxRounds}  ·  {string.upper(if type(mapName) == "string" then mapName else "")}`
	if current == "Waiting" then
		timer.Text = ""
		status.Text = "WAITING FOR PLAYERS"
	elseif current == "PreRound" then
		timer.Text = tostring(math.ceil(left))
		timer.TextColor3 = GOLD
		local team = myTeam()
		status.Text = if team then `{where}  ·  YOU ARE {teamName(team)}` else where
	elseif current == "Active" then
		timer.Text = formatTime(left)
		timer.TextColor3 = if left <= 30 then RED else WHITE
		status.Text = where
	elseif current == "MatchOver" then
		timer.Text = ""
		status.Text = `NEXT MATCH IN {math.ceil(left)}`
	else
		-- RoundOver: the next round's number is set a moment early, so don't show it.
		timer.Text = ""
		status.Text = ""
	end
end

local function colored(name: string, team: string?): string
	local color = TeamInfo.color(team)
	return string.format('<font color="#%s">%s</font>', color:ToHex(), name)
end

local function addFeedEntry(report: CombatTypes.DestroyedReport)
	feedOrder += 1
	local killerName = report.killerName
	local victim = colored(report.victimName, report.victimTeam)
	local text = if killerName then `{colored(killerName, report.killerTeam)}  >  {victim}` else `{victim} was destroyed`
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
	entry.RichText = true
	entry.Text = `  {text}  `
	entry.Parent = feed
	corner(entry, UDim.new(0, 6))

	local entries = {}
	for _, child in feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(entries, child)
		end
	end
	table.sort(entries, function(x, y)
		return x.LayoutOrder < y.LayoutOrder
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
	if phase() ~= "Active" then
		return
	end
	if report.victim == localPlayer then
		local by = if report.killerName then `by {report.killerName}` else ""
		showBanner(`DESTROYED {by}`, "Spectating your team until the next round", RED, 3)
	elseif report.killer == localPlayer then
		showBanner(`DESTROYED {report.victimName}!`, "", GOLD, 1.5)
	end
end

function RoundHud.start()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	Remotes.TankDestroyed.OnClientEvent:Connect(onTankDestroyed)
	RunService.RenderStepped:Connect(update)
end

return RoundHud
