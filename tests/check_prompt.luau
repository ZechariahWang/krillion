-- Checks one prompt of the bank by itself and says how typed answers would be graded:
--   lune run tests/check_prompt.luau <prompt id> [typed answer ...]
-- The checks are the ones tests/PromptBank.test.luau makes of the whole bank. For each typed answer it prints
-- the tier and bank spelling it resolves to and whether it locks in at once ("sure") or asks first, or
-- REFUSED. Use it when adding answers: try what a player would type before and after.
local process = require("@lune/process")

local AnswerMatcher = require("../src/ReplicatedStorage/Shared/AnswerMatcher")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")
local Tiers = require("../src/ReplicatedStorage/Config/Tiers")

local id = process.args[1]
if id == nil then
	print("usage: lune run tests/check_prompt.luau <prompt id> [typed answer ...]")
	process.exit(2)
end

local loaded, prompt = pcall(require, "../src/ServerStorage/PromptBank/" .. id)
if not loaded then
	print("FAIL  " .. id .. " does not load: " .. tostring(prompt))
	process.exit(1)
end

local problems = {}
local function problem(text: string)
	table.insert(problems, text)
end

local answers = {}
local counts = {}
for tierName, list in prompt.answers do
	if Tiers.ByName[tierName] == nil then
		problem("unknown tier " .. tierName)
	end
	counts[tierName] = #list
	for _, answer in list do
		if AnswerMatcher.normalize(answer) ~= answer then
			problem("not normalized: " .. answer .. " (should be " .. AnswerMatcher.normalize(answer) .. ")")
		end
		if #answer > GameConfig.Answer.MaxLength then
			problem("longer than " .. GameConfig.Answer.MaxLength .. " characters: " .. answer)
		end
		if answers[answer] ~= nil then
			problem(answer .. " is in " .. answers[answer] .. " and " .. tierName)
		end
		answers[answer] = tierName
	end
end
for _, tierName in { "Plankton", "Schooler", "Rare" } do
	if (counts[tierName] or 0) == 0 then
		problem("no " .. tierName .. " answers")
	end
end
local aliasCount = 0
for alias, target in prompt.aliases do
	aliasCount += 1
	if AnswerMatcher.normalize(alias) ~= alias then
		problem("alias not normalized: " .. alias)
	end
	if answers[alias] ~= nil then
		problem("alias is also an answer: " .. alias)
	end
	if answers[target] == nil then
		problem("alias " .. alias .. " points at missing " .. target)
	end
end

local parts = {}
for _, tier in Tiers.List do
	if counts[tier.name] ~= nil then
		table.insert(parts, tier.name .. " " .. counts[tier.name])
	end
end
print(id .. ": " .. prompt.prompt)
print("  " .. table.concat(parts, ", ") .. ", aliases " .. aliasCount)

for index = 2, #process.args do
	local typed = process.args[index]
	local tier, spelling, sure = AnswerMatcher.resolve(typed, prompt)
	if tier == nil then
		print(string.format("  %-28s REFUSED", typed))
	else
		print(string.format("  %-28s %s as %q%s", typed, tier, spelling, if sure then " (sure)" else " (asks first)"))
	end
end

if #problems > 0 then
	for _, text in problems do
		print("  FAIL  " .. text)
	end
	process.exit(1)
end
print("  ok")
