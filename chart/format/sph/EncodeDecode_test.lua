local ChartDecoder = require("chart.format.sph.ChartDecoder")
local ChartEncoder = require("chart.format.sph.ChartEncoder")

local test = {}

function test.basic(t)
	-- volume is a custom field
	-- volume 80
	-- disabled for a while

	local s = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# sounds
01 sound01.ogg
02 sound02.ogg
03 sound03.ogg
04 sound04.ogg

# notes
0100 +1/2
1000 =0.01 :0102 .9901
0100 +1/2
1000
0100 +1/2 x1.1 #1/2
0004 ^ e0.5
0004 ^ x1.1
1000 x1.05 :0001020304 .001020
0100 +1/2 // comment
0010 x1.1,1.2,1.3
2000
3000
-
-
- =1.01
]]

	local dec = ChartDecoder()
	local enc = ChartEncoder()

	t:eq(enc:encode(dec:decode(s)), s)
end

function test.visuals(t)
	local s = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# notes
- =0
1111
1000 ^ v1
1000 ^ v2
1000 ^ v3
-
1111
1000 v1
1000 v2
1000 v3
-
- =1
]]

	local dec = ChartDecoder()
	local enc = ChartEncoder()

	t:eq(enc:encode(dec:decode(s)), s)
end

-- create a close point for expand if missing
function test.close_point(t)
	local s_in = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# notes
1000 =0 e1
0001 e1
- ^ e2
- =1
]]

	local s_out = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# notes
1000 =0 e1
- ^
0001 e1
- ^ e2
- ^
- =1
]]

	local dec = ChartDecoder()
	local enc = ChartEncoder()

	t:eq(enc:encode(dec:decode(s_in)), s_out)
end


-- create a close point for expand if missing
function test.close_point_2_layers(t)
	local s_in = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# notes
- =0 x1
- v2 x1
-
- v2 e2
0011 ^ v2 e-2
0011 ^ v3 e1
-
-
- v2 e2
0010 ^ v2 e-2
-
- =3
]]

	local s_out = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# notes
- =0 x1
- v2 x1
-
- v2 e2
0011 ^ v2 e-2
- ^ v2
0011 ^ v3 e1
- ^ v3
-
-
- v2 e2
0010 ^ v2 e-2
- ^ v2
-
- =3
]]

	local dec = ChartDecoder()
	local enc = ChartEncoder()

	t:eq(enc:encode(dec:decode(s_in)), s_out)
end

return test
