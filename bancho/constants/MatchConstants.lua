local M = {}

M.MatchWinConditions = {}
M.MatchWinConditions.SCORE = 0
M.MatchWinConditions.ACCURACY = 1
M.MatchWinConditions.MOD_ACCURACY = 2
M.MatchWinConditions.PHASED = 3
M.MatchWinConditions.MOD_PHASED = 4
M.MatchWinConditions.NONMOD_ACCURACY = 5
M.MatchWinConditions.NONMOD_PHASED = 6
M.MatchWinConditions.RANKED_SCORE = 7
M.MatchWinConditions.SCORE_V2 = 8

M.MatchTeamTypes = {}
M.MatchTeamTypes.HEAD_TO_HEAD = 0
M.MatchTeamTypes.TEAM_BATTLE = 1
M.MatchTeamTypes.TAG_TEAM_BATTLE = 2
M.MatchTeamTypes.DIRECT = 3

M.MatchTeams = {}
M.MatchTeams.NEUTRAL = 0
M.MatchTeams.RED = 1
M.MatchTeams.BLUE = 2

return M
