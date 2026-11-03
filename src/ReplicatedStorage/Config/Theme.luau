--!strict
-- Visual tokens shared by the Studio-built UI and map (tools/BuildUi, tools/BuildMap) and the client controllers.
-- UI style: dark translucent navy panels, cream heavy text, small corners, thin aqua accent bars.

local Theme = {
	Color = {
		-- UI
		Panel = Color3.fromHex("0A1420"),
		PanelSolid = Color3.fromHex("101C2B"),
		Row = Color3.fromHex("14202E"),
		Field = Color3.fromHex("050B12"),
		Cream = Color3.fromHex("FFF5DC"),
		Muted = Color3.fromHex("7A8CA0"),
		Accent = Color3.fromHex("3CC8FF"),
		Green = Color3.fromHex("50E07A"),
		Yellow = Color3.fromHex("FFD23F"),
		Red = Color3.fromHex("FF5A5A"),
		Orange = Color3.fromHex("FF9F50"),
		Purple = Color3.fromHex("A97BFF"),
		Gold = Color3.fromHex("FFC24B"),
		Silver = Color3.fromHex("C7D2E0"),
		Bronze = Color3.fromHex("E09A5B"),
		Grey = Color3.fromHex("7A8CA0"),
		-- Map
		Ink = Color3.fromHex("1B2A49"),
		White = Color3.fromHex("FFFFFF"),
		Blue = Color3.fromHex("2F80ED"),
		Sky = Color3.fromHex("4FC3F7"),
		Water = Color3.fromHex("2E9BFF"),
		Wood = Color3.fromHex("B5835A"),
		WoodDark = Color3.fromHex("8A5A3B"),
		Sand = Color3.fromHex("F2DDA4"),
		Leaf = Color3.fromHex("4CC35A"),
	},
	Tier = {
		Plankton = Color3.fromHex("9AA5B1"),
		TooClever = Color3.fromHex("4FC3F7"),
		Schooler = Color3.fromHex("50E07A"),
		Rare = Color3.fromHex("A97BFF"),
		DeepCut = Color3.fromHex("FF9F50"),
		OneInAKrillion = Color3.fromHex("FFC24B"),
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
	Panel = {
		Transparency = 0.25, -- HUD panels over the world
		ModalTransparency = 0.1, -- cards that need to be read
		RowTransparency = 0.3,
	},
	Radius = {
		Small = UDim.new(0, 6),
		Pill = UDim.new(1, 0),
	},
	Font = {
		Body = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold),
		Title = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
		Heavy = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic), -- top status bars
	},
	Shadow = {
		Transparency = 0.5,
		Blur = 20,
	},
	-- Minimal motion: short ease-outs, no overshoot, no bounce.
	Tween = {
		Enter = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Exit = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Press = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Tick = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Nudge = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Count = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Flash = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Float = TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	},
}

return table.freeze(Theme)
