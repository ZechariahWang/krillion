--!strict
return {
	id = "martial_art",
	prompt = "Name a martial art",
	answers = {
		Plankton = {
			"karate", "judo", "taekwondo", "kung fu", "boxing", "jiu jitsu",
		},
		TooClever = {
			"muay thai", "aikido", "capoeira", "krav maga", "wrestling",
		},
		Schooler = {
			"brazilian jiu jitsu", "kickboxing", "mma", "sumo", "ninjutsu", "tai chi", "fencing", "wing chun",
			"hapkido", "kendo", "sambo", "savate", "jeet kune do", "shaolin kung fu", "tang soo do", "kenpo",
			"shotokan", "goju ryu", "kyokushin", "archery",
		},
		Rare = {
			"iaido", "kyudo", "kali", "eskrima", "silat", "systema", "bokator", "lethwei", "sanda", "baguazhang",
			"xingyiquan", "hung gar", "choy li fut", "bartitsu", "glima", "wushu", "shorinji kempo", "wado ryu",
			"shito ryu", "catch wrestling", "pankration", "vovinam", "taekkyon", "kalaripayattu", "gatka",
			"naginata", "bojutsu", "kobudo", "daito ryu", "kenjutsu", "kajukenbo", "jodo",
		},
		DeepCut = {
			"hwa rang do", "kuk sool won", "ashihara karate", "daido juku", "american kenpo", "lima lama",
			"battojutsu", "yoseikan", "uechi ryu", "isshin ryu", "bando", "kuntao", "tomoi", "combat sambo",
			"dambe", "laamb", "engolo", "tahtib", "jogo do pau", "bataireacht", "ssireum", "kurash", "yagli gures",
			"schwingen", "tessenjutsu", "kusarigamajutsu", "sojutsu", "hanbo",
		},
		Mythic = {
			"yabusame", "shurikenjutsu", "sikaran", "panantukan", "dumog", "malla yuddha", "vajra mushti",
			"thang ta", "silambam", "zulu stick fighting", "canne de combat", "lutte traditionnelle",
		},
	},
	aliases = {
		["karate chop"] = "karate", ["jiujitsu"] = "jiu jitsu", ["jui jitsu"] = "jiu jitsu", ["jujutsu"] = "jiu jitsu",
		["jujitsu"] = "jiu jitsu", ["ju jitsu"] = "jiu jitsu", ["tae kwon do"] = "taekwondo",
		["tekwondo"] = "taekwondo", ["taekwando"] = "taekwondo", ["kungfu"] = "kung fu", ["gung fu"] = "kung fu",
		["kung foo"] = "kung fu", ["muaythai"] = "muay thai", ["thai boxing"] = "muay thai",
		["bjj"] = "brazilian jiu jitsu", ["brazilian jiujitsu"] = "brazilian jiu jitsu", ["kick boxing"] = "kickboxing",
		["ufc"] = "mma", ["mixed martial arts"] = "mma", ["cage fighting"] = "mma", ["sumo wrestling"] = "sumo",
		["taichi"] = "tai chi", ["tai chi chuan"] = "tai chi", ["wingchun"] = "wing chun",
		["tang soo"] = "tang soo do", ["goju"] = "goju ryu", ["kyokushinkai"] = "kyokushin",
		["shotokan karate"] = "shotokan", ["kenpo karate"] = "kenpo", ["bagua"] = "baguazhang",
		["xingyi"] = "xingyiquan", ["escrima"] = "eskrima", ["arnis"] = "eskrima", ["pencak silat"] = "silat",
		["capoeria"] = "capoeira", ["capoiera"] = "capoeira", ["kravmaga"] = "krav maga", ["krav magga"] = "krav maga",
		["shaolin"] = "shaolin kung fu", ["jeet kun do"] = "jeet kune do", ["greco roman"] = "wrestling",
		["russian wrestling"] = "sambo", ["french kickboxing"] = "savate", ["japanese archery"] = "kyudo",
		["kuk sool"] = "kuk sool won", ["hwarangdo"] = "hwa rang do", ["korean wrestling"] = "ssireum",
		["turkish oil wrestling"] = "yagli gures", ["swiss wrestling"] = "schwingen", ["tae kyon"] = "taekkyon",
		["kalarippayattu"] = "kalaripayattu", ["kalaripayat"] = "kalaripayattu", ["ninja fighting"] = "ninjutsu",
		["shorinji kenpo"] = "shorinji kempo", ["lethwei burmese boxing"] = "lethwei", ["burmese boxing"] = "lethwei",
		["stick fighting"] = "kali", ["sword fighting"] = "kenjutsu", ["japanese sword fighting"] = "kenjutsu",
	},
}
