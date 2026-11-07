--!strict
return {
	id = "ocean_animal",
	prompt = "Name an animal that lives in the ocean",
	answers = {
		Plankton = {
			"shark", "whale", "dolphin", "fish", "octopus",
		},
		TooClever = {
			"blobfish", "anglerfish",
		},
		Schooler = {
			"jellyfish", "turtle", "crab", "seal", "squid", "starfish", "lobster",
		},
		Rare = {
			"manta ray", "seahorse", "eel", "walrus", "stingray", "clownfish",
		},
		DeepCut = {
			"narwhal", "nautilus", "cuttlefish", "dugong", "sea cucumber",
		},
		OneInAKrillion = {
			"vampire squid", "oarfish", "coelacanth", "sea pig", "siphonophore",
		},
	},
	aliases = {
		["orca"] = "whale", ["ray"] = "manta ray", ["seastar"] = "starfish",
	},
}
