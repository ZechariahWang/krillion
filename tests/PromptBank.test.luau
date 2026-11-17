local PromptBank = require("../src/ServerStorage/PromptBank")
local AnswerMatcher = require("../src/ReplicatedStorage/Shared/AnswerMatcher")
local Tiers = require("../src/ReplicatedStorage/Config/Tiers")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local fs = require("@lune/fs")

local REQUIRED_TIERS = { "Plankton", "Schooler", "Rare" }
-- A prompt is one ModuleScript: kept well inside what a script can hold, so the bank can grow without a surprise.
local MAX_FILE_BYTES = 700000 -- a script holds 1,000,000 characters; the big answer run took author to 587 KB
-- Refusing an answer walks the whole prompt, on the one thread every player shares.
local MAX_REFUSAL_SECONDS = 0.1

local function eachPrompt(check: (any) -> ())
	for _, prompt in PromptBank.List do
		check(prompt)
	end
end

return function(test)
	test("prompt ids are unique and indexed", function()
		local seen = {}
		for _, prompt in PromptBank.List do
			assert(not seen[prompt.id], "duplicate id " .. prompt.id)
			seen[prompt.id] = true
			assert(PromptBank.ById[prompt.id] == prompt, prompt.id .. " missing from ById")
		end
	end)

	test("every answer tier is a real tier", function()
		eachPrompt(function(prompt)
			for tierName in prompt.answers do
				assert(Tiers.ByName[tierName] ~= nil, prompt.id .. " has unknown tier " .. tierName)
			end
		end)
	end)

	test("every prompt has Plankton, Schooler and Rare answers", function()
		eachPrompt(function(prompt)
			for _, tierName in REQUIRED_TIERS do
				local list = prompt.answers[tierName]
				assert(list ~= nil and #list > 0, prompt.id .. " has no " .. tierName .. " answers")
			end
		end)
	end)

	test("answers are normalized and appear once per prompt", function()
		eachPrompt(function(prompt)
			local seen = {}
			for tierName, list in prompt.answers do
				for _, answer in list do
					assert(AnswerMatcher.normalize(answer) == answer, prompt.id .. ": not normalized: " .. answer)
					assert(seen[answer] == nil, prompt.id .. ": " .. answer .. " is in " .. tostring(seen[answer]) .. " and " .. tierName)
					seen[answer] = tierName
				end
			end
		end)
	end)

	test("every answer is short enough to type and to lock in", function()
		local limit = GameConfig.Answer.MaxLength
		eachPrompt(function(prompt)
			for _, list in prompt.answers do
				for _, answer in list do
					assert(#answer <= limit, prompt.id .. ": longer than " .. limit .. " characters: " .. answer)
				end
			end
		end)
	end)

	test("prompt files stay small enough to be one script", function()
		eachPrompt(function(prompt)
			local size = #fs.readFile("src/ServerStorage/PromptBank/" .. prompt.id .. ".luau")
			assert(size <= MAX_FILE_BYTES, prompt.id .. " is " .. size .. " bytes")
		end)
	end)

	test("a refused answer is graded quickly even on the largest prompts", function()
		local typed = { "zzqx", "diet frobnicate cherry", "the great wibbleton", "pepsi zero sugar lemon", "flibbertigibbet" }
		eachPrompt(function(prompt)
			AnswerMatcher.warm(prompt)
			for _, text in typed do
				local started = os.clock()
				AnswerMatcher.resolve(text, prompt)
				local took = os.clock() - started
				assert(took <= MAX_REFUSAL_SECONDS, string.format("%s: %q took %.0f ms", prompt.id, text, took * 1000))
			end
		end)
	end)

	test("aliases are normalized and point at a real answer", function()
		eachPrompt(function(prompt)
			local answers = {}
			for _, list in prompt.answers do
				for _, answer in list do
					answers[answer] = true
				end
			end
			for alias, target in prompt.aliases do
				assert(AnswerMatcher.normalize(alias) == alias, prompt.id .. ": alias not normalized: " .. alias)
				assert(answers[alias] == nil, prompt.id .. ": alias is also an answer: " .. alias)
				assert(answers[target] == true, prompt.id .. ": alias " .. alias .. " points at missing " .. target)
			end
		end)
	end)
end
