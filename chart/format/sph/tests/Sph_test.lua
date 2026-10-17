local Sph = require("chart.format.sph.Sph")

local test = {}

---@param t testing.T
function test.encdec_1(t)
	local sph = Sph()

	local chart = [[
# metadata
title Title
artist Artist

# sounds
01 sound01.ogg
## sound##.ogg

# notes
0100 =0 +1/2
1000 =0.01 :01##
0100 +1/2
1000
0100 +1/2 x1.1 #1/2
0004 ^ e0.5
1000 x1
0100 +1/2 // comment
0010
-
-
- =1.01
]]
	sph:decode(chart)

	t:eq(sph:encode(), chart)
end

return test
