local AnswerGate = require("../src/ReplicatedStorage/Shared/AnswerGate")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local CFG = {
	CheckMinInterval = 0.35,
	RetryCooldown = 1,
	MaxChecksPerRound = 40,
	DeadlineGrace = 0.5,
}

return function(test)
	test("a fresh gate allows a check", function()
		local gate = AnswerGate.new(20)
		assert(AnswerGate.check(gate, 0, CFG) == "ok")
	end)

	test("after an invalid check the cooldown is 1 s; after a valid one, 0.35 s", function()
		local gate = AnswerGate.new(20)
		AnswerGate.noteCheck(gate, 1, false)
		assert(AnswerGate.check(gate, 1.5, CFG) == "cooldown")
		assert(AnswerGate.check(gate, 1.99, CFG) == "cooldown")
		assert(AnswerGate.check(gate, 2, CFG) == "ok")
		AnswerGate.noteCheck(gate, 3, true)
		assert(AnswerGate.check(gate, 3.3, CFG) == "cooldown")
		assert(AnswerGate.check(gate, 3.35, CFG) == "ok")
	end)

	test("the 41st check hits the limit", function()
		local gate = AnswerGate.new(1000)
		local now = 0
		for _ = 1, 40 do
			assert(AnswerGate.check(gate, now, CFG) == "ok")
			AnswerGate.noteCheck(gate, now, true)
			now += 1
		end
		assert(AnswerGate.check(gate, now, CFG) == "limit")
	end)

	test("answers close after the deadline plus the grace", function()
		local gate = AnswerGate.new(20)
		assert(AnswerGate.check(gate, 20.4, CFG) == "ok")
		assert(AnswerGate.check(gate, 20.6, CFG) == "closed")
		assert(AnswerGate.canSubmit(gate, 20.6, CFG) == "closed")
	end)

	test("extra time moves the deadline", function()
		local gate = AnswerGate.new(20)
		gate.deadline += 10
		assert(AnswerGate.check(gate, 25, CFG) == "ok")
		assert(AnswerGate.check(gate, 30.6, CFG) == "closed")
	end)

	test("submit is allowed right after a valid check", function()
		local gate = AnswerGate.new(20)
		AnswerGate.noteCheck(gate, 5, true)
		assert(AnswerGate.canSubmit(gate, 5.01, CFG) == "ok")
	end)

	test("submit without a valid check waits like a check", function()
		local gate = AnswerGate.new(20)
		assert(AnswerGate.canSubmit(gate, 0, CFG) == "ok")
		AnswerGate.noteCheck(gate, 5, false)
		assert(AnswerGate.canSubmit(gate, 5.5, CFG) == "cooldown")
		assert(AnswerGate.canSubmit(gate, 6.1, CFG) == "ok")
	end)

	test("a locked gate refuses everything", function()
		local gate = AnswerGate.new(20)
		AnswerGate.noteCheck(gate, 1, true)
		AnswerGate.lock(gate)
		assert(AnswerGate.check(gate, 10, CFG) == "locked")
		assert(AnswerGate.canSubmit(gate, 10, CFG) == "locked")
	end)

	test("the default config is GameConfig.Answer", function()
		local gate = AnswerGate.new(20)
		AnswerGate.noteCheck(gate, 1, false)
		assert(AnswerGate.check(gate, 1 + GameConfig.Answer.RetryCooldown - 0.01) == "cooldown")
		assert(AnswerGate.check(gate, 1 + GameConfig.Answer.RetryCooldown) == "ok")
	end)
end
