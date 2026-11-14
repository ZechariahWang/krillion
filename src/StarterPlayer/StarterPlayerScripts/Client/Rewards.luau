--!strict
-- Drives LobbyUi.Rewards: the one REWARDS window, opened from the rail's REWARDS key, with a Daily, a Quests
-- and a Rewards tab. This module owns the window (fit, open and close, the tabs, their badges and the rail
-- key's badge) and draws the Rewards page: free rewards for joining the group and inviting friends, plus an
-- unrewarded FAVORITE nudge. Reward items in the shop open that page.
-- Client/Daily and Client/Quests draw the other two pages: each takes its page from Rewards.page, marks its
-- tab with Rewards.setTabBadge and redraws from Rewards.onShow. They require this module, so it must never
-- require them.
-- Row buttons keep their text on a child Label (the button itself carries the thick border); the group row's
-- button shows a "!" badge while that reward is waiting.
-- The server (RewardService) verifies and grants everything; this only prompts and shows progress.
-- Liking has no API and favoriting cannot be verified, so neither ever pays (Roblox rules).

local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local RewardRules = require(ReplicatedStorage.Shared.Rewards)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local WAIT_SECONDS = 10
local MARGIN = 16 -- pixels kept clear around the panel when it is scaled down for a small screen
local MIN_FIT = 0.4
local RAIL_KEY = "RewardsButton"
-- The pages under Panel.Pages; each tab key names one in its `Page` attribute.
local PAGES = { "Daily", "Quests", "Rewards" }
local UNLIT_TRANSPARENCY = 0.75 -- a tab that is not showing fades its face, like an unlit shop section key
local CHECK_TIMEOUT = 35 -- the server re-checks membership for about 30 s; after this the button resets
local GROUP_ID = GameConfig.Rewards.GroupId
local INVITE_MESSAGE = "Come dive with me in Rare or Sink! Give the rarest answers to stay above the water."
-- The nudge waits for a calm moment so it never lands on the results or the reveal.
local CALM_PHASES: { [string]: boolean } = { Waiting = true, Intermission = true }

type Swatch = { Top: Color3, Bottom: Color3, Lip: Color3 }

-- Repaints a chunky face (white, coloured by its gradient) with a swatch, keeping the height of the lip band
-- authored in Studio.
local function paint(gradient: UIGradient, swatch: Swatch)
	local points = gradient.Color.Keypoints
	local edge = if #points >= 4 then points[3].Time else 0.9
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, swatch.Top),
		ColorSequenceKeypoint.new(math.max(edge - 0.01, 0), swatch.Bottom),
		ColorSequenceKeypoint.new(edge, swatch.Lip),
		ColorSequenceKeypoint.new(1, swatch.Lip),
	})
end

-- A used-up button is repainted grey; its authored colours come back when it is clickable again.
local DONE_SWATCH: Swatch = {
	Top = Color3.fromRGB(194, 200, 218),
	Bottom = Color3.fromRGB(143, 152, 180),
	Lip = Color3.fromRGB(93, 101, 132),
}

local player = Players.LocalPlayer

type Tab = {
	button: TextButton,
	lip: UIGradient?, -- the lit face
	badge: TextLabel?,
}

type Row = {
	frame: Frame,
	sub: TextLabel?,
	progress: TextLabel?,
	button: TextButton?,
	label: TextLabel?, -- the button's text
	badge: GuiObject?, -- the "!" on the button, if it has one
	face: UIGradient?, -- the button's Lip gradient, which carries its colour
	colors: ColorSequence?, -- the face's authored colours, restored when it is clickable again
}

local gui: Frame? = nil
local fit: UIScale? = nil
local panel: Frame? = nil
local pages: { [string]: GuiObject } = {}
local tabs: { [string]: Tab } = {}
local rows: { [string]: Row } = {}
local bound = false -- the window lookups are over, whether or not they found it

local opened = false
local current: string? = nil -- the page showing
-- Each tab's badge text. Kept here so a badge set before the window is bound still shows.
local badges: { [string]: string? } = {}
local showCallbacks: { [string]: { () -> () } } = {}

local claimed: { [string]: boolean } = {}
local referrals = 0
local firstGames: number? = nil -- profile.games when this session started
local games = 0
local playing = false
local phase = "Waiting"

local joining = false -- PromptJoinAsync is up
local checking = false -- RewardClaim sent; waiting for the server's verdict
local requested = false -- the group takes join requests and ours is waiting
local favoriteShown = false -- the favorite prompt worked and was answered this session
local favoriteBroken = false -- PromptSetFavorite errored; fall back to pointing at the game page
local nudged = false

local Rewards = {}

-- The window -----------------------------------------------------------------------------------------------

-- Shrinks the panel on small screens instead of letting it run off the edge.
local function fitToScreen()
	local screen = gui
	local frame = panel
	local scale = fit
	if screen == nil or frame == nil or scale == nil then
		return
	end
	Ui.fitPanel(screen.AbsoluteSize, frame, scale, nil, MARGIN, MIN_FIT, 0)
end

local function drawBadge(name: string)
	local tab = tabs[name]
	local badge = if tab ~= nil then tab.badge else nil
	if badge == nil then
		return
	end
	local text = badges[name]
	if text == nil then
		badge.Visible = false
		return
	end
	badge.Text = text
	if not badge.Visible then
		Ui.pop(badge)
	end
end

-- The rail key carries one badge for all three tabs, in the order a plain open picks its tab: "!" while a
-- daily claim waits, else the Quests count, else the "!" of the group reward. So a reward that is never
-- claimed does not hide the other two.
local profileSeen = false -- a profile that loaded has arrived

local function railBadge(): string?
	if badges.Daily == "!" then
		return "!"
	end
	return badges.Quests or badges.Rewards
end

-- Shows a badge on a tab ("!" or "1/3"); nil hides it. The rail key's badge follows.
function Rewards.setTabBadge(tab: string, text: string?)
	badges[tab] = text
	drawBadge(tab)
	Rail.setBadge(RAIL_KEY, railBadge())
end

-- Calls `callback` whenever this tab's page becomes the one showing in the open window, opening included.
function Rewards.onShow(tab: string, callback: () -> ())
	local callbacks = showCallbacks[tab] or {}
	showCallbacks[tab] = callbacks
	table.insert(callbacks, callback)
end

-- Whether the window is open; with a tab, whether it is open on that tab's page.
function Rewards.isOpen(tab: string?): boolean
	return opened and (tab == nil or tab == current)
end

-- A tab's page frame ("Daily", "Quests" or "Rewards"), for the controller that draws it. Yields until the
-- window is bound, WAIT_SECONDS at most; nil when the page is not there.
function Rewards.page(name: string): GuiObject?
	local deadline = os.clock() + WAIT_SECONDS
	while not bound and os.clock() < deadline do
		task.wait()
	end
	return pages[name]
end

local function setTabLit(tab: Tab, lit: boolean)
	local lip = tab.lip
	if lip ~= nil then
		lip.Enabled = lit
	end
	tab.button.BackgroundTransparency = if lit then 0 else UNLIT_TRANSPARENCY
end

-- Shows one page, lights its tab and lets the page's owner redraw it.
local function showPage(name: string)
	current = name
	for pageName, page in pages do
		page.Visible = pageName == name
	end
	for pageName, tab in tabs do
		setTabLit(tab, pageName == name)
	end
	local callbacks = showCallbacks[name]
	if callbacks ~= nil then
		for _, callback in callbacks do
			callback()
		end
	end
end

-- The tab a plain open lands on: a daily claim that is waiting, then unfinished quests, then the free
-- rewards. The tab badges say which: Daily carries "!" while a claim waits, Quests a count until all are done.
local function defaultTab(): string?
	if badges.Daily == "!" and pages.Daily ~= nil then
		return "Daily"
	end
	if badges.Quests ~= nil and pages.Quests ~= nil then
		return "Quests"
	end
	if pages.Rewards ~= nil then
		return "Rewards"
	end
	-- No Rewards page: whichever page is there.
	return (next(pages))
end

function Rewards.close()
	local screen = gui
	if screen == nil or not opened then
		return
	end
	opened = false
	screen.Visible = false
	Windows.closed(Rewards.close)
end

-- Opens the window on a tab ("Daily", "Quests" or "Rewards"), or on the one with something to do when none
-- is given. Never over a pillar: the match comes first.
function Rewards.open(tab: string?)
	local screen = gui
	local frame = panel
	if screen == nil or frame == nil or playing or player:GetAttribute("Playing") == true then
		return
	end
	local name = if tab ~= nil and pages[tab] ~= nil then tab else defaultTab()
	if name == nil then
		return
	end
	fitToScreen()
	screen.Visible = true
	if not opened then
		opened = true
		Sfx.play("Open", 0.5)
		Ui.pop(frame, 0.7)
	end
	showPage(name)
	Windows.opened(Rewards.close)
end

local function toggle()
	if opened then
		Sfx.play("Close", 0.5)
		Rewards.close()
	else
		Rewards.open()
	end
end

-- The Rewards page -----------------------------------------------------------------------------------------

local function itemNames(reward: string): string
	local names = {}
	for _, id in RewardRules.itemsFor(reward) do
		local item = Cosmetics.ById[id]
		if item ~= nil then
			table.insert(names, string.upper(item.name) .. " " .. string.lower(item.slot))
		end
	end
	return table.concat(names, " + ")
end

local function setButton(row: Row?, text: string, enabled: boolean)
	local button = if row ~= nil then row.button else nil
	if row == nil or button == nil then
		return
	end
	local label = row.label
	if label ~= nil then
		label.Text = text
	else
		button.Text = text
	end
	button.Active = enabled
	local face = row.face
	local colors = row.colors
	if face ~= nil and colors ~= nil then
		if enabled then
			face.Color = colors
		else
			paint(face, DONE_SWATCH)
		end
	end
end

local function setRowBadge(row: Row?, show: boolean)
	local badge = if row ~= nil then row.badge else nil
	if badge == nil or badge.Visible == show then
		return
	end
	if show then
		Ui.pop(badge, 0.5)
	else
		badge.Visible = false
	end
end

local function setProgress(row: Row?, text: string?)
	local label = if row ~= nil then row.progress else nil
	if label == nil then
		return
	end
	label.Visible = text ~= nil
	if text ~= nil then
		label.Text = text
	end
end

local function render()
	local groupDone = claimed[RewardRules.Group] == true
	-- No badge until the real profile is in: before it, nothing is known to be unclaimed.
	Rewards.setTabBadge("Rewards", if profileSeen and not groupDone and GROUP_ID ~= 0 then "!" else nil)

	local group = rows.Group
	if group ~= nil then
		group.frame.Visible = GROUP_ID ~= 0
		if group.sub ~= nil then
			local grant = RewardRules.groupGrant()
			group.sub.Text = string.format(
				"Get the %s + %s %s",
				itemNames(RewardRules.Group),
				Currency.digits(grant.shells),
				Currency.Upper
			)
		end
		setRowBadge(group, not groupDone and not checking and not joining)
		if groupDone then
			setButton(group, "CLAIMED", false)
			setProgress(group, "WELCOME TO THE CREW")
		elseif checking then
			setButton(group, "CHECKING...", false)
			setProgress(group, nil)
		elseif joining then
			setButton(group, "...", false)
		elseif requested then
			setButton(group, "CLAIM", true)
			setProgress(group, "REQUEST SENT: CLAIM ONCE ACCEPTED")
		else
			setButton(group, "JOIN", true)
			setProgress(group, nil)
		end
	end

	local invite = rows.Invite
	if invite ~= nil then
		if invite.sub ~= nil then
			invite.sub.Text = string.format(
				"%d friend = %s, %d = %s. Counts once they finish a match.",
				GameConfig.Rewards.ReferralTier1,
				itemNames(RewardRules.Referral1),
				GameConfig.Rewards.ReferralTier2,
				itemNames(RewardRules.Referral3)
			)
		end
		local goal = RewardRules.nextGoal(referrals)
		if goal ~= nil then
			setProgress(invite, string.format("%d / %d FRIENDS", referrals, goal))
		else
			setProgress(invite, "ALL INVITE REWARDS UNLOCKED")
		end
		setButton(invite, "INVITE", true)
	end

	local favorite = rows.Favorite
	if favorite ~= nil then
		local button = favorite.button
		if favoriteBroken then
			if button ~= nil then
				button.Visible = false
			end
			if favorite.sub ~= nil then
				favorite.sub.Text = "Tap the star on the game page so you can find it again."
			end
		elseif favoriteShown then
			setButton(favorite, "THANKS!", false)
		end
	end
end

local function claimGroup()
	checking = true
	render()
	Net.event("RewardClaim"):FireServer(RewardRules.Group)
	task.delay(CHECK_TIMEOUT, function()
		if checking and claimed[RewardRules.Group] ~= true then
			checking = false
			render()
		end
	end)
end

local function onGroup()
	if joining or checking or claimed[RewardRules.Group] == true or GROUP_ID == 0 then
		return
	end
	joining = true
	render()
	task.spawn(function()
		local ok, result = pcall(function()
			return GroupService:PromptJoinAsync(GROUP_ID)
		end)
		joining = false
		local status = if ok and typeof(result) == "EnumItem" then result.Name else nil
		if status == "Joined" or status == "AlreadyMember" then
			Sfx.play("Coin", 0.5)
			claimGroup()
			return
		elseif status == "JoinRequestPending" then
			requested = true
			Toasts.show("JOIN REQUEST SENT! TAP CLAIM ONCE YOU'RE ACCEPTED", "info")
		elseif not ok then
			-- No prompt here (older client, error): the server can still see a membership made elsewhere.
			claimGroup()
			return
		end
		render()
	end)
end

local function onInvite()
	task.spawn(function()
		local ok, canSend = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if not ok or canSend ~= true then
			Toasts.show("INVITES AREN'T AVAILABLE ON THIS ACCOUNT RIGHT NOW", "bad")
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = INVITE_MESSAGE
		local sent, err = pcall(function()
			SocialService:PromptGameInvite(player, options)
		end)
		if not sent then
			warn("Rewards: invite prompt failed: " .. tostring(err))
			Toasts.show("INVITES AREN'T AVAILABLE ON THIS ACCOUNT RIGHT NOW", "bad")
		end
	end)
end

local function onFavorite()
	-- Documented for avatar items; on the place it may not work everywhere, so a failure only hides the button.
	local ok = pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
	if not ok then
		favoriteBroken = true
		render()
	end
end

local function maybeNudge()
	if firstGames == nil or playing or not CALM_PHASES[phase] or favoriteShown or favoriteBroken then
		return
	end
	if not RewardRules.favoriteNudgeDue(games - (firstGames :: number), nudged) then
		return
	end
	nudged = true
	Toasts.show("ENJOYING RARE OR SINK? FAVORITE IT SO YOU CAN FIND IT AGAIN", "info")
end

-- Binding --------------------------------------------------------------------------------------------------

local function bindRow(container: Instance, key: string, name: string, onClick: () -> ())
	local frame = container:FindFirstChild(name)
	if frame == nil or not frame:IsA("Frame") then
		warn("Rewards: the Rewards page has no row " .. name)
		return
	end
	local sub = frame:FindFirstChild("Sub")
	local progress = frame:FindFirstChild("Progress")
	local button = frame:FindFirstChild("Button")
	local label = if button ~= nil then button:FindFirstChild("Label") else nil
	local badge = if button ~= nil then button:FindFirstChild("Badge") else nil
	local lip = if button ~= nil then button:FindFirstChild("Lip") else nil
	local face = if lip ~= nil and lip:IsA("UIGradient") then lip else nil
	local row: Row = {
		frame = frame,
		sub = if sub ~= nil and sub:IsA("TextLabel") then sub else nil,
		progress = if progress ~= nil and progress:IsA("TextLabel") then progress else nil,
		button = if button ~= nil and button:IsA("TextButton") then button else nil,
		label = if label ~= nil and label:IsA("TextLabel") then label else nil,
		badge = if badge ~= nil and badge:IsA("GuiObject") then badge else nil,
		face = face,
		colors = if face ~= nil then face.Color else nil,
	}
	rows[key] = row
	local clickable = row.button
	if clickable ~= nil then
		Ui.pressable(clickable)
		clickable.Activated:Connect(function()
			if clickable.Active then
				Sfx.play("Pop", 0.4)
				onClick()
			end
		end)
	end
end

-- The tab keys are the TextButtons under Panel.Tabs; each one's `Page` attribute names the page it shows.
local function bindTabs(frame: Instance)
	for _, child in frame:GetChildren() do
		local name = child:GetAttribute("Page")
		if child:IsA("TextButton") and type(name) == "string" then
			if pages[name] == nil then
				warn(`Rewards: the tab {child.Name} names the page "{name}", which is missing`)
				continue
			end
			local lip = child:FindFirstChild("Lip")
			local badge = child:FindFirstChild("Badge")
			tabs[name] = {
				button = child,
				lip = if lip ~= nil and lip:IsA("UIGradient") then lip else nil,
				badge = if badge ~= nil and badge:IsA("TextLabel") then badge else nil,
			}
			Ui.pressable(child)
			child.Activated:Connect(function()
				Sfx.play("Pop", 0.4)
				showPage(name)
			end)
			drawBadge(name)
		end
	end
end

local function bind(screen: Frame)
	local holder = screen:WaitForChild("Holder", WAIT_SECONDS)
	local found = if holder ~= nil then holder:WaitForChild("Panel", WAIT_SECONDS) else nil
	if holder == nil or found == nil or not found:IsA("Frame") then
		warn("Rewards: LobbyUi.Rewards.Holder.Panel is missing; the rewards window stays closed")
		return
	end
	local pageHolder = found:WaitForChild("Pages", WAIT_SECONDS)
	if pageHolder ~= nil then
		for _, name in PAGES do
			local page = pageHolder:FindFirstChild(name)
			if page ~= nil and page:IsA("GuiObject") then
				pages[name] = page
			else
				warn(`Rewards: LobbyUi.Rewards has no page {name}; its tab stays empty`)
			end
		end
	end
	if next(pages) == nil then
		warn("Rewards: LobbyUi.Rewards.Holder.Panel.Pages is missing or empty; the rewards window stays closed")
		return
	end
	local scale = holder:FindFirstChild("Fit")
	fit = if scale ~= nil and scale:IsA("UIScale") then scale else nil
	panel = found
	local ownPage = pages.Rewards
	local list = if ownPage ~= nil then ownPage:FindFirstChild("Rows") else nil
	if list ~= nil then
		bindRow(list, "Group", "GroupRow", onGroup)
		bindRow(list, "Invite", "InviteRow", onInvite)
		bindRow(list, "Favorite", "FavoriteRow", onFavorite)
	elseif ownPage ~= nil then
		warn("Rewards: the Rewards page has no Rows")
	end
	local tabHolder = found:FindFirstChild("Tabs")
	if tabHolder ~= nil then
		bindTabs(tabHolder)
	end
	for _, name in PAGES do
		if pages[name] ~= nil and tabs[name] == nil then
			warn(`Rewards: the page {name} has no tab key under Panel.Tabs`)
		end
	end
	local closeButton = found:FindFirstChild("CloseButton")
	if closeButton ~= nil and closeButton:IsA("TextButton") then
		Ui.pressable(closeButton)
		closeButton.Activated:Connect(function()
			Sfx.play("Close", 0.5)
			Rewards.close()
		end)
	end
	-- Tapping outside the panel closes it.
	local scrim = screen:FindFirstChild("Scrim")
	if scrim ~= nil and scrim:IsA("GuiButton") then
		scrim.Activated:Connect(Rewards.close)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
	screen.Visible = false
	gui = screen
	render()
end

function Rewards.init(playerGui: PlayerGui)
	local railButton = Rail.button(RAIL_KEY)
	if railButton ~= nil then
		railButton.Activated:Connect(toggle)
	else
		warn("Rewards: the rail has no RewardsButton; the rewards window only opens by itself")
	end
	player:GetAttributeChangedSignal("Playing"):Connect(function()
		if player:GetAttribute("Playing") == true then
			Rewards.close()
		end
	end)
	pcall(function()
		AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
			if result == Enum.AvatarPromptResult.Success then
				favoriteShown = true
				Toasts.show("THANKS FOR THE FAVORITE!", "good")
				render()
			end
		end)
	end)
	Rewards.onShow("Rewards", render)
	render()
	task.spawn(function()
		local found = Ui.screen(playerGui, "Rewards", WAIT_SECONDS)
		if found ~= nil then
			bind(found)
		else
			warn("Rewards: LobbyUi.Rewards is missing; the rewards window stays closed")
		end
		bound = true
	end)
end

-- ProfileChanged payload: claimed, referrals, games.
function Rewards.onProfile(profile)
	profileSeen = profile.loadFailed ~= true
	if typeof(profile.claimed) == "table" then
		claimed = profile.claimed
	end
	if typeof(profile.referrals) == "number" then
		referrals = profile.referrals
	end
	if typeof(profile.games) == "number" then
		games = profile.games
		if firstGames == nil then
			firstGames = games
		end
	end
	if claimed[RewardRules.Group] == true then
		checking = false
		requested = false
	end
	render()
	maybeNudge()
end

function Rewards.onState(payload)
	playing = payload.playing == true
	phase = payload.phase
	if playing then
		Rewards.close()
	end
	maybeNudge()
end

return Rewards
