--!strict
return {
	id = "canadian_city",
	prompt = "Name a city in Canada",
	answers = {
		Plankton = {
			"toronto", "vancouver", "montreal", "ottawa", "calgary", "edmonton",
		},
		TooClever = {
			"quebec city", "winnipeg", "victoria", "halifax",
		},
		Schooler = {
			"hamilton", "mississauga", "regina", "saskatoon", "niagara falls", "kingston", "london", "windsor", "st johns",
			"kelowna", "brampton", "surrey", "burnaby", "oshawa", "waterloo", "kitchener", "whitehorse", "yellowknife",
			"fredericton", "charlottetown", "moncton", "thunder bay",
		},
		Rare = {
			"laval", "gatineau", "sherbrooke", "barrie", "guelph", "kamloops", "nanaimo", "lethbridge", "red deer", "sudbury",
			"saint john", "trois rivieres", "markham", "vaughan", "abbotsford", "saanich", "medicine hat", "brantford",
			"peterborough", "cambridge", "burlington", "oakville", "iqaluit", "sault ste marie", "north bay", "kenora",
			"prince george", "moose jaw", "brandon", "richmond", "richmond hill", "chilliwack", "langley", "coquitlam", "delta",
			"milton", "ajax", "pickering", "cornwall", "belleville", "st catharines", "welland", "stratford", "sarnia",
			"dartmouth",
		},
		DeepCut = {
			"grande prairie", "fort mcmurray", "timmins", "saguenay", "drummondville", "granby", "lloydminster", "prince albert",
			"swift current", "dawson city", "inuvik", "corner brook", "gander", "truro", "miramichi", "bathurst", "chatham kent",
			"orillia", "orangeville", "woodstock", "leamington", "fort st john", "dawson creek", "campbell river", "courtenay",
			"penticton", "vernon", "cranbrook", "nelson", "salmon arm", "brockville", "cobourg", "fort erie", "owen sound",
		},
		Mythic = {
			"flin flon", "thompson", "yorkton", "estevan", "trail", "kimberley", "revelstoke", "powell river", "rouyn noranda",
			"val d or", "baie comeau", "sept iles", "hay river", "churchill", "portage la prairie", "steinbach", "rimouski",
			"kapuskasing", "cold lake", "camrose", "wetaskiwin", "yarmouth", "digby", "summerside", "happy valley goose bay",
			"labrador city", "rankin inlet",
		},
	},
	aliases = {
		["quebec"] = "quebec city", ["vancouver bc"] = "vancouver", ["montreal quebec"] = "montreal",
		["toronto ontario"] = "toronto", ["calgary alberta"] = "calgary", ["victoria bc"] = "victoria",
		["saint johns"] = "st johns", ["london ontario"] = "london", ["niagara"] = "niagara falls",
		["saint catharines"] = "st catharines", ["sault st marie"] = "sault ste marie", ["val dor"] = "val d or",
		["ottowa"] = "ottawa", ["edmonten"] = "edmonton", ["winnepeg"] = "winnipeg", ["vancover"] = "vancouver",
		["halifax ns"] = "halifax", ["st johns newfoundland"] = "st johns", ["regina saskatchewan"] = "regina",
	},
}
