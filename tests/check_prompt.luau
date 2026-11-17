-- Checks one prompt of the bank by itself and says how typed answers would be graded:
--   lune run tests/check_prompt.luau <prompt id> [typed answer ...] [--file <list>] [--all]
-- The checks are the ones tests/PromptBank.test.luau makes of the whole bank. Each typed answer prints the
-- tier and bank spelling it resolves to and whether it locks in at once ("sure") or asks first, or REFUSED.
-- --file reads more typed answers from a text file, one per line, and prints only the ones that are REFUSED or
-- would ask first (the ones a player would notice), then a count; add --all to print the accepted ones too.
-- Use it when adding answers: probe what a player would type, add what is refused (tests/bank.py add).
local fs = require("@lune/fs")
local process = require("@lune/process")

local AnswerMatcher = require("../src/ReplicatedStorage/Shared/AnswerMatcher")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")
local Tiers = require("../src/ReplicatedStorage/Config/Tiers")

local id = process.args[1]
if id == nil or string.sub(id, 1, 2) == "--" then
	print("usage: lune run tests/check_prompt.luau <prompt id> [typed answer ...] [--file <list>] [--all]")
	process.exit(2)
end
local typedList: { string } = {}
local showAll = false
local listPath: string? = nil
do
	local index = 2
	while index <= #process.args do
		local arg = process.args[index]
		if arg == "--all" then
			showAll = true
		elseif arg == "--file" then
			index += 1
			listPath = process.args[index]
		else
			table.insert(typedList, arg)
		end
		index += 1
	end
end
local fromFile: { string } = {}
if listPath ~= nil then
	local readOk, text = pcall(fs.readFile, listPath)
	if not readOk then
		print("FAIL  cannot read " .. listPath .. ": " .. tostring(text))
		process.exit(1)
	end
	for line in string.gmatch((string.gsub(text, "\r", "")), "[^\n]+") do
		if string.find(line, "%S") ~= nil then
			table.insert(fromFile, line)
		end
	end
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

for _, typed in typedList do
	local tier, spelling, sure = AnswerMatcher.resolve(typed, prompt)
	if tier == nil then
		print(string.format("  %-28s REFUSED", typed))
	else
		print(string.format("  %-28s %s as %q%s", typed, tier, spelling, if sure then " (sure)" else " (asks first)"))
	end
end

if #fromFile > 0 then
	local accepted, asks, refused = 0, 0, 0
	for _, typed in fromFile do
		local tier, spelling, sure = AnswerMatcher.resolve(typed, prompt)
		if tier == nil then
			refused += 1
			print("  REFUSED  " .. typed)
		elseif sure then
			accepted += 1
			if showAll then
				print(string.format("  ok       %s -> %s (%s)", typed, spelling, tier))
			end
		else
			asks += 1
			print(string.format("  ASKS     %s -> %s (%s)", typed, spelling :: string, tier))
		end
	end
	print(string.format("  %d candidates: %d accepted as typed, %d ask first (a typo fix or dropped words), %d refused", #fromFile, accepted, asks, refused))
end

if #problems > 0 then
	for _, text in problems do
		print("  FAIL  " .. text)
	end
	process.exit(1)
end
print("  ok")
