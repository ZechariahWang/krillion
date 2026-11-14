local process = require("@lune/process")

local passed = 0
local failed = 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name)
		print("  " .. tostring(err))
	end
end

local suites = {
	require("./AnswerMatcher.test"),
	require("./WaterCurve.test"),
	require("./MatchState.test"),
	require("./SpecialRound.test"),
	require("./Profile.test"),
	require("./Economy.test"),
	require("./ArenaLayout.test"),
	require("./Shop.test"),
	require("./Signal.test"),
	require("./Currency.test"),
	require("./Depth.test"),
	require("./Boosts.test"),
	require("./AnswerGate.test"),
	require("./LateJoin.test"),
	require("./Schooling.test"),
	require("./Quests.test"),
	require("./Rewards.test"),
	require("./Cosmetics.test"),
	require("./Tide.test"),
	require("./AnswerStats.test"),
	require("./BotBrain.test"),
	require("./Monetization.test"),
	require("./PromptBank.test"),
	require("./DayCycle.test"),
	require("./LabelSpread.test"),
	require("./Daily.test"),
	require("./DivePack.test"),
}

for _, suite in suites do
	suite(test)
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
