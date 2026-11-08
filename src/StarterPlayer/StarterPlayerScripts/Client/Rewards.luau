--!strict
-- Drives StarterGui.Rewards: free rewards for joining the group and inviting friends, plus an unrewarded
-- FAVORITE nudge, as a big chunky panel. Opened from the rail's REWARDS key and from reward items in the shop.
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
local Theme = require(ReplicatedStorage.Config.Theme)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local RewardRules = require(ReplicatedStorage.Shared.Rewards)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)

local WAIT_SECONDS = 10
local MARGIN = 16 -- pixels kept clear around the panel when it is scaled down for a small screen
local MIN_FIT = 0.4
local PORTRAIT_BELOW = 0.7 -- the wide layout shows smaller than this: use the tall phone one if it shows bigger
local PORTRAIT_SIZE = UDim2.fromOffset(460, 876)
local PORTRAIT_ROW = 222 -- a portrait row stacks its button under the text
local ROW_NAMES = { "GroupRow", "InviteRow", "FavoriteRow" }
local CHECK_TIMEOUT = 35 -- the server re-checks membership for about 30 s; after this the button resets
local GROUP_ID = GameConfig.Rewards.GroupId
local INVITE_MESSAGE = "Come dive with me in Krillion! Give the rarest answers to stay above the water."
-- The nudge waits for a calm moment so it never lands on the results or the reveal.
local CALM_PHASES: { [string]: boolean } = { Waiting = true, Intermission = true }

type Swatch = { Top: Color3, Bottom: Color3, Lip: Color3 }

-- Repaints a chunky face (white, coloured by its gradient) with a Theme.Chunky swatch, keeping the height
-- of the lip band authored in Studio.
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
local layout: Ui.PhoneLayout? = nil
local rows: { [string]: Row } = {}

local claimed: { [string]: boolean } = {}
local referrals = 0
local firstGames: number? = nil -- profile.games when this session started
local games = 0
local playing = false
local phase = "Waiting"
local isOpen = false

local joining = false -- PromptJoinAsync is up
local checking = false -- RewardClaim sent; waiting for the server's verdict
local requested = false -- the group takes join requests and ours is waiting
local favoriteShown = false -- the favorite prompt worked and was answered this session
local favoriteBroken = false -- PromptSetFavorite errored; fall back to pointing at the game page
local nudged = false

local Rewards = {}

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

-- Shrinks the panel on small screens instead of letting it run off the edge; a portrait phone gets the tall
-- layout so the row text stays readable.
local function fitToScreen()
	local screen = gui
	local frame = panel
	local scale = fit
	if screen == nil or frame == nil or scale == nil then
		return
	end
	Ui.fitPanel(screen.AbsoluteSize, frame, scale, layout, MARGIN, MIN_FIT, PORTRAIT_BELOW)
end

-- Portrait phone layout: narrow and tall, each row's button full width under its text, bigger small print.
local function portraitOverrides(): Ui.Overrides
	local overrides: Ui.Overrides = {
		Rows = { Size = UDim2.new(1, -48, 0, PORTRAIT_ROW * #ROW_NAMES + 14 * (#ROW_NAMES - 1)) },
		LikeLine = {
			Position = UDim2.new(0, 24, 1, -62),
			Size = UDim2.new(1, -48, 0, 50),
			TextWrapped = true,
		},
	}
	for _, name in ROW_NAMES do
		local path = "Rows/" .. name
		overrides[path] = { Size = UDim2.new(1, 0, 0, PORTRAIT_ROW) }
		overrides[path .. "/IconBack"] = {
			Size = UDim2.fromOffset(76, 76),
			Position = UDim2.fromOffset(14, 12),
			AnchorPoint = Vector2.zero,
		}
		overrides[path .. "/Title"] = { Position = UDim2.fromOffset(102, 10), Size = UDim2.new(1, -116, 0, 34) }
		overrides[path .. "/Sub"] = {
			Position = UDim2.fromOffset(102, 46),
			Size = UDim2.new(1, -116, 0, 70),
			TextSize = 20,
		}
		overrides[path .. "/Progress"] = {
			Position = UDim2.fromOffset(16, 118),
			Size = UDim2.new(1, -32, 0, 24),
			TextSize = 20,
		}
		overrides[path .. "/Button"] = {
			Size = UDim2.new(1, -32, 0, 64),
			Position = UDim2.new(0.5, 0, 1, -12),
			AnchorPoint = Vector2.new(0.5, 1),
		}
	end
	return overrides
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
	Rail.setBadge("RewardsButton", if groupDone or GROUP_ID == 0 then nil else "!")

	local group = rows.Group
	if group ~= nil then
		group.frame.Visible = GROUP_ID ~= 0
		if group.sub ~= nil then
			local grant = RewardRules.groupGrant()
			group.sub.Text = string.format(
				"Get the %s + %s %s",
				itemNames(RewardRules.Group),
				Currency.digits(grant.shells),
				Theme.Icon.Shell
			)
		end
		setRowBadge(group, not groupDone and not checking and not joining)
		if groupDone then
			setButton(group, "CLAIMED", false)
			setProgress(group, Theme.Icon.Check .. " WELCOME TO THE CREW")
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
			setProgress(invite, Theme.Icon.Check .. " ALL INVITE REWARDS UNLOCKED")
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
	Toasts.show("ENJOYING KRILLION? ⭐ FAVORITE IT SO YOU CAN FIND IT AGAIN", "info")
end

local function close()
	local screen = gui
	if screen == nil or not isOpen then
		return
	end
	isOpen = false
	screen.Visible = false
	Rail.panelClosed(close)
end

local function bindRow(container: Instance, key: string, name: string, onClick: () -> ())
	local frame = container:FindFirstChild(name)
	if frame == nil or not frame:IsA("Frame") then
		warn("Rewards: StarterGui.Rewards row " .. name .. " is missing")
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

local function bind(screen: Frame)
	local holder = screen:WaitForChild("Holder", WAIT_SECONDS)
	local found = if holder ~= nil then holder:WaitForChild("Panel", WAIT_SECONDS) else nil
	if holder == nil or found == nil or not found:IsA("Frame") then
		warn("Rewards: StarterGui.Rewards.Holder.Panel is missing; the rewards panel stays closed")
		return
	end
	local scale = holder:FindFirstChild("Fit")
	fit = if scale ~= nil and scale:IsA("UIScale") then scale else nil
	panel = found
	local list = found:WaitForChild("Rows", WAIT_SECONDS)
	if list ~= nil then
		bindRow(list, "Group", "GroupRow", onGroup)
		bindRow(list, "Invite", "InviteRow", onInvite)
		bindRow(list, "Favorite", "FavoriteRow", onFavorite)
	end
	layout = Ui.phoneLayout(found, PORTRAIT_SIZE, portraitOverrides())
	local closeButton = found:FindFirstChild("CloseButton")
	if closeButton ~= nil and closeButton:IsA("TextButton") then
		Ui.pressable(closeButton)
		closeButton.Activated:Connect(function()
			Sfx.play("Close", 0.5)
			close()
		end)
	end
	-- Tapping outside the panel closes it.
	local scrim = screen:FindFirstChild("Scrim")
	if scrim ~= nil and scrim:IsA("GuiButton") then
		scrim.Activated:Connect(close)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
	gui = screen
	render()
end

function Rewards.init(playerGui: PlayerGui)
	local railButton = Rail.button("RewardsButton")
	if railButton ~= nil then
		railButton.Activated:Connect(Rewards.open)
	end
	pcall(function()
		AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
			if result == Enum.AvatarPromptResult.Success then
				favoriteShown = true
				Toasts.show("THANKS FOR THE FAVORITE!", "good")
				render()
			end
		end)
	end)
	render()
	task.spawn(function()
		local found = Ui.screen(playerGui, "Rewards", WAIT_SECONDS)
		if found == nil or not found:IsA("Frame") then
			warn("Rewards: StarterGui.Rewards is missing; the rewards panel stays closed")
			return
		end
		bind(found)
	end)
end

-- ProfileChanged payload: claimed, referrals, games.
function Rewards.onProfile(profile)
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
		close()
	end
	maybeNudge()
end

-- Opens the rewards panel (ShopUi calls this for "FREE: JOIN GROUP" items). Never over a pillar.
function Rewards.open()
	local screen = gui
	local frame = panel
	if screen == nil or frame == nil or playing then
		return
	end
	render()
	fitToScreen()
	screen.Visible = true
	if not isOpen then
		isOpen = true
		Sfx.play("Open", 0.5)
		Ui.pop(frame, 0.7)
	end
	Rail.panelOpened(close)
end

return Rewards
