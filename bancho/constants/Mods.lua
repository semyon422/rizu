local bit = require("bit")
local M = {}

M.NOFAIL      = bit.lshift(1, 0)
M.EASY        = bit.lshift(1, 1)
M.TOUCHSCREEN = bit.lshift(1, 2)
M.HIDDEN      = bit.lshift(1, 3)
M.HARDROCK    = bit.lshift(1, 4)
M.SUDDENDEATH = bit.lshift(1, 5)
M.DOUBLETIME  = bit.lshift(1, 6)
M.RELAX       = bit.lshift(1, 7)
M.HALFTIME    = bit.lshift(1, 8)
M.NIGHTCORE   = bit.lshift(1, 9)
M.FLASHLIGHT  = bit.lshift(1, 10)
M.AUTOPLAY    = bit.lshift(1, 11)
M.SPUNOUT     = bit.lshift(1, 12)
M.AUTOPILOT   = bit.lshift(1, 13)
M.PERFECT     = bit.lshift(1, 14)
M.KEY4        = bit.lshift(1, 15)
M.KEY5        = bit.lshift(1, 16)
M.KEY6        = bit.lshift(1, 17)
M.KEY7        = bit.lshift(1, 18)
M.KEY8        = bit.lshift(1, 19)
M.FADEIN      = bit.lshift(1, 20)
M.RANDOM      = bit.lshift(1, 21)
M.CINEMA      = bit.lshift(1, 22)
M.TARGET      = bit.lshift(1, 23)
M.KEY9        = bit.lshift(1, 24)
M.KEYCOOP     = bit.lshift(1, 25)
M.KEY1        = bit.lshift(1, 26)
M.KEY3        = bit.lshift(1, 27)
M.KEY2        = bit.lshift(1, 28)
M.SCOREV2     = bit.lshift(1, 29)
M.MIRROR      = bit.lshift(1, 30)
M.NOMOD = 0
M.KEY_MODS = bit.bor(M.KEY1, M.KEY2, M.KEY3, M.KEY4, M.KEY5, M.KEY6, M.KEY7, M.KEY8, M.KEY9)
M.SCORE_INCREASE_MODS = bit.bor(M.HIDDEN, M.HARDROCK, M.FADEIN, M.DOUBLETIME, M.FLASHLIGHT)
M.SPEED_CHANGING_MODS = bit.bor(M.DOUBLETIME, M.NIGHTCORE, M.HALFTIME)
M.OSU_SPECIFIC_MODS = bit.bor(M.AUTOPILOT, M.SPUNOUT, M.TARGET)
M.MANIA_SPECIFIC_MODS = bit.bor(M.MIRROR, M.RANDOM, M.FADEIN, M.KEY_MODS)

function M.filterInvalidCombos(mods, mode_vn)
	if mode_vn ~= 0 then
		mods = bit.band(mods, bit.bnot(M.OSU_SPECIFIC_MODS))
	end
	if mode_vn ~= 3 then
		mods = bit.band(mods, bit.bnot(M.MANIA_SPECIFIC_MODS))
	end
	return mods
end

function M.fromModString(s)
	local _map = {HD = M.HIDDEN, HR = M.HARDROCK, DT = M.DOUBLETIME, HT = M.HALFTIME, V2 = M.SCOREV2, ["4K"] = M.KEY4}
	local mods = 0
	local i = 1
	while i <= #s do
		local two = s:sub(i, i + 1):upper()
		local v = _map[two]
		if v then
			mods = bit.bor(mods, v)
			i = i + 2
		else
			i = i + 1
		end
	end
	return mods
end

function M.toString(mods)
	if mods == 0 then return "NM" end
	return "MODS"
end

return M
