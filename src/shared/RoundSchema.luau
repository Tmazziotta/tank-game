--!strict
-- Match and round state the server publishes as attributes on ReplicatedStorage.
-- A match is best of Config.Round.MaxRounds rounds of 3v3 elimination.

-- Waiting: no players. PreRound: countdown, tanks frozen. Active: fighting.
-- RoundOver / MatchOver: result screens.
export type Phase = "Waiting" | "PreRound" | "Active" | "RoundOver" | "MatchOver"

-- How a round was decided.
export type EndReason = "Wipe" | "Health" | "Draw"

return {
	PhaseAttribute = "RoundPhase", -- Phase
	EndsAtAttribute = "RoundEndsAt", -- workspace:GetServerTimeNow() timestamp; 0 = no timer
	MapAttribute = "MapName", -- display name of the current arena
	RoundNumberAttribute = "RoundNumber", -- 1-based, within the match

	-- Per team, suffixed with the team name, e.g. "WinsRed", "AliveBlue".
	WinsPrefix = "Wins", -- rounds won this match
	AlivePrefix = "Alive", -- tanks still fighting this round
	HealthPrefix = "Health", -- team health fraction 0..1 (the tiebreak), live

	RoundWinnerAttribute = "RoundWinner", -- team name, or "" for a draw
	RoundReasonAttribute = "RoundReason", -- EndReason
	MatchWinnerAttribute = "MatchWinner", -- team name, or "" for a draw
}
