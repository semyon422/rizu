local M = {}
M.IDLE = 0
M.AFK = 1
M.PLAYING = 2
M.EDITING = 3
M.MODDING = 4
M.MULTIPLAYER = 5
M.WATCHING = 6
M.UNKNOWN = 7
M.TESTING = 8
M.SUBMITTING = 9
M.PAUSED = 10
M.LOBBY = 11
M.MULTIPLAYING = 12
M.OSUDIRECT = 13

--- Lookup table: value -> action name.
local _byValue = {
	[0] = "IDLE",
	[1] = "AFK",
	[2] = "PLAYING",
	[3] = "EDITING",
	[4] = "MODDING",
	[5] = "MULTIPLAYER",
	[6] = "WATCHING",
	[7] = "UNKNOWN",
	[8] = "TESTING",
	[9] = "SUBMITTING",
	[10] = "PAUSED",
	[11] = "LOBBY",
	[12] = "MULTIPLAYING",
	[13] = "OSUDIRECT",
}

--- Return the action value for a given integer, falling back to the raw value if unknown.
---@param value integer
---@return integer
function M.fromValue(value)
	return _byValue[value] ~= nil and value or value
end

return M
