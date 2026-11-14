--!strict
-- Visual tokens the client controllers and server use when they recolour Studio-authored UI and parts.

local Theme = {
	Color = {
		-- UI
		Cream = Color3.fromHex("FFF5DC"),
		Green = Color3.fromHex("50E07A"),
		Yellow = Color3.fromHex("FFD23F"),
		Red = Color3.fromHex("FF5A5A"),
		Orange = Color3.fromHex("FF9F50"),
		Gold = Color3.fromHex("FFC24B"),
		Grey = Color3.fromHex("7A8CA0"),
		-- World
		Ink = Color3.fromHex("1B2A49"),
		White = Color3.fromHex("FFFFFF"),
		Water = Color3.fromHex("2E9BFF"),
		Slate = Color3.fromRGB(110, 116, 128), -- a sunk pillar
	},
	Tier = {
		Plankton = Color3.fromHex("9AA5B1"),
		TooClever = Color3.fromHex("4FC3F7"),
		Schooler = Color3.fromHex("50E07A"),
		Rare = Color3.fromHex("A97BFF"),
		DeepCut = Color3.fromHex("FF9F50"),
		Mythic = Color3.fromHex("FFC24B"),
	},
	-- Shop item rarity (Config/Cosmetics `rarity`): the card frame and the rarity line.
	Rarity = {
		Common = Color3.fromHex("9AA5B1"),
		Rare = Color3.fromHex("4FA8FF"),
		Epic = Color3.fromHex("B46BFF"),
		Legendary = Color3.fromHex("FFB52E"),
		Mythic = Color3.fromHex("FF4FA3"),
	},
	Pillars = {
		Color3.fromHex("FF4D5E"),
		Color3.fromHex("FF8C42"),
		Color3.fromHex("FFD23F"),
		Color3.fromHex("3DDC6A"),
		Color3.fromHex("4FC3F7"),
		Color3.fromHex("2F80ED"),
		Color3.fromHex("9B5DE5"),
		Color3.fromHex("FF7EB6"),
		Color3.fromHex("00C2A8"),
		Color3.fromHex("A3E635"),
		Color3.fromHex("F97316"),
		Color3.fromHex("6366F1"),
	},
	-- Chunky display text for titles, numbers, buttons and callouts; Body for sub-lines and rows.
	Font = {
		Display = Font.new("rbxasset://fonts/families/FredokaOne.json"),
		Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
		Legacy = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold),
	},
	Outline = Color3.fromRGB(10, 20, 40), -- dark navy text outline (UIStroke, Contextual)
	Stroke = { -- outline thickness in pixels
		Title = 3,
		Label = 2,
		Button = 2.5,
	},
	Panel = { -- top and bottom of a panel's gradient fill
		Top = Color3.fromRGB(26, 52, 98),
		Bottom = Color3.fromRGB(13, 28, 60),
		Lip = Color3.fromRGB(7, 15, 36), -- the thin lip band under HUD chips
	},
	Header = { -- coloured header bars
		You = Color3.fromRGB(46, 150, 255),
		Other = Color3.fromRGB(255, 76, 122),
		Quest = Color3.fromRGB(38, 198, 196),
		Reward = Color3.fromRGB(255, 200, 61),
		Results = Color3.fromRGB(150, 96, 255),
		Danger = Color3.fromRGB(255, 84, 84),
		Good = Color3.fromRGB(70, 214, 110),
	},
	-- The chunky toy look for big pop-ups (callouts, revive, results): saturated fills
	-- shaded lighter at the top and darker at the bottom, a hard darker lip band along the bottom edge,
	-- thick dark borders, big corners and big outlined FredokaOne text. Model.json files cannot require
	-- Theme, so the values are spelled out for them:
	--   Outline  #180F34 (UIStroke Border on panels and buttons, Contextual on text)
	--   Border 4 px (panels), 3 px (buttons); text outline 3-4 px; corners 22 px (panels), 14 px (buttons)
	--   Lip: 8 px band on panels, 6 px on buttons, using the colour's Lip value
	--   Pink   #FF7CC0 > #E8378F, lip #A81E63      Purple #A47BFF > #6C3FE6, lip #4423A3
	--   Lime   #9BF25F > #4FC632, lip #2F861C      Gold   #FFD95E > #FFA41F, lip #BF6A06
	--   Sky    #74D4FF > #2E9BFF, lip #1C62B5      Red    #FF8270 > #E83B3B, lip #A11F26
	--   Deep fills: Sea #2F7FE0 > #1A47A0 (lip #10306E), Grape #6A45DB > #3D2394 (lip #28166A),
	--   Berry #D9468F > #932063 (lip #641343)
	Chunky = {
		Outline = Color3.fromHex("180F34"),
		Border = 4,
		ButtonBorder = 3,
		TextStroke = 3.5,
		CalloutStroke = 4.5,
		Corner = 22,
		ButtonCorner = 14,
		Lip = 8,
		ButtonLip = 6,
		Color = {
			Pink = { Top = Color3.fromHex("FF7CC0"), Bottom = Color3.fromHex("E8378F"), Lip = Color3.fromHex("A81E63") },
			Purple = { Top = Color3.fromHex("A47BFF"), Bottom = Color3.fromHex("6C3FE6"), Lip = Color3.fromHex("4423A3") },
			Lime = { Top = Color3.fromHex("9BF25F"), Bottom = Color3.fromHex("4FC632"), Lip = Color3.fromHex("2F861C") },
			Gold = { Top = Color3.fromHex("FFD95E"), Bottom = Color3.fromHex("FFA41F"), Lip = Color3.fromHex("BF6A06") },
			Sky = { Top = Color3.fromHex("74D4FF"), Bottom = Color3.fromHex("2E9BFF"), Lip = Color3.fromHex("1C62B5") },
			Red = { Top = Color3.fromHex("FF8270"), Bottom = Color3.fromHex("E83B3B"), Lip = Color3.fromHex("A11F26") },
			Sea = { Top = Color3.fromHex("2F7FE0"), Bottom = Color3.fromHex("1A47A0"), Lip = Color3.fromHex("10306E") },
			Grape = { Top = Color3.fromHex("6A45DB"), Bottom = Color3.fromHex("3D2394"), Lip = Color3.fromHex("28166A") },
			Berry = { Top = Color3.fromHex("D9468F"), Bottom = Color3.fromHex("932063"), Lip = Color3.fromHex("641343") },
		},
		-- How much bigger than authored each pop-up shows (UIScale), before it is shrunk to fit the screen.
		Grow = {
			Callout = 1.6,
			CoinPop = 1.5,
			Card = 1.5, -- the revive card
			Results = 1.4,
		},
	},
	Depth = { -- the dive card's water window, top to bottom
		Sky = Color3.fromRGB(150, 214, 255),
		Surface = Color3.fromRGB(64, 196, 230),
		Abyss = Color3.fromRGB(8, 6, 26),
	},
	Confetti = {
		Color3.fromRGB(255, 76, 122),
		Color3.fromRGB(255, 200, 61),
		Color3.fromRGB(70, 214, 110),
		Color3.fromRGB(46, 150, 255),
		Color3.fromRGB(150, 96, 255),
		Color3.fromRGB(38, 198, 196),
	},
	-- Short ease-outs. Only Pop (and its Bounce/Stamp variants) overshoot, and those are kept for
	-- reward moments: the reveal, rare tiers, wins.
	Tween = {
		Enter = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Pop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Bounce = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), -- same curve as Pop
		Stamp = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Exit = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Press = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Tick = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Nudge = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Count = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Flash = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Float = TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Boing = TweenInfo.new(0.7, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), -- coin pops only
		Hop = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), -- big pop-up entrances
	},
}

return table.freeze(Theme)
