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
