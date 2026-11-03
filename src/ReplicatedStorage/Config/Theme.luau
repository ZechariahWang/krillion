--!strict
-- Visual tokens shared by the Studio-built UI and map (tools/BuildUi, tools/BuildMap) and the client controllers.

local Theme = {
	Color = {
		Ink = Color3.fromHex("1B2A49"), -- outlines and dark text
		White = Color3.fromHex("FFFFFF"),
		Muted = Color3.fromHex("6B7A99"),
		RowLight = Color3.fromHex("EEF4FC"),
		Blue = Color3.fromHex("2F80ED"),
		Sky = Color3.fromHex("4FC3F7"),
		Green = Color3.fromHex("3DDC6A"),
		Yellow = Color3.fromHex("FFD23F"),
		Orange = Color3.fromHex("FF8C42"),
		Red = Color3.fromHex("FF4D5E"),
		Purple = Color3.fromHex("9B5DE5"),
		Gold = Color3.fromHex("FFC93C"),
		Silver = Color3.fromHex("C7D2E0"),
		Bronze = Color3.fromHex("E09A5B"),
		Grey = Color3.fromHex("A9B4C6"),
		Water = Color3.fromHex("2E9BFF"),
		Wood = Color3.fromHex("B5835A"),
		WoodDark = Color3.fromHex("8A5A3B"),
		Sand = Color3.fromHex("F2DDA4"),
		Leaf = Color3.fromHex("4CC35A"),
	},
	Tier = {
		Plankton = Color3.fromHex("9AA5B1"),
		TooClever = Color3.fromHex("4FC3F7"),
		Schooler = Color3.fromHex("3DDC6A"),
		Rare = Color3.fromHex("9B5DE5"),
		DeepCut = Color3.fromHex("FF8C42"),
		OneInAKrillion = Color3.fromHex("FFC93C"),
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
	Radius = {
		Small = UDim.new(0, 12),
		Large = UDim.new(0, 18),
		Pill = UDim.new(1, 0),
	},
	Stroke = {
		Card = 4,
		Text = 3,
		TextSmall = 2,
	},
	Font = {
		Title = Font.fromEnum(Enum.Font.LuckiestGuy),
		Body = Font.fromEnum(Enum.Font.FredokaOne),
	},
	Tween = {
		Enter = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Exit = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		Pop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Slam = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		Press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Tick = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Count = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Flash = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Float = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	},
}

return table.freeze(Theme)
