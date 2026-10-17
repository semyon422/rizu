local bit = require("bit")
local M = {}
M.PLAYER    = bit.lshift(1, 0)
M.SUPPORTER = bit.lshift(1, 1)
M.MODERATOR = bit.lshift(1, 2)
M.DEVELOPER = bit.lshift(1, 3)
M.OWNER     = bit.lshift(1, 4)
return M
