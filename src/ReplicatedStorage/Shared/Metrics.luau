--!strict
-- Names and numbering for the analytics events Server/MetricsService sends to Roblox's AnalyticsService.
-- Pure, so the tests can guard the funnel order and the Shells bookkeeping.

local Metrics = {}

-- A new player's first session, in the order the steps usually happen. Append new steps at the end:
-- renumbering a step breaks the funnel chart's history.
Metrics.ONBOARDING = { "Joined", "TutorialDone", "MatchStarted", "AnswerAccepted", "RoundSurvived", "MatchFinished" }

Metrics.FUNNEL_STEP_LIMIT = 100 -- Roblox keeps at most this many steps per funnel
Metrics.MAX_ROUND = 40 -- rounds past this share the last match funnel step

-- Shells transaction types, by the wallet reason; any other reason is "Gameplay". The values are names of
-- Enum.AnalyticsEconomyTransactionType.
local TRANSACTIONS: { [string]: string } = {
	purchase = "IAP",
	spend = "Shop",
	refund = "Shop",
	daily = "TimedReward",
}

export type Economy = {
	flow: string, -- "Source" | "Sink": a name of Enum.AnalyticsEconomyFlowType
	amount: number,
	transaction: string,
	sku: string,
}

function Metrics.onboardingStep(name: string): number?
	for index, step in Metrics.ONBOARDING do
		if step == name then
			return index
		end
	end
	return nil
end

-- The match funnel: round 0 is the start (step 1), surviving round N is step N + 1.
function Metrics.matchStep(round: number): (number, string)
	if round <= 0 then
		return 1, "Match started"
	end
	local capped = math.min(round, Metrics.MAX_ROUND)
	return capped + 1, "Survived round " .. capped
end

-- delta: Shells gained (positive) or spent (negative). sku says what a spend bought.
function Metrics.economy(delta: number, reason: string?, sku: string?): Economy
	local why = reason or "unknown"
	return {
		flow = if delta >= 0 then "Source" else "Sink",
		amount = math.abs(delta),
		transaction = TRANSACTIONS[why] or "Gameplay",
		sku = sku or why,
	}
end

-- A custom field value that names its dimension, so it reads on its own in a chart breakdown.
function Metrics.field(dimension: string, value: string?): string
	return dimension .. " - " .. (value or "None")
end

return Metrics
