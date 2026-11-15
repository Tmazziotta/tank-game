--!strict
-- Top-right cluster: daily quests chip, coins with a "+" (shop) button, settings. Quests,
-- buying coins and settings are stubs for now (they toast "coming soon").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Toy = require(script.Parent.Toy)

local CurrencyBar = {}

local H = 62
local GAP = 12

function CurrencyBar.mount(parent: Instance, toast: (string) -> ())
	local holder = Toy.frame(parent, UDim2.new(1, -16, 0, 12), UDim2.fromOffset(0, H))
	holder.Name = "CurrencyBar"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.AutomaticSize = Enum.AutomaticSize.X
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = holder

	-- Daily quests (stub).
	local quests = Toy.button(holder, "★ 0/3", 22, UDim2.new(), UDim2.fromOffset(118, H))
	quests.holder.LayoutOrder = 1
	quests.holder.Name = "Quests"
	quests.button.Activated:Connect(function()
		toast("Daily quests are coming soon")
	end)

	-- Coins + buy.
	local coins = Toy.panel(holder, UDim2.new(), UDim2.fromOffset(236, H))
	coins.holder.LayoutOrder = 2
	coins.holder.Name = "Coins"
	Toy.coin(coins.face, UDim2.fromOffset(10, 11), 34)
	local amount = Toy.text(coins.face, "0", 26, UDim2.fromOffset(52, 0), UDim2.new(1, -110, 1, 0))
	amount.TextXAlignment = Enum.TextXAlignment.Left
	local plus = Toy.button(coins.face, "+", 30, UDim2.new(1, -52, 0, 6), UDim2.fromOffset(44, 44), Toy.Yellow, 12)
	plus.holder.Name = "BuyCoins"
	plus.button.Activated:Connect(function()
		toast("The coin shop is coming soon")
	end)

	-- Settings (stub).
	local settings = Toy.button(holder, "⚙️", 28, UDim2.new(), UDim2.fromOffset(H, H))
	settings.holder.LayoutOrder = 3
	settings.holder.Name = "Settings"
	settings.button.Activated:Connect(function()
		toast("Settings are coming soon")
	end)

	local function render(data: PlayerDataTypes.Data)
		amount.Text = tostring(data.Coins)
	end
	ProfileClient.changed:Connect(render)
	local data = ProfileClient.get()
	if data then
		render(data)
	end
end

return CurrencyBar
