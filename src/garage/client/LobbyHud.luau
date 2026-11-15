--!strict
-- The Garage HUD: level/XP/coins chip, the tab strip (Garage, Toy Shelf, Toolbox, Dress Up,
-- Claw Machine), the loadout bar and PLAY on the Garage tab, the interim Toy Shelf, and
-- "coming soon" cards for the rest. Laid out at a 1100x620 reference size and scaled to
-- the screen (UIScale), so it fits phones as well as PC.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LoadoutBar = require(script.Parent.LoadoutBar)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Progression = require(ReplicatedStorage.Shared.Progression)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local ToyShelf = require(script.Parent.ToyShelf)
local UiKit = require(script.Parent.UiKit)

type Data = PlayerDataTypes.Data

local LobbyHud = {}

local REF_W, REF_H = 1100, 620
local TAB_W, TAB_H, TAB_GAP = 158, 58, 6
local TOAST_TIME = 4

type Tab = { id: string, label: string, blurb: string? }
local TABS: { Tab } = {
	{ id = "Garage", label = "GARAGE" },
	{ id = "ToyShelf", label = "TOY SHELF" },
	{ id = "Toolbox", label = "TOOLBOX", blurb = "Mod trees: unlock mods that change how each tank plays." },
	{ id = "DressUp", label = "DRESS UP", blurb = "Hats, paint, trails and victory emotes for your tank." },
	{ id = "Claw", label = "CLAW MACHINE", blurb = "Daily shop and the claw: grab a random cosmetic." },
}

local gui = Instance.new("ScreenGui")
gui.Name = "Lobby"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(REF_W, REF_H)
root.BackgroundTransparency = 1
root.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = root

local function rescale()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		scale.Scale = math.min(size.X / REF_W, size.Y / REF_H)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)

-- Profile chip ----------------------------------------------------------------------
local chip = UiKit.frame(root, UDim2.fromOffset(10, 10), UDim2.fromOffset(250, TAB_H + 12), UiKit.Panel, 0.1)
UiKit.corner(chip, 14)
local levelLabel = UiKit.label(chip, "Level 1", 24, UDim2.fromOffset(14, 6), UDim2.fromOffset(110, 30))
levelLabel.TextXAlignment = Enum.TextXAlignment.Left
local coinLabel = UiKit.label(chip, "0 coins", 22, UDim2.new(1, -134, 0, 6), UDim2.fromOffset(120, 30))
coinLabel.TextXAlignment = Enum.TextXAlignment.Right
coinLabel.TextColor3 = UiKit.Gold
local xpTrack = UiKit.frame(chip, UDim2.fromOffset(14, 42), UDim2.new(1, -28, 0, 20), UiKit.PanelLight)
UiKit.corner(xpTrack, 10)
local xpFill = UiKit.frame(xpTrack, UDim2.new(), UDim2.fromScale(0, 1), UiKit.XP)
UiKit.corner(xpFill, 10)
local xpText = UiKit.label(xpTrack, "", 16, UDim2.new(), UDim2.fromScale(1, 1))
xpText.ZIndex = 2

-- Tabs -------------------------------------------------------------------------------
local tabButtons: { [string]: TextButton } = {}
for index, tab in TABS do
	local b = UiKit.button(root, tab.label, 18, UDim2.fromOffset(270 + (index - 1) * (TAB_W + TAB_GAP), 10), UDim2.fromOffset(TAB_W, TAB_H), UiKit.Panel)
	b.BackgroundTransparency = 0.1
	b.Name = `Tab{tab.id}`
	tabButtons[tab.id] = b
end

-- Content area under the top bar.
local content = UiKit.frame(root, UDim2.fromOffset(0, TAB_H + 30), UDim2.new(1, 0, 1, -(TAB_H + 30)), Color3.new(), 1)

-- Garage tab: selected tank name, loadout bar and PLAY.
content.Name = "Content"
local garagePage = UiKit.frame(content, UDim2.new(), UDim2.fromScale(1, 1), Color3.new(), 1)
garagePage.Name = "GaragePage"
local tankName = UiKit.label(garagePage, "", 34, UDim2.new(0, 0, 1, -170), UDim2.new(1, -240, 0, 40))
local tankInfo = UiKit.label(garagePage, "", 18, UDim2.new(0, 0, 1, -134), UDim2.new(1, -240, 0, 22))
tankInfo.TextColor3 = UiKit.Muted
local playButton = UiKit.button(garagePage, "PLAY", 46, UDim2.new(1, -256, 1, -112), UDim2.fromOffset(240, 96), UiKit.Gold)
playButton.Name = "Play"
playButton.TextColor3 = Color3.fromRGB(60, 40, 10)
playButton.TextStrokeTransparency = 1
local playInfo = UiKit.label(playButton, "", 17, UDim2.new(0, 0, 1, -26), UDim2.new(1, 0, 0, 20))
playInfo.TextColor3 = Color3.fromRGB(90, 60, 20)
playInfo.TextStrokeTransparency = 1
UiKit.stroke(playButton, Color3.fromRGB(255, 240, 180), 3)

-- Other tabs sit on a dimmed panel so text stays readable over the desk.
local sheet = UiKit.frame(content, UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, -10), UiKit.Panel, 0.25)
sheet.Active = true -- swallow drags so the turntable doesn't spin under the menu
UiKit.corner(sheet, 18)
local shelfPage = UiKit.frame(sheet, UDim2.fromOffset(0, 10), UDim2.new(1, 0, 1, -10), Color3.new(), 1)
local soonPage = UiKit.frame(sheet, UDim2.new(), UDim2.fromScale(1, 1), Color3.new(), 1)
local soonTitle = UiKit.label(soonPage, "", 44, UDim2.new(0, 0, 0.5, -90), UDim2.new(1, 0, 0, 50))
local soonTag = UiKit.label(soonPage, "COMING SOON", 26, UDim2.new(0, 0, 0.5, -30), UDim2.new(1, 0, 0, 30))
soonTag.TextColor3 = UiKit.Gold
local soonBlurb = UiKit.label(soonPage, "", 20, UDim2.new(0, 60, 0.5, 14), UDim2.new(1, -120, 0, 60))
soonBlurb.TextColor3 = UiKit.Muted
soonBlurb.TextWrapped = true

-- Toast ------------------------------------------------------------------------------
local toastLabel = UiKit.label(root, "", 22, UDim2.new(0.5, -300, 0, TAB_H + 36), UDim2.fromOffset(600, 44))
toastLabel.BackgroundColor3 = UiKit.Panel
toastLabel.BackgroundTransparency = 0.1
toastLabel.Visible = false
toastLabel.ZIndex = 10
toastLabel.TextWrapped = true
UiKit.corner(toastLabel, 12)
local toastSerial = 0

function LobbyHud.toast(message: string)
	toastSerial += 1
	local serial = toastSerial
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(TOAST_TIME, function()
		if toastSerial == serial then
			toastLabel.Visible = false
		end
	end)
end

-- State ------------------------------------------------------------------------------
local currentTab = "Garage"
local playCallback: (() -> ())? = nil
local playBusy = false

local function selectTab(id: string)
	currentTab = id
	for tabId, b in tabButtons do
		b.BackgroundColor3 = if tabId == id then UiKit.Blue else UiKit.Panel
	end
	garagePage.Visible = id == "Garage"
	LoadoutBar.setVisible(id == "Garage")
	sheet.Visible = id ~= "Garage"
	shelfPage.Visible = id == "ToyShelf"
	soonPage.Visible = id ~= "Garage" and id ~= "ToyShelf"
	if id == "ToyShelf" then
		ToyShelf.mount(shelfPage)
	end
	for _, tab in TABS do
		if tab.id == id and tab.blurb then
			soonTitle.Text = tab.label
			soonBlurb.Text = tab.blurb
		end
	end
end

local function render(data: Data)
	local level = Progression.levelForXP(data.XP)
	levelLabel.Text = `Level {level}`
	coinLabel.Text = `{data.Coins} coins`
	local floor = Progression.xpForLevel(level)
	local nextAt = Progression.xpForLevel(level + 1)
	local into, span = data.XP - floor, math.max(nextAt - floor, 1)
	xpFill.Size = UDim2.fromScale(math.clamp(into / span, 0, 1), 1)
	xpText.Text = `{into} / {span} XP`
	local def = TankCatalog.get(data.SelectedTank)
	tankName.Text = string.upper(def.DisplayName)
	tankInfo.Text = `{def.Class} · Tier {UiKit.tier(def.Tier)}`
	playInfo.Text = `4v4 · Tier {UiKit.tier(def.Tier)}`
end

-- PLAY calls `callback` (which may yield); the button is locked until it returns.
function LobbyHud.onPlay(callback: () -> ())
	playCallback = callback
end

function LobbyHud.setPlayBusy(on: boolean, text: string?)
	playBusy = on
	playButton.Text = text or "PLAY"
	playButton.BackgroundColor3 = if on then UiKit.Disabled else UiKit.Gold
end

function LobbyHud.gui(): ScreenGui
	return gui
end

function LobbyHud.start()
	LoadoutBar.mount(garagePage, root, Config.Garage.LoadoutSlots, LobbyHud.toast)
	ToyShelf.start()
	for id, b in tabButtons do
		b.Activated:Connect(function()
			selectTab(id)
		end)
	end
	playButton.Activated:Connect(function()
		local callback = playCallback
		if playBusy or not callback then
			return
		end
		callback()
	end)
	ProfileClient.changed:Connect(render)
	local data = ProfileClient.get()
	if data then
		render(data)
	end
	selectTab(currentTab)
	rescale()
end

return LobbyHud
