--!strict
-- Visual tokens shared by the Studio-built UI (via tools/BuildUi) and the client controllers.

local Theme = {
	Color = {
		Navy = Color3.fromHex("0B1E3F"),
		Surface = Color3.fromHex("16305E"),
		SurfaceLight = Color3.fromHex("1F3F78"),
		Accent = Color3.fromHex("4DA3FF"),
		Water = Color3.fromHex("1E5BFF"),
		Text = Color3.fromHex("FFFFFF"),
		TextDim = Color3.fromHex("B8C7E0"),
		Danger = Color3.fromHex("FF5C5C"),
		Gold = Color3.fromHex("FFD166"),
	},
	Tier = {
		Plankton = Color3.fromHex("8FA3BF"),
		TooClever = Color3.fromHex("7CC4FF"),
		Schooler = Color3.fromHex("4DA3FF"),
		Rare = Color3.fromHex("8B7CFF"),
		DeepCut = Color3.fromHex("FF8A5C"),
		OneInAKrillion = Color3.fromHex("FFD166"),
	},
	Radius = {
		Small = UDim.new(0, 10),
		Large = UDim.new(0, 16),
		Pill = UDim.new(1, 0),
	},
	Stroke = {
		Thickness = 1.5,
		Transparency = 0.8,
	},
	Panel = {
		Transparency = 0.2,
	},
	Font = {
		Regular = Font.fromEnum(Enum.Font.BuilderSans),
		Medium = Font.fromEnum(Enum.Font.BuilderSansMedium),
		Bold = Font.fromEnum(Enum.Font.BuilderSansBold),
		Black = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
	},
	Tween = {
		Enter = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Exit = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		Pop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Press = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Pulse = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		Count = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	},
}

return table.freeze(Theme)
