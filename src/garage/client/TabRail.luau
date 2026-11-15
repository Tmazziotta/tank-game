--!strict
-- Left tab rail: chunky toy buttons with an icon, plus the label on wide screens (icon-only
-- in compact mode). Any tab can carry a red "NEW" badge.

local Toy = require(script.Parent.Toy)

export type Tab = { id: string, label: string, icon: string }

local TabRail = {}

TabRail.Top = 124
TabRail.FullWidth = 210
TabRail.CompactWidth = 84
local H, GAP = 64, 10

TabRail.tabs = {
	{ id = "Garage", label = "Garage", icon = "🏠" },
	{ id = "ToyShelf", label = "Toy Shelf", icon = "🧸" },
	{ id = "Toolbox", label = "Toolbox", icon = "🧰" },
	{ id = "DressUp", label = "Dress Up", icon = "🎩" },
	{ id = "Claw", label = "Claw Machine", icon = "🕹️" },
} :: { Tab }

type Entry = { button: Toy.Button, icon: TextLabel, label: TextLabel, badge: Frame }

local entries: { [string]: Entry } = {}
local holder: Frame? = nil

function TabRail.mount(parent: Instance, onSelect: (id: string) -> ())
	local rail = Toy.frame(parent, UDim2.fromOffset(16, TabRail.Top), UDim2.fromOffset(TabRail.FullWidth, #TabRail.tabs * (H + GAP)))
	rail.Name = "TabRail"
	holder = rail
	for index, tab in TabRail.tabs do
		local b = Toy.button(rail, "", 20, UDim2.new(0, 0, 0, (index - 1) * (H + GAP)), UDim2.new(1, 0, 0, H))
		b.holder.Name = `Tab{tab.id}`
		local icon = Toy.text(b.face, tab.icon, 30, UDim2.fromOffset(8, 0), UDim2.new(0, 52, 1, 0))
		icon.ZIndex = 3
		local label = Toy.text(b.face, tab.label, 22, UDim2.fromOffset(62, 0), UDim2.new(1, -70, 1, 0))
		label.ZIndex = 3
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 22
		limit.Parent = label
		local badge = Toy.newBadge(b.holder)
		badge.Visible = false
		entries[tab.id] = { button = b, icon = icon, label = label, badge = badge }
		b.button.Activated:Connect(function()
			onSelect(tab.id)
		end)
	end
end

function TabRail.setSelected(id: string)
	for tabId, entry in entries do
		entry.button.face.BackgroundColor3 = if tabId == id then Toy.Yellow else Toy.Cream
	end
end

function TabRail.setNew(id: string, on: boolean)
	local entry = entries[id]
	if entry then
		entry.badge.Visible = on
	end
end

-- Icon-only rail on small screens.
function TabRail.setCompact(on: boolean)
	local rail = holder
	if rail then
		rail.Size = UDim2.fromOffset(if on then TabRail.CompactWidth else TabRail.FullWidth, rail.Size.Y.Offset)
	end
	for _, entry in entries do
		entry.label.Visible = not on
		entry.icon.Position = if on then UDim2.new() else UDim2.fromOffset(8, 0)
		entry.icon.Size = if on then UDim2.fromScale(1, 1) else UDim2.new(0, 52, 1, 0)
	end
end

function TabRail.width(compact: boolean): number
	return if compact then TabRail.CompactWidth else TabRail.FullWidth
end

return TabRail
