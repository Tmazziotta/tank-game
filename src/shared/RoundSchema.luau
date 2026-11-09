--!strict
-- Round state the server publishes as attributes on ReplicatedStorage.

export type Phase = "Waiting" | "Intermission" | "Active" | "Results"

return {
	PhaseAttribute = "RoundPhase", -- Phase
	EndsAtAttribute = "RoundEndsAt", -- workspace:GetServerTimeNow() timestamp; 0 = no timer
	WinnerAttribute = "RoundWinner", -- winner's DisplayName, "" for a draw
	WinnerKillsAttribute = "RoundWinnerKills",
}
