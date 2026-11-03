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
}

for _, suite in suites do
	suite(test)
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
