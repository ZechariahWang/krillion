--!strict
-- Drives LobbyUi.Collection, the answer collection window opened from the rail's CollectionButton: one card per
-- prompt with your best match answer and its tier (Shared/Collection), a gold check once mastered, the
-- mastered and found counts, the next milestone and a search box. The album (every live prompt and its
-- rarest tier) comes from the server (CollectionCatalog); the cards come from the profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local CollectionRules = require(ReplicatedStorage.Shared.Collection)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local WAIT_SECONDS = 10
local MARGIN = 16
local MIN_FIT = 0.4
local RAIL_KEY = "CollectionButton"
local NOT_FOUND = Color3.fromHex("8A9BB0")

local player = Players.LocalPlayer

type CardView = {
	entry: CollectionRules.Entry,
	frame: Frame,
	prompt: TextLabel,
	tier: TextLabel,
	answer: TextLabel,
	check: GuiObject?,
	dim: GuiObject?,
}

local gui: Frame? = nil
local panel: Frame? = nil
local fit: UIScale? = nil
local grid: ScrollingFrame? = nil
local template: Frame? = nil
local progress: TextLabel? = nil
local nextLine: TextLabel? = nil
local search: TextBox? = nil
local opened = false

local catalogue: { CollectionRules.Entry } = {}
local cards: { [string]: CollectionRules.Card } = {}
local views: { CardView } = {}

local Collection = {}

local function fitToScreen()
	local screen = gui
	local frame = panel
	local scale = fit
	if screen == nil or frame == nil or scale == nil then
		return
	end
	Ui.fitPanel(screen.AbsoluteSize, frame, scale, nil, MARGIN, MIN_FIT, 0)
end

local function textChild(parent: Instance, name: string): TextLabel
	return parent:FindFirstChild(name) :: TextLabel
end

-- One card per album prompt, made once when the album arrives; render() only changes what they show.
local function buildCards()
	local holder = grid
	local base = template
	if holder == nil or base == nil then
		return
	end
	for _, view in views do
		view.frame:Destroy()
	end
	views = {}
	for _, entry in catalogue do
		local frame = base:Clone()
		frame.Name = "Card"
		frame.Visible = true
		frame.Parent = holder
		table.insert(views, {
			entry = entry,
			frame = frame,
			prompt = textChild(frame, "Prompt"),
			tier = textChild(frame, "Tier"),
			answer = textChild(frame, "Answer"),
			check = frame:FindFirstChild("Check") :: GuiObject?,
			dim = frame:FindFirstChild("Dim") :: GuiObject?,
		})
	end
end

local function milestoneText(mastered: number): string
	local milestone = CollectionRules.nextMilestone(mastered, #catalogue)
	if milestone == nil then
		return "EVERY MILESTONE REACHED"
	end
	local parts = { "NEXT: " .. CollectionRules.needFor(milestone, #catalogue) .. " MASTERED" }
	if milestone.shells > 0 then
		table.insert(parts, "+" .. Currency.format(milestone.shells))
	end
	local title = milestone.title
	if title ~= nil then
		for _, item in Cosmetics.forReward(title) do
			table.insert(parts, string.upper(item.name) .. " TITLE")
		end
	end
	return table.concat(parts, "  |  ")
end

-- Found cards first, rarest first; then the rest; alphabetical within each.
local function sortKey(view: CardView): (number, string)
	local card = cards[view.entry.id]
	local index = if card ~= nil then Tiers.index(card.tier) else 0
	return index, view.entry.prompt
end

local function render()
	local found, mastered = CollectionRules.counts(cards, catalogue)
	if progress ~= nil then
		progress.Text = mastered .. "/" .. #catalogue .. " MASTERED  |  " .. found .. " FOUND"
	end
	if nextLine ~= nil then
		nextLine.Text = milestoneText(mastered)
	end
	local query = ""
	if search ~= nil then
		query = string.lower(search.Text)
	end
	table.sort(views, function(a, b)
		local aIndex, aPrompt = sortKey(a)
		local bIndex, bPrompt = sortKey(b)
		if aIndex ~= bIndex then
			return aIndex > bIndex
		end
		return aPrompt < bPrompt
	end)
	for order, view in views do
		local card = cards[view.entry.id]
		view.frame.LayoutOrder = order
		view.frame.Visible = query == "" or string.find(string.lower(view.entry.prompt), query, 1, true) ~= nil
		view.prompt.Text = string.upper(view.entry.prompt)
		if card ~= nil then
			local info = Tiers.ByName[card.tier]
			view.tier.Text = if info ~= nil then string.upper(info.label) else card.tier
			view.tier.TextColor3 = Ui.tierColor(card.tier)
			view.answer.Text = string.upper(card.answer)
		else
			view.tier.Text = "???"
			view.tier.TextColor3 = NOT_FOUND
			view.answer.Text = "NOT FOUND YET"
		end
		if view.check ~= nil then
			view.check.Visible = CollectionRules.isMastered(card, view.entry.top)
		end
		if view.dim ~= nil then
			view.dim.Visible = card == nil
		end
	end
end

function Collection.close()
	local screen = gui
	if screen == nil or not opened then
		return
	end
	opened = false
	screen.Visible = false
	Windows.closed(Collection.close)
end

-- Never over a pillar: the match comes first.
function Collection.open()
	local screen = gui
	local frame = panel
	if screen == nil or frame == nil or player:GetAttribute("Playing") == true then
		return
	end
	if #catalogue == 0 then
		Net.event("CollectionCatalog"):FireServer()
	end
	fitToScreen()
	render()
	screen.Visible = true
	if not opened then
		opened = true
		Sfx.play("Open", 0.5)
		Ui.pop(frame, 0.7)
	end
	Windows.opened(Collection.close)
end

local function toggle()
	if opened then
		Sfx.play("Close", 0.5)
		Collection.close()
	else
		Collection.open()
	end
end

function Collection.onProfile(profile)
	if type(profile) ~= "table" or type(profile.collection) ~= "table" then
		return
	end
	cards = profile.collection
	if opened then
		render()
	end
end

local function onCatalogue(payload)
	if type(payload) ~= "table" then
		return
	end
	catalogue = payload
	buildCards()
	render()
end

local function bind(screen: Frame)
	local holder = screen:FindFirstChild("Holder")
	local found = if holder ~= nil then holder:FindFirstChild("Panel") else nil
	local scale = if holder ~= nil then holder:FindFirstChild("Fit") else nil
	local gridFound = if found ~= nil then found:FindFirstChild("Grid") else nil
	local templateFound = if gridFound ~= nil then gridFound:FindFirstChild("CardTemplate") else nil
	if found == nil or not found:IsA("Frame") or gridFound == nil or not gridFound:IsA("ScrollingFrame") or templateFound == nil or not templateFound:IsA("Frame") then
		warn("Collection: LobbyUi.Collection needs Holder.Panel.Grid.CardTemplate; the window stays closed")
		return
	end
	panel = found
	fit = if scale ~= nil and scale:IsA("UIScale") then scale else nil
	grid = gridFound
	template = templateFound
	templateFound.Visible = false
	local progressFound = found:FindFirstChild("Progress")
	progress = if progressFound ~= nil and progressFound:IsA("TextLabel") then progressFound else nil
	local nextFound = found:FindFirstChild("Next")
	nextLine = if nextFound ~= nil and nextFound:IsA("TextLabel") then nextFound else nil
	local searchFound = found:FindFirstChild("Search")
	if searchFound ~= nil and searchFound:IsA("TextBox") then
		search = searchFound
		searchFound:GetPropertyChangedSignal("Text"):Connect(render)
	end
	local closeButton = found:FindFirstChild("CloseButton")
	if closeButton ~= nil and closeButton:IsA("TextButton") then
		Ui.pressable(closeButton)
		closeButton.Activated:Connect(function()
			Sfx.play("Close", 0.5)
			Collection.close()
		end)
	end
	local scrim = screen:FindFirstChild("Scrim")
	if scrim ~= nil and scrim:IsA("GuiButton") then
		scrim.Activated:Connect(Collection.close)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
	screen.Visible = false
	gui = screen
	buildCards()
end

function Collection.init(playerGui: PlayerGui)
	local railButton = Rail.button(RAIL_KEY)
	if railButton ~= nil then
		railButton.Activated:Connect(toggle)
	else
		warn("Collection: the rail has no CollectionButton")
	end
	player:GetAttributeChangedSignal("Playing"):Connect(function()
		if player:GetAttribute("Playing") == true then
			Collection.close()
		end
	end)
	Net.event("CollectionCatalog").OnClientEvent:Connect(onCatalogue)
	Net.event("CollectionCatalog"):FireServer()
	task.spawn(function()
		local found = Ui.screen(playerGui, "Collection", WAIT_SECONDS)
		if found ~= nil then
			bind(found)
		else
			warn("Collection: LobbyUi.Collection is missing; the collection window stays closed")
		end
	end)
end

return Collection
