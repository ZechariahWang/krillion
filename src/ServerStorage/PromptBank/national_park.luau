--!strict
return {
	id = "national_park",
	prompt = "Name a US national park",
	answers = {
		Plankton = {
			"yellowstone", "yosemite", "grand canyon", "zion", "great smoky mountains",
		},
		TooClever = {
			"glacier", "arches", "acadia", "death valley", "grand teton",
		},
		Schooler = {
			"joshua tree", "bryce canyon", "rocky mountain", "olympic", "mount rainier", "sequoia", "redwood",
			"everglades", "denali", "badlands", "shenandoah", "crater lake", "carlsbad caverns", "hawaii volcanoes",
			"big bend", "mesa verde", "mammoth cave", "kings canyon", "petrified forest", "white sands",
		},
		Rare = {
			"capitol reef", "great basin", "great sand dunes", "theodore roosevelt", "isle royale", "dry tortugas",
			"hot springs", "north cascades", "lassen volcanic", "katmai", "kenai fjords", "gateway arch", "saguaro",
			"channel islands", "glacier bay", "canyonlands", "haleakala",
		},
		DeepCut = {
			"american samoa", "congaree", "pinnacles", "guadalupe mountains", "new river gorge", "virgin islands",
			"biscayne", "indiana dunes", "cuyahoga valley", "black canyon of the gunnison", "wind cave", "voyageurs",
		},
		Mythic = {
			"kobuk valley", "lake clark", "gates of the arctic", "wrangell st elias",
		},
	},
	aliases = {
		["yellow stone"] = "yellowstone", ["yosemity"] = "yosemite", ["yosemite valley"] = "yosemite",
		["the grand canyon"] = "grand canyon", ["smokies"] = "great smoky mountains",
		["smoky mountains"] = "great smoky mountains", ["great smokey mountains"] = "great smoky mountains",
		["smokey mountains"] = "great smoky mountains", ["glacier national park"] = "glacier",
		["arches national park"] = "arches", ["tetons"] = "grand teton", ["the tetons"] = "grand teton",
		["teton"] = "grand teton", ["rockies"] = "rocky mountain", ["rocky mountains"] = "rocky mountain",
		["rainier"] = "mount rainier", ["mt rainier"] = "mount rainier", ["sequoias"] = "sequoia",
		["redwoods"] = "redwood", ["redwood forest"] = "redwood", ["everglade"] = "everglades",
		["carlsbad"] = "carlsbad caverns", ["carlsbad cavern"] = "carlsbad caverns", ["bryce"] = "bryce canyon",
		["joshua trees"] = "joshua tree", ["mesa verd"] = "mesa verde", ["haleakala crater"] = "haleakala",
		["volcanoes"] = "hawaii volcanoes", ["lassen"] = "lassen volcanic", ["new river"] = "new river gorge",
		["black canyon"] = "black canyon of the gunnison", ["great sand dune"] = "great sand dunes",
		["tortugas"] = "dry tortugas", ["mammoth caves"] = "mammoth cave", ["wrangell"] = "wrangell st elias",
		["gates of arctic"] = "gates of the arctic", ["grand tetons"] = "grand teton",
		["olympic national park"] = "olympic", ["badland"] = "badlands", ["denali park"] = "denali",
		["mount mckinley"] = "denali", ["mckinley"] = "denali",
		["theodore roosevelt national park"] = "theodore roosevelt", ["roosevelt"] = "theodore roosevelt",
	},
}
