--!strict
return {
	id = "car_brand",
	prompt = "Name a car brand",
	answers = {
		Plankton = {
			"toyota", "ford", "bmw", "tesla", "honda",
		},
		TooClever = {
			"bugatti", "koenigsegg", "pagani",
		},
		Schooler = {
			"mercedes", "audi", "nissan", "volkswagen", "chevrolet", "hyundai", "ferrari", "lamborghini", "porsche", "jeep",
			"dodge", "kia", "mazda", "subaru", "lexus", "mitsubishi", "volvo", "jaguar", "land rover", "rolls royce",
			"bentley", "maserati", "aston martin", "cadillac", "mini", "chrysler",
		},
		Rare = {
			"gmc", "ram", "buick", "lincoln", "acura", "infiniti", "mclaren", "lotus", "genesis", "polestar", "rivian",
			"lucid", "peugeot", "renault", "fiat", "suzuki", "citroen", "alfa romeo", "skoda", "seat", "opel", "vauxhall",
			"isuzu", "daihatsu", "pontiac", "oldsmobile", "plymouth", "saturn", "hummer", "scion", "datsun", "delorean",
			"smart", "byd", "mg", "geely", "cupra", "maybach", "abarth", "lancia", "daewoo",
		},
		DeepCut = {
			"saab", "holden", "mahindra", "ssangyong", "mercury", "rover", "triumph", "austin", "morris", "studebaker",
			"packard", "desoto", "amc", "trabant", "lada", "tvr", "morgan", "caterham", "de tomaso", "spyker", "rimac",
			"zenvo", "saleen", "shelby", "fisker", "vinfast", "zeekr", "nio", "xpeng", "chery", "great wall", "haval",
			"wuling", "dongfeng", "alpine", "ginetta", "lagonda", "alpina", "brabus", "ruf", "ineos", "ariel", "noble",
			"hennessey", "karma", "bollinger", "canoo", "aptera", "togg",
		},
		OneInAKrillion = {
			"dacia", "proton", "tata", "perodua", "borgward", "wartburg", "zastava", "yugo", "tatra", "simca", "talbot",
			"hillman", "mitsuoka", "hongqi", "roewe", "baojun", "faw", "saic",
		},
	},
	aliases = {
		["chevy"] = "chevrolet", ["mercedes benz"] = "mercedes", ["benz"] = "mercedes", ["merc"] = "mercedes",
		["vw"] = "volkswagen", ["range rover"] = "land rover", ["rolls"] = "rolls royce", ["mini cooper"] = "mini",
		["alfa"] = "alfa romeo",
	},
}
