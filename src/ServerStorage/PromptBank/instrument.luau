--!strict
return {
	id = "instrument",
	prompt = "Name a musical instrument",
	answers = {
		Plankton = {
			"guitar", "piano", "drums", "violin",
		},
		TooClever = {
			"theremin", "didgeridoo",
		},
		Schooler = {
			"flute", "trumpet", "cello", "saxophone", "clarinet", "harp", "ukulele",
		},
		Rare = {
			"oboe", "bassoon", "banjo", "accordion", "mandolin", "tuba",
		},
		DeepCut = {
			"sitar", "bagpipes", "harpsichord", "marimba", "oud",
		},
		OneInAKrillion = {
			"hurdy gurdy", "nyckelharpa", "shamisen", "erhu", "kora",
		},
	},
	aliases = {
		["bagpipe"] = "bagpipes", ["drum"] = "drums", ["sax"] = "saxophone",
	},
}
