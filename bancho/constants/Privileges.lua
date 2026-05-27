local bit = require("bit")
local M = {}

M.UNRESTRICTED    = bit.lshift(1, 0)
M.VERIFIED        = bit.lshift(1, 1)
M.WHITELISTED     = bit.lshift(1, 2)
M.SUPPORTER       = bit.lshift(1, 4)
M.PREMIUM         = bit.lshift(1, 5)
M.ALUMNI          = bit.lshift(1, 7)
M.TOURNEY_MANAGER = bit.lshift(1, 10)
M.NOMINATOR       = bit.lshift(1, 11)
M.MODERATOR       = bit.lshift(1, 12)
M.ADMINISTRATOR   = bit.lshift(1, 13)
M.DEVELOPER       = bit.lshift(1, 14)
M.DONATOR = bit.bor(M.SUPPORTER, M.PREMIUM)
M.STAFF   = bit.bor(M.MODERATOR, M.ADMINISTRATOR, M.DEVELOPER)

return M
