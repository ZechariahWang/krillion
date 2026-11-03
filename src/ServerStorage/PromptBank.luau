--!strict
-- Curated prompts with tiered answers. Server only: never move this into ReplicatedStorage.
-- Answers and aliases must already be normalized (lowercase, no punctuation, single spaces).

type Prompt = {
	id: string,
	prompt: string,
	answers: { [string]: { string } },
	aliases: { [string]: string },
}

local list: { Prompt } = {
	{
		id = "country_a",
		prompt = "Name a country whose name starts with A",
		answers = {
			Plankton = { "australia", "argentina", "austria" },
			TooClever = { "algeria", "afghanistan" },
			Schooler = { "albania", "angola", "armenia", "azerbaijan" },
			Rare = { "andorra" },
			DeepCut = { "antigua and barbuda" },
			OneInAKrillion = { "abkhazia" },
		},
		aliases = { antigua = "antigua and barbuda" },
	},
	{
		id = "bird",
		prompt = "Name a bird",
		answers = {
			Plankton = { "eagle", "pigeon", "parrot", "owl", "chicken", "penguin" },
			TooClever = { "flamingo", "ostrich", "peacock", "hummingbird" },
			Schooler = { "sparrow", "crow", "robin", "seagull", "duck", "swan", "goose", "hawk" },
			Rare = { "puffin", "albatross", "kingfisher", "toucan", "pelican" },
			DeepCut = { "kakapo", "shoebill", "cassowary", "hoatzin" },
			OneInAKrillion = { "kagu", "bateleur", "potoo" },
		},
		aliases = { seagulls = "seagull", hen = "chicken" },
	},
	{
		id = "fruit",
		prompt = "Name a fruit",
		answers = {
			Plankton = { "apple", "banana", "orange", "strawberry", "grape" },
			TooClever = { "dragon fruit", "durian", "lychee" },
			Schooler = { "mango", "pear", "peach", "cherry", "pineapple", "watermelon", "kiwi" },
			Rare = { "papaya", "fig", "guava", "persimmon", "pomegranate" },
			DeepCut = { "rambutan", "jackfruit", "mangosteen", "quince" },
			OneInAKrillion = { "medlar", "jabuticaba", "cloudberry", "salak" },
		},
		aliases = { dragonfruit = "dragon fruit", pitaya = "dragon fruit" },
	},
	{
		id = "planet_moon",
		prompt = "Name a moon in our solar system",
		answers = {
			Plankton = { "moon", "the moon" },
			TooClever = { "europa", "titan" },
			Schooler = { "io", "ganymede", "callisto", "phobos" },
			Rare = { "deimos", "enceladus", "triton", "charon" },
			DeepCut = { "mimas", "rhea", "iapetus", "dione", "tethys" },
			OneInAKrillion = { "hyperion", "miranda", "umbriel", "nereid" },
		},
		aliases = { luna = "moon" },
	},
	{
		id = "programming_language",
		prompt = "Name a programming language",
		answers = {
			Plankton = { "python", "java", "javascript", "c" },
			TooClever = { "brainfuck", "lua", "rust" },
			Schooler = { "c plus plus", "c sharp", "ruby", "go", "php", "swift", "kotlin" },
			Rare = { "haskell", "scala", "perl", "fortran", "cobol", "elixir" },
			DeepCut = { "ocaml", "erlang", "prolog", "lisp", "ada" },
			OneInAKrillion = { "forth", "apl", "smalltalk", "nim", "zig" },
		},
		aliases = { ["c++"] = "c plus plus", cpp = "c plus plus", ["c#"] = "c sharp", csharp = "c sharp", js = "javascript", golang = "go" },
	},
	{
		id = "instrument",
		prompt = "Name a musical instrument",
		answers = {
			Plankton = { "guitar", "piano", "drums", "violin" },
			TooClever = { "theremin", "didgeridoo" },
			Schooler = { "flute", "trumpet", "cello", "saxophone", "clarinet", "harp", "ukulele" },
			Rare = { "oboe", "bassoon", "banjo", "accordion", "mandolin", "tuba" },
			DeepCut = { "sitar", "bagpipes", "harpsichord", "marimba", "oud" },
			OneInAKrillion = { "hurdy gurdy", "nyckelharpa", "shamisen", "erhu", "kora" },
		},
		aliases = { drum = "drums", sax = "saxophone", bagpipe = "bagpipes" },
	},
	{
		id = "sport_ball",
		prompt = "Name a sport played with a ball",
		answers = {
			Plankton = { "soccer", "football", "basketball", "tennis" },
			TooClever = { "quidditch", "sepak takraw" },
			Schooler = { "baseball", "volleyball", "golf", "rugby", "cricket", "hockey" },
			Rare = { "handball", "water polo", "squash", "lacrosse", "softball" },
			DeepCut = { "polo", "netball", "hurling", "pelota", "racquetball" },
			OneInAKrillion = { "fives", "jai alai", "korfball", "pickleball" },
		},
		aliases = { basket = "basketball", footie = "football" },
	},
	{
		id = "color",
		prompt = "Name a colour",
		answers = {
			Plankton = { "red", "blue", "green", "yellow", "black", "white" },
			TooClever = { "chartreuse", "periwinkle" },
			Schooler = { "purple", "orange", "pink", "brown", "grey", "gray" },
			Rare = { "teal", "magenta", "turquoise", "maroon", "beige", "navy", "indigo" },
			DeepCut = { "ochre", "vermilion", "cerulean", "mauve", "taupe" },
			OneInAKrillion = { "gamboge", "glaucous", "feldgrau", "smaragdine" },
		},
		aliases = { violet = "purple" },
	},
	{
		id = "dog_breed",
		prompt = "Name a dog breed",
		answers = {
			Plankton = { "labrador", "golden retriever", "german shepherd", "poodle" },
			TooClever = { "chihuahua", "pug" },
			Schooler = { "bulldog", "beagle", "husky", "dachshund", "corgi", "boxer" },
			Rare = { "dalmatian", "great dane", "shih tzu", "border collie", "rottweiler" },
			DeepCut = { "basenji", "whippet", "samoyed", "akita", "papillon" },
			OneInAKrillion = { "xoloitzcuintli", "azawakh", "otterhound", "mudi" },
		},
		aliases = { lab = "labrador", retriever = "golden retriever", shepherd = "german shepherd" },
	},
	{
		id = "capital_europe",
		prompt = "Name a capital city in Europe",
		answers = {
			Plankton = { "london", "paris", "berlin", "rome", "madrid" },
			TooClever = { "vaduz", "valletta" },
			Schooler = { "vienna", "amsterdam", "lisbon", "athens", "dublin", "prague", "brussels" },
			Rare = { "oslo", "helsinki", "warsaw", "budapest", "bern", "copenhagen", "stockholm" },
			DeepCut = { "ljubljana", "bratislava", "vilnius", "tallinn", "riga", "sarajevo" },
			OneInAKrillion = { "chisinau", "podgorica", "tirana", "skopje", "andorra la vella" },
		},
		aliases = { kiev = "kyiv" },
	},
	{
		id = "vegetable",
		prompt = "Name a vegetable",
		answers = {
			Plankton = { "carrot", "potato", "broccoli", "tomato" },
			TooClever = { "romanesco", "kohlrabi" },
			Schooler = { "onion", "lettuce", "cucumber", "spinach", "pepper", "cabbage", "pea", "corn" },
			Rare = { "zucchini", "eggplant", "asparagus", "cauliflower", "celery", "leek", "beet" },
			DeepCut = { "fennel", "artichoke", "okra", "parsnip", "turnip", "radish" },
			OneInAKrillion = { "salsify", "celeriac", "cardoon", "samphire" },
		},
		aliases = { aubergine = "eggplant", courgette = "zucchini", peas = "pea", beetroot = "beet" },
	},
	{
		id = "ocean_animal",
		prompt = "Name an animal that lives in the ocean",
		answers = {
			Plankton = { "shark", "whale", "dolphin", "fish", "octopus" },
			TooClever = { "blobfish", "anglerfish" },
			Schooler = { "jellyfish", "turtle", "crab", "seal", "squid", "starfish", "lobster" },
			Rare = { "manta ray", "seahorse", "eel", "walrus", "stingray", "clownfish" },
			DeepCut = { "narwhal", "nautilus", "cuttlefish", "dugong", "sea cucumber" },
			OneInAKrillion = { "vampire squid", "oarfish", "coelacanth", "sea pig", "siphonophore" },
		},
		aliases = { orca = "whale", ray = "manta ray", seastar = "starfish" },
	},
	{
		id = "chess_piece",
		prompt = "Name a chess piece",
		answers = {
			Plankton = { "king", "queen", "pawn" },
			TooClever = { "horse" },
			Schooler = { "knight", "rook", "bishop" },
			Rare = { "castle" },
			DeepCut = { "ferz", "alfil" },
			OneInAKrillion = { "chancellor", "archbishop", "amazon" },
		},
		aliases = {},
	},
	{
		id = "pasta",
		prompt = "Name a pasta shape",
		answers = {
			Plankton = { "spaghetti", "penne", "macaroni" },
			TooClever = { "angel hair" },
			Schooler = { "fettuccine", "lasagna", "ravioli", "linguine", "fusilli", "rigatoni" },
			Rare = { "farfalle", "tortellini", "gnocchi", "orzo", "tagliatelle" },
			DeepCut = { "orecchiette", "bucatini", "cavatappi", "pappardelle", "conchiglie" },
			OneInAKrillion = { "strozzapreti", "trofie", "casarecce", "mafaldine", "radiatori" },
		},
		aliases = { lasagne = "lasagna", bowtie = "farfalle", ["bow tie"] = "farfalle" },
	},
	{
		id = "element",
		prompt = "Name a chemical element",
		answers = {
			Plankton = { "hydrogen", "oxygen", "gold", "carbon", "iron" },
			TooClever = { "ununoctium", "oganesson" },
			Schooler = { "helium", "nitrogen", "silver", "copper", "sodium", "calcium", "neon" },
			Rare = { "lithium", "uranium", "platinum", "zinc", "mercury", "argon", "titanium" },
			DeepCut = { "tungsten", "bismuth", "gallium", "krypton", "cobalt", "iodine" },
			OneInAKrillion = { "dysprosium", "ytterbium", "praseodymium", "hafnium", "thulium" },
		},
		aliases = {},
	},
	{
		id = "cheese",
		prompt = "Name a cheese",
		answers = {
			Plankton = { "cheddar", "mozzarella", "parmesan" },
			TooClever = { "casu marzu" },
			Schooler = { "brie", "feta", "gouda", "swiss", "blue cheese", "cream cheese" },
			Rare = { "gorgonzola", "camembert", "ricotta", "edam", "halloumi", "provolone" },
			DeepCut = { "manchego", "gruyere", "roquefort", "stilton", "pecorino", "emmental" },
			OneInAKrillion = { "taleggio", "comte", "reblochon", "paneer", "burrata" },
		},
		aliases = { parmigiano = "parmesan", blue = "blue cheese" },
	},
	{
		id = "board_game",
		prompt = "Name a board game",
		answers = {
			Plankton = { "monopoly", "chess", "scrabble" },
			TooClever = { "go" },
			Schooler = { "checkers", "clue", "risk", "battleship", "backgammon", "sorry" },
			Rare = { "catan", "ticket to ride", "pandemic", "trouble", "candy land", "operation" },
			DeepCut = { "carcassonne", "azul", "codenames", "dominion", "stratego" },
			OneInAKrillion = { "terraforming mars", "twilight imperium", "gloomhaven", "wingspan", "agricola" },
		},
		aliases = { cluedo = "clue", draughts = "checkers", ["settlers of catan"] = "catan" },
	},
	{
		id = "currency",
		prompt = "Name a currency",
		answers = {
			Plankton = { "dollar", "euro", "pound" },
			TooClever = { "bitcoin", "robux" },
			Schooler = { "yen", "peso", "rupee", "yuan", "franc" },
			Rare = { "won", "ruble", "lira", "krona", "rand", "real" },
			DeepCut = { "zloty", "forint", "baht", "dirham", "shekel", "ringgit" },
			OneInAKrillion = { "ngultrum", "kwacha", "lempira", "tugrik", "quetzal" },
		},
		aliases = { dollars = "dollar", euros = "euro", pounds = "pound", rupees = "rupee" },
	},
	{
		id = "tree",
		prompt = "Name a type of tree",
		answers = {
			Plankton = { "oak", "pine", "maple", "palm" },
			TooClever = { "baobab", "bonsai" },
			Schooler = { "birch", "willow", "cherry", "apple", "spruce", "fir", "cedar" },
			Rare = { "redwood", "sequoia", "elm", "ash", "beech", "eucalyptus", "mahogany" },
			DeepCut = { "sycamore", "yew", "larch", "hornbeam", "alder", "ginkgo" },
			OneInAKrillion = { "hawthorn", "rowan", "tamarack", "sassafras", "linden" },
		},
		aliases = { ["palm tree"] = "palm", ["pine tree"] = "pine", ["oak tree"] = "oak" },
	},
	{
		id = "shape",
		prompt = "Name a shape",
		answers = {
			Plankton = { "circle", "square", "triangle" },
			TooClever = { "blob", "squiggle" },
			Schooler = { "rectangle", "oval", "star", "heart", "hexagon", "pentagon", "diamond" },
			Rare = { "octagon", "trapezoid", "rhombus", "crescent", "cube", "sphere" },
			DeepCut = { "parallelogram", "ellipse", "heptagon", "decagon", "torus" },
			OneInAKrillion = { "trapezium", "dodecagon", "icosahedron", "annulus", "lemniscate" },
		},
		aliases = { donut = "torus" },
	},
	{
		id = "dinosaur",
		prompt = "Name a dinosaur",
		answers = {
			Plankton = { "t rex", "tyrannosaurus", "triceratops" },
			TooClever = { "barney" },
			Schooler = { "stegosaurus", "velociraptor", "brachiosaurus", "diplodocus" },
			Rare = { "ankylosaurus", "spinosaurus", "pterodactyl", "allosaurus", "iguanodon" },
			DeepCut = { "parasaurolophus", "carnotaurus", "pachycephalosaurus", "gallimimus" },
			OneInAKrillion = { "therizinosaurus", "giganotosaurus", "deinonychus", "troodon", "compsognathus" },
		},
		aliases = { trex = "t rex", ["tyrannosaurus rex"] = "t rex", raptor = "velociraptor" },
	},
	{
		id = "cloud",
		prompt = "Name a type of cloud",
		answers = {
			Plankton = { "cumulus" },
			TooClever = { "mushroom cloud", "storm cloud" },
			Schooler = { "stratus", "cirrus", "cumulonimbus" },
			Rare = { "nimbus", "altostratus", "nimbostratus" },
			DeepCut = { "altocumulus", "cirrostratus", "stratocumulus", "cirrocumulus" },
			OneInAKrillion = { "mammatus", "lenticular", "noctilucent", "asperitas" },
		},
		aliases = {},
	},
	{
		id = "mythical_creature",
		prompt = "Name a mythical creature",
		answers = {
			Plankton = { "dragon", "unicorn", "mermaid" },
			TooClever = { "bigfoot", "loch ness monster" },
			Schooler = { "phoenix", "griffin", "centaur", "werewolf", "vampire", "fairy", "troll" },
			Rare = { "minotaur", "pegasus", "kraken", "hydra", "sphinx", "cyclops", "basilisk" },
			DeepCut = { "chimera", "banshee", "kelpie", "wyvern", "manticore", "golem" },
			OneInAKrillion = { "kitsune", "qilin", "bunyip", "tarasque", "amphisbaena" },
		},
		aliases = { nessie = "loch ness monster", sasquatch = "bigfoot", gryphon = "griffin" },
	},
	{
		id = "olympic_sport",
		prompt = "Name a Summer Olympic sport",
		answers = {
			Plankton = { "swimming", "gymnastics", "athletics", "running" },
			TooClever = { "breakdancing", "breaking" },
			Schooler = { "basketball", "soccer", "football", "tennis", "volleyball", "cycling", "boxing", "diving" },
			Rare = { "rowing", "fencing", "archery", "judo", "wrestling", "weightlifting", "sailing" },
			DeepCut = { "taekwondo", "canoeing", "triathlon", "equestrian", "shooting", "badminton" },
			OneInAKrillion = { "modern pentathlon", "trampoline", "skateboarding", "surfing", "sport climbing" },
		},
		aliases = { track = "athletics", ["track and field"] = "athletics", climbing = "sport climbing" },
	},
	{
		id = "spice",
		prompt = "Name a spice or herb",
		answers = {
			Plankton = { "salt", "pepper", "cinnamon", "basil" },
			TooClever = { "msg" },
			Schooler = { "oregano", "paprika", "ginger", "garlic", "parsley", "cumin", "mint" },
			Rare = { "turmeric", "nutmeg", "thyme", "rosemary", "cardamom", "chili", "saffron" },
			DeepCut = { "coriander", "cloves", "sage", "dill", "fenugreek", "star anise" },
			OneInAKrillion = { "sumac", "asafoetida", "galangal", "mace", "lovage" },
		},
		aliases = { cilantro = "coriander", clove = "cloves", chilli = "chili" },
	},
	{
		id = "car_brand",
		prompt = "Name a car brand",
		answers = {
			Plankton = { "toyota", "ford", "bmw", "tesla", "honda" },
			TooClever = { "bugatti", "koenigsegg" },
			Schooler = { "mercedes", "audi", "nissan", "volkswagen", "chevrolet", "hyundai", "ferrari" },
			Rare = { "porsche", "lamborghini", "mazda", "subaru", "kia", "jeep", "volvo" },
			DeepCut = { "peugeot", "renault", "skoda", "fiat", "suzuki", "citroen", "alfa romeo" },
			OneInAKrillion = { "dacia", "lada", "proton", "tata", "holden", "saab" },
		},
		aliases = { chevy = "chevrolet", vw = "volkswagen", ["mercedes benz"] = "mercedes" },
	},
	{
		id = "bone",
		prompt = "Name a bone in the human body",
		answers = {
			Plankton = { "femur", "skull", "rib" },
			TooClever = { "funny bone" },
			Schooler = { "spine", "tibia", "humerus", "pelvis", "jaw", "collarbone" },
			Rare = { "fibula", "radius", "ulna", "clavicle", "scapula", "sternum", "patella" },
			DeepCut = { "mandible", "vertebra", "sacrum", "coccyx", "hyoid", "talus" },
			OneInAKrillion = { "stapes", "incus", "malleus", "zygomatic", "ethmoid" },
		},
		aliases = { kneecap = "patella", ["shoulder blade"] = "scapula", tailbone = "coccyx", backbone = "spine" },
	},
	{
		id = "ice_cream",
		prompt = "Name an ice cream flavour",
		answers = {
			Plankton = { "vanilla", "chocolate", "strawberry" },
			TooClever = { "garlic", "bacon" },
			Schooler = { "mint", "cookie dough", "cookies and cream", "caramel", "coffee", "mango" },
			Rare = { "pistachio", "rocky road", "butter pecan", "neapolitan", "cherry", "coconut" },
			DeepCut = { "rum raisin", "green tea", "matcha", "stracciatella", "black sesame" },
			OneInAKrillion = { "ube", "durian", "spumoni", "tiger tail", "hokey pokey" },
		},
		aliases = { ["mint chocolate chip"] = "mint", choc = "chocolate" },
	},
	{
		id = "desert",
		prompt = "Name a desert",
		answers = {
			Plankton = { "sahara" },
			TooClever = { "antarctica", "arctic" },
			Schooler = { "gobi", "mojave", "kalahari", "arabian" },
			Rare = { "atacama", "sonoran", "namib", "great victoria" },
			DeepCut = { "thar", "chihuahuan", "karakum", "taklamakan", "simpson" },
			OneInAKrillion = { "kyzylkum", "dasht e kavir", "gibson", "tanami", "negev" },
		},
		aliases = { ["sahara desert"] = "sahara", ["gobi desert"] = "gobi", ["mojave desert"] = "mojave" },
	},
	{
		id = "sea_or_gulf",
		prompt = "Name a sea or gulf (not an ocean)",
		answers = {
			Plankton = { "mediterranean", "caribbean", "red sea" },
			TooClever = { "dead sea" },
			Schooler = { "black sea", "baltic", "north sea", "gulf of mexico", "caspian" },
			Rare = { "arabian sea", "persian gulf", "south china sea", "adriatic", "aegean" },
			DeepCut = { "bering sea", "coral sea", "tasman sea", "sea of japan", "gulf of guinea" },
			OneInAKrillion = { "sargasso sea", "laptev sea", "banda sea", "gulf of bothnia", "sea of okhotsk" },
		},
		aliases = { ["mediterranean sea"] = "mediterranean", ["caribbean sea"] = "caribbean", ["baltic sea"] = "baltic", ["caspian sea"] = "caspian" },
	},
	{
		id = "greek_god",
		prompt = "Name a Greek god or goddess",
		answers = {
			Plankton = { "zeus", "poseidon", "athena", "hades" },
			TooClever = { "percy jackson" },
			Schooler = { "apollo", "aphrodite", "ares", "hermes", "hera", "artemis" },
			Rare = { "demeter", "dionysus", "hephaestus", "persephone", "hestia" },
			DeepCut = { "nike", "eros", "hecate", "pan", "iris", "nemesis" },
			OneInAKrillion = { "hypnos", "morpheus", "thanatos", "eos", "selene" },
		},
		aliases = {},
	},
	{
		id = "coffee_drink",
		prompt = "Name a coffee drink",
		answers = {
			Plankton = { "latte", "espresso", "cappuccino" },
			TooClever = { "frappuccino" },
			Schooler = { "americano", "mocha", "macchiato", "iced coffee", "cold brew" },
			Rare = { "flat white", "cortado", "affogato", "irish coffee" },
			DeepCut = { "ristretto", "lungo", "red eye", "cafe au lait", "doppio" },
			OneInAKrillion = { "cafe bombon", "turkish coffee", "einspanner", "marocchino", "carajillo" },
		},
		aliases = { frappe = "frappuccino", flatwhite = "flat white" },
	},
	{
		id = "mountain",
		prompt = "Name a mountain",
		answers = {
			Plankton = { "everest", "mount everest" },
			TooClever = { "olympus mons" },
			Schooler = { "kilimanjaro", "k2", "fuji", "mont blanc", "denali" },
			Rare = { "matterhorn", "aconcagua", "elbrus", "mount rainier", "ben nevis" },
			DeepCut = { "annapurna", "kangchenjunga", "lhotse", "mount cook", "vinson" },
			OneInAKrillion = { "nanga parbat", "cho oyu", "makalu", "eiger", "huascaran" },
		},
		aliases = { ["mt everest"] = "everest", ["mount fuji"] = "fuji", ["mount kilimanjaro"] = "kilimanjaro", mckinley = "denali" },
	},
	{
		id = "fabric",
		prompt = "Name a fabric or textile",
		answers = {
			Plankton = { "cotton", "silk", "wool" },
			TooClever = { "spandex" },
			Schooler = { "denim", "polyester", "leather", "linen", "nylon", "velvet" },
			Rare = { "satin", "cashmere", "suede", "fleece", "lace", "tweed" },
			DeepCut = { "chiffon", "corduroy", "flannel", "jersey", "organza", "muslin" },
			OneInAKrillion = { "seersucker", "gabardine", "brocade", "taffeta", "hessian" },
		},
		aliases = { jean = "denim", jeans = "denim" },
	},
	{
		id = "pokemon",
		prompt = "Name a Pokemon",
		answers = {
			Plankton = { "pikachu", "charizard", "charmander", "squirtle", "bulbasaur" },
			TooClever = { "missingno", "bidoof" },
			Schooler = { "eevee", "mewtwo", "snorlax", "jigglypuff", "gengar", "mew" },
			Rare = { "lucario", "gyarados", "dragonite", "greninja", "magikarp", "psyduck" },
			DeepCut = { "ditto", "lapras", "scyther", "arcanine", "umbreon", "garchomp" },
			OneInAKrillion = { "farfetchd", "stunfisk", "klefki", "dunsparce", "bruxish" },
		},
		aliases = {},
	},
	{
		id = "kitchen_tool",
		prompt = "Name a kitchen tool or utensil",
		answers = {
			Plankton = { "knife", "spoon", "fork", "spatula" },
			TooClever = { "air fryer" },
			Schooler = { "whisk", "ladle", "grater", "peeler", "tongs", "rolling pin", "blender" },
			Rare = { "colander", "sieve", "mandoline", "mortar and pestle", "zester" },
			DeepCut = { "garlic press", "pastry brush", "bench scraper", "melon baller", "skimmer" },
			OneInAKrillion = { "spurtle", "chinois", "tamis", "spider strainer", "cherry pitter" },
		},
		aliases = { strainer = "colander", pestle = "mortar and pestle" },
	},
	{
		id = "river",
		prompt = "Name a river",
		answers = {
			Plankton = { "nile", "amazon", "mississippi" },
			TooClever = { "styx" },
			Schooler = { "thames", "yangtze", "danube", "ganges", "rhine", "seine" },
			Rare = { "mekong", "colorado", "volga", "congo", "tigris", "euphrates", "zambezi" },
			DeepCut = { "yukon", "orinoco", "indus", "niger", "murray", "elbe" },
			OneInAKrillion = { "lena", "yenisei", "irrawaddy", "limpopo", "ob" },
		},
		aliases = { ["river nile"] = "nile", ["amazon river"] = "amazon", ["river thames"] = "thames" },
	},
	{
		id = "superhero",
		prompt = "Name a superhero",
		answers = {
			Plankton = { "superman", "batman", "spiderman", "iron man" },
			TooClever = { "squirrel girl", "one punch man" },
			Schooler = { "wonder woman", "hulk", "thor", "captain america", "flash", "wolverine" },
			Rare = { "aquaman", "black panther", "green lantern", "deadpool", "doctor strange", "ant man" },
			DeepCut = { "hawkeye", "nightwing", "vision", "cyborg", "green arrow", "shazam" },
			OneInAKrillion = { "moon knight", "booster gold", "blue beetle", "jessica jones", "martian manhunter" },
		},
		aliases = { ["spider man"] = "spiderman", ironman = "iron man", antman = "ant man", ["the flash"] = "flash" },
	},
	{
		id = "gemstone",
		prompt = "Name a gemstone",
		answers = {
			Plankton = { "diamond", "ruby", "emerald", "sapphire" },
			TooClever = { "infinity stone" },
			Schooler = { "pearl", "amethyst", "opal", "topaz", "jade" },
			Rare = { "garnet", "aquamarine", "turquoise", "onyx", "peridot", "quartz" },
			DeepCut = { "tanzanite", "citrine", "moonstone", "lapis lazuli", "tourmaline" },
			OneInAKrillion = { "alexandrite", "spinel", "zircon", "kunzite", "morganite" },
		},
		aliases = { lapis = "lapis lazuli" },
	},
	{
		id = "bread",
		prompt = "Name a type of bread",
		answers = {
			Plankton = { "white bread", "baguette", "sourdough" },
			TooClever = { "garlic bread" },
			Schooler = { "bagel", "pita", "naan", "ciabatta", "rye", "brioche", "tortilla" },
			Rare = { "focaccia", "pretzel", "croissant", "challah", "cornbread", "flatbread" },
			DeepCut = { "pumpernickel", "soda bread", "lavash", "injera", "panettone" },
			OneInAKrillion = { "bannock", "limpa", "pao de queijo", "roti canai", "damper" },
		},
		aliases = { white = "white bread", pitta = "pita", pretzels = "pretzel" },
	},
}

local byId: { [string]: Prompt } = {}
for _, prompt in list do
	byId[prompt.id] = prompt
end

local PromptBank = {
	List = list,
	ById = byId,
}

-- A random prompt whose id is not in the exclusion set. Falls back to any prompt when everything is excluded.
function PromptBank.random(exclude: { [string]: boolean }): Prompt
	local candidates = {}
	for _, prompt in list do
		if not exclude[prompt.id] then
			table.insert(candidates, prompt)
		end
	end
	if #candidates == 0 then
		candidates = list
	end
	return candidates[math.random(1, #candidates)]
end

return PromptBank
