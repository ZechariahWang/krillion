--!strict
-- Curated prompts with tiered answers, one module per prompt. Server only: never move this into ReplicatedStorage.
-- Answers and aliases must already be normalized (lowercase, no punctuation, single spaces).

export type Prompt = {
	id: string,
	prompt: string,
	answers: { [string]: { string } },
	aliases: { [string]: string },
}

local list: { Prompt } = {
	require("@self/country_a"),
	require("@self/bird"),
	require("@self/fruit"),
	require("@self/planet_moon"),
	require("@self/programming_language"),
	require("@self/instrument"),
	require("@self/sport_ball"),
	require("@self/color"),
	require("@self/dog_breed"),
	require("@self/capital_europe"),
	require("@self/vegetable"),
	require("@self/ocean_animal"),
	require("@self/chess_piece"),
	require("@self/pasta"),
	require("@self/element"),
	require("@self/cheese"),
	require("@self/board_game"),
	require("@self/currency"),
	require("@self/tree"),
	require("@self/shape"),
	require("@self/dinosaur"),
	require("@self/cloud"),
	require("@self/mythical_creature"),
	require("@self/olympic_sport"),
	require("@self/spice"),
	require("@self/car_brand"),
	require("@self/bone"),
	require("@self/ice_cream"),
	require("@self/desert"),
	require("@self/sea_or_gulf"),
	require("@self/greek_god"),
	require("@self/coffee_drink"),
	require("@self/mountain"),
	require("@self/fabric"),
	require("@self/pokemon"),
	require("@self/kitchen_tool"),
	require("@self/river"),
	require("@self/superhero"),
	require("@self/gemstone"),
	require("@self/bread"),
	require("@self/insect"),
	require("@self/candy"),
	require("@self/city_usa"),
	require("@self/video_game"),
	require("@self/school_subject"),
	require("@self/snake"),
	require("@self/pizza_topping"),
	require("@self/island"),
	require("@self/cartoon_character"),
	require("@self/job"),
	require("@self/mammal"),
	require("@self/breakfast_food"),
	require("@self/city_asia"),
	require("@self/disney_movie"),
	require("@self/body_part"),
	require("@self/cat_breed"),
	require("@self/sandwich"),
	require("@self/emotion"),
	require("@self/weather"),
	require("@self/flower"),
	require("@self/soup"),
	require("@self/vehicle"),
	require("@self/music_genre"),
	require("@self/dessert"),
	require("@self/language"),
	require("@self/painter"),
	require("@self/constellation"),
	require("@self/unit"),
	require("@self/clothing"),
	require("@self/dance"),
	require("@self/farm_animal"),
	require("@self/reptile"),
	require("@self/tea"),
	require("@self/nut_seed"),
	require("@self/country_africa"),
	require("@self/country_europe"),
	require("@self/us_state"),
	require("@self/star_galaxy"),
	require("@self/fish"),
	require("@self/mushroom"),
	require("@self/hat"),
	require("@self/shoe"),
	require("@self/tool"),
	require("@self/sauce"),
	require("@self/sport_any"),
	require("@self/hobby"),
	require("@self/furniture"),
	require("@self/soft_drink"),
	require("@self/smoothie_ingredient"),
	require("@self/kitchen_appliance"),
	require("@self/toy"),
	require("@self/movie_genre"),
	require("@self/author"),
	require("@self/composer"),
	require("@self/holiday"),
	require("@self/metal"),
	require("@self/lake"),
	require("@self/landmark"),
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
