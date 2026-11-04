--!strict
-- Per-player answer gate for one prompt: how often Enter-to-check may run, how many checks a round allows,
-- and when the player's own deadline (with extra time) has passed. Pure, so Lune tests can require it.
local GameConfig = require("../Config/GameConfig")

export type Gate = {
	checks: number, -- checks (and failed submits) this prompt
	lastCheck: number, -- clock time of the last check, or -math.huge
	lastWrong: number, -- clock time of the last refused answer, or -math.huge
	lastValid: boolean, -- the last check was in the bank, so the lock-in may follow at once
	deadline: number, -- this player's own end of answering (base time plus any extra time)
	locked: boolean,
}

export type Config = {
	CheckMinInterval: number,
	RetryCooldown: number,
	MaxChecksPerRound: number,
	DeadlineGrace: number,
}

local AnswerGate = {}

function AnswerGate.new(deadline: number): Gate
	return {
		checks = 0,
		lastCheck = -math.huge,
		lastWrong = -math.huge,
		lastValid = false,
		deadline = deadline,
		locked = false,
	}
end

-- Network slack: an answer sent just before the deadline still counts when it lands a moment after.
function AnswerGate.isClosed(gate: Gate, now: number, cfg: Config?): boolean
	local config: Config = cfg or GameConfig.Answer
	return now > gate.deadline + config.DeadlineGrace
end

-- "ok" | "locked" | "closed" | "limit" | "cooldown". A wrong answer waits RetryCooldown so guesses cannot
-- be spammed; any check waits CheckMinInterval.
function AnswerGate.check(gate: Gate, now: number, cfg: Config?): string
	local config: Config = cfg or GameConfig.Answer
	if gate.locked then
		return "locked"
	end
	if AnswerGate.isClosed(gate, now, config) then
		return "closed"
	end
	if gate.checks >= config.MaxChecksPerRound then
		return "limit"
	end
	if now - gate.lastCheck < config.CheckMinInterval or now - gate.lastWrong < config.RetryCooldown then
		return "cooldown"
	end
	return "ok"
end

-- Records a check (or a refused lock-in) that went through.
function AnswerGate.noteCheck(gate: Gate, now: number, valid: boolean)
	gate.checks += 1
	gate.lastCheck = now
	gate.lastValid = valid
	if not valid then
		gate.lastWrong = now
	end
end

-- Whether a lock-in may be graded now. Right after a valid check the second Enter skips the cooldown;
-- a lock-in without one is treated like a check.
function AnswerGate.canSubmit(gate: Gate, now: number, cfg: Config?): string
	local config: Config = cfg or GameConfig.Answer
	if gate.locked then
		return "locked"
	end
	if AnswerGate.isClosed(gate, now, config) then
		return "closed"
	end
	if gate.lastValid then
		return "ok"
	end
	return AnswerGate.check(gate, now, config)
end

function AnswerGate.lock(gate: Gate)
	gate.locked = true
end

return AnswerGate
