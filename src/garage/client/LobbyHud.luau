--!strict
-- The Garage HUD (v2, toy-box style). Corners: player card (top-left), quests / coins /
-- settings (top-right), tab rail (left), selected-tank card (right), loadout cards
-- (bottom-left), mode / party / PLAY (bottom-right). Other tabs open a sheet beside the rail.
--
-- Sizing: everything is laid out in reference pixels inside a root frame that one UIScale
-- fits to the safe area (CoreUISafeInsets keeps clear of Roblox's top bar and notches).
-- Small screens switch to "compact": icon-only rail and a slightly bigger scale.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CurrencyBar = require(script.Parent.CurrencyBar)
local LinePicker = require(script.Parent.LinePicker)
local LoadoutCards = require(script.Parent.LoadoutCards)
local PlayPanel = require(script.Parent.PlayPanel)
local PlayerCard = require(script.Parent.PlayerCard)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Progression = require(ReplicatedStorage.Shared.Progression)
local TabRail = require(script.Parent.TabRail)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankInfoCard = require(script.Parent.TankInfoCard)
local Toy = require(script.Parent.Toy)
local ToyShelf = require(script.Parent.ToyShelf)

local LobbyHud = {}

-- Reference size per mode: the root is never smaller than this (in reference pixels).
local FULL_REF = Vector2.new(1250, 620)
local COMPACT_REF = Vector2.new(1100, 500) -- fits the rail exactly; keep in step with TabRail
local MIN_SCALE, MAX_SCALE = 0.5, 1.4
local TOAST_TIME = 4

-- Studio only: set the Lobby ScreenGui's "PreviewSize" attribute (Vector2, the safe-area
-- size of a device) to lay the HUD out as on that screen, shrunk to fit the window and
-- outlined in red, for layout checks without the device emulator.
local PREVIEW_ATTRIBUTE = "PreviewSize"

local SOON: { [string]: { title: string, blurb: string } } = {
	Toolbox = { title = "🧰 Toolbox", blurb = "Mod trees: unlock mods that change how each tank plays." },
	DressUp = { title = "🎩 Dress Up", blurb = "Hats, paint, trails and victory emotes for your tank." },
	Claw = { title = "🕹️ Claw Machine", blurb = "Daily shop and the claw: grab a random cosmetic." },
}

local gui = Instance.new("ScreenGui")
gui.Name = "Lobby"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = root

local previewBox = Instance.new("Frame")
previewBox.Name = "PreviewBox"
previewBox.AnchorPoint = Vector2.new(0.5, 0.5)
previewBox.Position = UDim2.fromScale(0.5, 0.5)
previewBox.BackgroundTransparency = 1
previewBox.Visible = false
previewBox.Parent = gui
local previewStroke = Instance.new("UIStroke")
previewStroke.Color = Color3.new(1, 0, 0)
previewStroke.Thickness = 2
previewStroke.Parent = previewBox

-- Garage tab widgets (hidden on other tabs).
local garagePage = Toy.frame(root, UDim2.new(), UDim2.fromScale(1, 1))
garagePage.Name = "GaragePage"

-- Sheet for the other tabs.
local sheet = Toy.panel(root, UDim2.new(), UDim2.new())
sheet.holder.Name = "Sheet"
sheet.face.Active = true -- swallow drags so the turntable doesn't spin under the menu
local shelfPage = Toy.frame(sheet.face, UDim2.fromOffset(0, 12), UDim2.new(1, 0, 1, -12))
shelfPage.Name = "ShelfPage"
local soonPage = Toy.frame(sheet.face, UDim2.new(), UDim2.fromScale(1, 1))
local soonTitle = Toy.text(soonPage, "", 44, UDim2.new(0, 0, 0.5, -90), UDim2.new(1, 0, 0, 50))
local soonChip = Toy.chip(soonPage, "COMING SOON", Toy.Yellow)
soonChip.AnchorPoint = Vector2.new(0.5, 0)
soonChip.Position = UDim2.new(0.5, 0, 0.5, -28)
local soonBlurb = Toy.text(soonPage, "", 20, UDim2.new(0, 60, 0.5, 20), UDim2.new(1, -120, 0, 60), Toy.BrownSoft)
soonBlurb.TextWrapped = true

-- Toast (top center, over everything).
local toastPanel = Toy.panel(root, UDim2.new(0.5, 0, 0, 14), UDim2.fromOffset(420, 58), Toy.YellowLight)
toastPanel.holder.Name = "Toast"
toastPanel.holder.AnchorPoint = Vector2.new(0.5, 0)
toastPanel.holder.Visible = false
toastPanel.holder.ZIndex = 50
local toastLabel = Toy.text(toastPanel.face, "", 19, UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0))
toastLabel.TextWrapped = true
local toastSerial = 0

function LobbyHud.toast(message: string)
	toastSerial += 1
	local serial = toastSerial
	toastLabel.Text = message
	toastPanel.holder.Visible = true
	task.delay(TOAST_TIME, function()
		if toastSerial == serial then
			toastPanel.holder.Visible = false
		end
	end)
end

-- State ------------------------------------------------------------------------------
local currentTab = "Garage"
local compact = false
local playCallback: (() -> ())? = nil
local playBusy = false
local play: PlayPanel.Handle? = nil

local function layoutSheet()
	local left = 16 + TabRail.width(compact) + 16
	sheet.holder.Position = UDim2.fromOffset(left, TabRail.Top)
	sheet.holder.Size = UDim2.new(1, -left - 16, 1, -TabRail.Top - 16)
end

local function selectTab(id: string)
	currentTab = id
	TabRail.setSelected(id)
	garagePage.Visible = id == "Garage"
	sheet.holder.Visible = id ~= "Garage"
	shelfPage.Visible = id == "ToyShelf"
	local soon = SOON[id]
	soonPage.Visible = soon ~= nil
	if soon then
		soonTitle.Text = soon.title
		soonBlurb.Text = soon.blurb
	end
	if id == "ToyShelf" then
		ToyShelf.mount(shelfPage)
	end
end

local function previewSize(): Vector2?
	if not Config.Places.DevMode then
		return nil
	end
	local value = gui:GetAttribute(PREVIEW_ATTRIBUTE)
	return if typeof(value) == "Vector2" and value.X > 0 and value.Y > 0 then value else nil
end

local function rescale()
	local window = gui.AbsoluteSize
	if window.X <= 0 or window.Y <= 0 then
		return
	end
	-- `size` is the screen being laid out for; `fit` shrinks a preview into the window.
	local preview = previewSize()
	local size = preview or window
	local fit = if preview then math.min(window.X / preview.X, window.Y / preview.Y, 1) else 1
	local nowCompact = size.Y < 500 or size.X < 1000
	local ref = if nowCompact then COMPACT_REF else FULL_REF
	local s = math.clamp(math.min(size.X / ref.X, size.Y / ref.Y), MIN_SCALE, MAX_SCALE)
	scale.Scale = s * fit
	root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
	root.AnchorPoint = if preview then Vector2.new(0.5, 0.5) else Vector2.zero
	root.Position = if preview then UDim2.fromScale(0.5, 0.5) else UDim2.new()
	previewBox.Visible = preview ~= nil
	previewBox.Size = UDim2.fromOffset(size.X * fit, size.Y * fit)
	if nowCompact ~= compact then
		compact = nowCompact
		TabRail.setCompact(compact)
		TankInfoCard.setCompact(compact)
		LoadoutCards.setLeft(16 + TabRail.width(compact) + 16)
		layoutSheet()
	end
end

-- "NEW" badges: Toy Shelf when a tank can be bought right now; Toolbox when the selected
-- tank has a mod it can unlock.
local function updateNew(data: PlayerDataTypes.Data)
	local buyable = false
	for _, id in TankCatalog.order do
		if Progression.canBuy(data, id) then
			buyable = true
			break
		end
	end
	TabRail.setNew("ToyShelf", buyable)
	local unlockable = false
	if data.OwnedTanks[data.SelectedTank] then
		for _, row in TankCatalog.modRows(data.SelectedTank) do
			for _, modId in row do
				if Progression.canUnlockMod(data, data.SelectedTank, modId) then
					unlockable = true
				end
			end
		end
	end
	TabRail.setNew("Toolbox", unlockable)
end

-- PLAY calls `callback` (which may yield); the button is locked until it returns.
function LobbyHud.onPlay(callback: () -> ())
	playCallback = callback
end

function LobbyHud.setPlayBusy(on: boolean, text: string?)
	playBusy = on
	if play then
		play.setBusy(on, text)
	end
end

function LobbyHud.gui(): ScreenGui
	return gui
end

function LobbyHud.start()
	PlayerCard.mount(root)
	CurrencyBar.mount(root, LobbyHud.toast)
	TabRail.mount(root, selectTab)
	TankInfoCard.mount(garagePage, function()
		selectTab("Toolbox")
	end)
	LoadoutCards.mount(garagePage, 16 + TabRail.width(compact) + 16, LobbyHud.toast)
	play = PlayPanel.mount(garagePage, LobbyHud.toast, function()
		local callback = playCallback
		if playBusy or not callback then
			return
		end
		callback()
	end)
	ToyShelf.start()
	LinePicker.mount(root, LobbyHud.toast)
	layoutSheet()
	ProfileClient.changed:Connect(updateNew)
	local data = ProfileClient.get()
	if data then
		updateNew(data)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	gui:GetAttributeChangedSignal(PREVIEW_ATTRIBUTE):Connect(rescale)
	rescale()
	selectTab(currentTab)
end

return LobbyHud
