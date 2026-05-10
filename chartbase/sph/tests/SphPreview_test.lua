local SphPreview = require("sph.SphPreview")
local SphLines = require("sph.SphLines")
local TextLines = require("sph.lines.TextLines")
local Fraction = require("ncdk.Fraction")
local stbl = require("stbl")

local test = {}

local function bytes_to_string(t)
	local s = {}
	for i, v in ipairs(t) do
		s[i] = string.char(v)
	end
	return table.concat(s)
end

---@param n number
---@return string
local function tobits(n)
	local t = {}
	for i = 1, 8 do
		t[i] = 0
	end
	local i = 8
	while n > 0 do
		local rest = n % 2
		t[i] = rest
		n = (n - rest) / 2
		i = i - 1
	end
	return ("0b%s"):format(table.concat(t))
end

function test.one_note(t)
	local s = {
		0b0, 0b0, 0b0, -- header
		0b01000000, -- 0/1 new line
		0b11000000, -- 1000
	}

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)
	t:tdeq(lines, {
		{notes = {true}},
	})
end

function test.visual_side(t)
	local s = {
		0b0, 0b0, 0b0, -- header

		0b01000000, -- 0/1 new line
		0b11000000, -- 1000

		0b01000000, -- 0/1 new line
		0b11000001, -- 0100

		-- - =1
		0b01000000, -- 0/1 new line
		0b00000001, -- add 1s

		-- - =2
		0b01000000, -- 0/1 new line
		0b00000001, -- add 1s
	}

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)
	t:tdeq(lines, {
		{notes = {true}},
		{notes = {nil, true}},
		{offset = 1},
		{offset = 2},
	})

	local sphLines = SphLines()
	sphLines:decode(SphPreview:decodeLines(str))

	sphLines.protoLines[2].same = true
	local lines1 = SphPreview:linesToPreviewLines(sphLines:encode())
	t:tdeq(lines1, {
		{notes = {true, true}},
		{offset = 1},
		{offset = 2},
	})
end

function test.complex_offsets(t)
	local s = {
		0b0, 0b0, 0b0, -- header

		-- - =0
		0b01000000, -- 0/1 new line
		0b00000000, -- add 0

		-- - =1
		0b01000000, -- 0/1 new line
		0b00000001, -- add 1

		-- - =35
		0b01000000, -- 0/1 new line
		0b00000010, -- add 2
		0b00000001, -- add 32

		-- - =35.5
		0b01000000, -- 0/1 new line
		0b00100010, -- add 0 + 512/1024, int diff = 0
		0b00000000, -- add 0/1024

		-- - =36.5
		0b01000000, -- 0/1 new line
		0b00100110, -- add 1 + 512/1024, int diff <= 7
		0b00000000, -- add 0/1024

		-- - =44.5
		0b01000000, -- 0/1 new line
		0b00001000, -- add 8
		0b00100010, -- add 0 + 512/1024, int diff <= 31
		0b00000000, -- add 0/1024

		-- - =76.5
		0b01000000, -- 0/1 new line
		0b00011111, -- add 31
		0b00100110, -- add 1 + 512/1024, int diff <= 38
		0b00000000, -- add 0/1024

		-- - =116.5
		0b01000000, -- 0/1 new line
		0b00001000, -- add 8
		0b00000001, -- add 32
		0b00100010, -- add 0 + 512/1024, else
		0b00000000, -- add 0/1024
	}

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)
	-- print(stbl.encode(lines))
	t:tdeq(lines, {
		{offset = 0},
		{offset = 1},
		{offset = 35},
		{offset = 35.5},
		{offset = 36.5},
		{offset = 44.5},
		{offset = 76.5},
		{offset = 116.5},
	})

	local _str = SphPreview:encode(lines)
	t:eq(_str, str)
end

function test.complex_fractions(t)
	local s = {
		0b0, 0b0, 0b0, -- header

		-- -
		0b01000000,

		-- - +1/8
		0b01000010,

		-- - +1/6
		0b01100010,

		-- - +1/5
		0b01010100, -- 1/16, double, 5
		0b00010000, -- 16

		-- - +1/21
		0b01110110, -- 1/12, double, 7
		0b00000100, -- 4

		-- - +255/256
		0b01011111, -- 1/16, double, 16
		0b11111111, -- 255
	}

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)
	t:tdeq(lines, {
		{},
		{time = {1, 8}},
		{time = {1, 6}},
		{time = {1, 5}},
		{time = {1, 21}},
		{time = {255, 256}},
	})

	lines[#lines].time = Fraction(511, 512) -- will be approximated to 255/256

	local _str = SphPreview:encode(lines)
	t:eq(_str, str)
end

function test.complex_case(t)
	local s = {
		0b0,
		0xFE, 0xFF, -- -2s

		-- 1100 +1/2
		0b01001000, -- +1/2
		0b11000000, -- 1000
		0b11000001, -- 0100

		-- - =-1.49609375 // -2 + 516/1024
		0b01000000, -- 0/1 new line
		0b00100010, -- add 0 + 512/1024
		0b00000100, -- add 4/1024

		-- 1000
		0b01000000, -- 0/1 new line
		0b11000000, -- 1000

		-- 1000 +11/12
		0b01101011, -- 11/12
		0b11000000, -- 1000

		-- - =5 // -2 + 7
		0b01000000, -- 0/1 new line
		0b00000111, -- add 7s and set frac part to 0

		-- 1000 +1/2
		0b01001000, -- +1/2
		0b11000000, -- 1000
	}

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)
	-- print(stbl.encode(lines))
	t:tdeq(lines, {
		{time = {1, 2}, notes = {true, true}},
		{offset = -2 + 129 / 256},
		{notes = {true}},
		{time = {11, 12}, notes = {true}},
		{offset = 5},
		{time = {1, 2}, notes = {true}},
	})

	local _str = SphPreview:encode(lines)
	t:eq(_str, str)

	local sphLines = SphLines()
	sphLines:decode(SphPreview:decodeLines(str))

	local tl = TextLines()
	tl.lines = sphLines:encode()
	tl.columns = 4
	t:eq(tl:encode(), [[
1100 +1/2
- =-1.49609375
1000
1000 +11/12
- =5
1000 +1/2]])

	local _str = SphPreview:encodeLines(sphLines:encode())
	-- print(stbl.encode(enc_lines))
	t:eq(_str, str)

	-- print()
	-- for i = 1, #str do
	-- 	print(i, tobits(str:byte(i, i)))
	-- end
	-- for i = 1, #_str do
	-- 	print(i, tobits(_str:byte(i, i)))
	-- end
end


function test.complex_case_2(t)
	local s = {
		0b1,
		0xFE, 0xFF, -- -2s

		-- 1111111111
		0b01000000, -- 0/1 new line
		0b11011111, -- 1111100000
		0b11111111, -- 0000011111

		-- 3000
		0b01000000, -- 0/1 new line
		0b10000001, -- 3000

		-- 1300
		0b01000000, -- 0/1 new line
		0b10000010, -- 0300
		0b11000001, -- 1000

		-- - =-2
		0b01000000, -- 0/1 new line
		0b00000000, -- add 0/1

		-- - =5 // -2 + 7
		0b01000000, -- 0/1 new line
		0b00000111, -- add 7s and set frac part to 0
	}

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)
	-- print(stbl.encode(lines))
	t:tdeq(lines, {
		{notes = {true, true, true, true, true, true, true, true, true, true}},
		{notes = {false}},
		{notes = {true, false}},
		{offset = -2},
		{offset = 5},
	})

	local _str = SphPreview:encode(lines, 1)
	t:eq(_str, str)

	local sphLines = SphLines()
	sphLines:decode(SphPreview:decodeLines(str))

	local tl = TextLines()
	tl.lines = sphLines:encode()
	tl.columns = 10
	t:eq(tl:encode(), [[
2211111111
3000000000
1300000000
- =-2
- =5]])

	local _str = SphPreview:encodeLines(sphLines:encode(), 1)
	t:eq(_str, str)
end

function test.columns_group_1(t)
	local lines = {
		{notes = {true, nil, nil, nil, nil, true, nil, nil, nil, nil, true}},
		{notes = {true, false, true, false, true, false, true, false, true, false}},
	}

	local _str = SphPreview:encode(lines, 1)
	local _lines = SphPreview:decode(_str)

	t:tdeq(_lines, lines)
end

function test.visual_merge(t)
	local _lines = {
		{offset = 0},
		{notes = {{column = 1, type = "1"}}, same = true},
		{notes = {{column = 2, type = "1"}}, same = true},
		{notes = {{column = 3, type = "1"}}},
		{},
	}

	local plines = SphPreview:linesToPreviewLines(_lines)
	t:tdeq(plines, {
		{notes = {true, true}, offset = 0},
		{notes = {nil, nil, true}},
		{},
	})

	local str = SphPreview:encodeLines(_lines, 1)
	local lines = SphPreview:decodeLines(str)

	t:tdeq(lines, { -- no same lines after decode
		{notes = {{column = 1, type = "1"}, {column = 2, type = "1"}}, offset = 0},
		{notes = {{column = 3, type = "1"}}},
		{},
	})
end

function test.collision_short_short(t)
	local _lines = {
		{notes = {{column = 1, type = "1"}}},
		{notes = {{column = 1, type = "1"}}, same = true},
	}

	local plines = SphPreview:linesToPreviewLines(_lines)
	t:tdeq(plines, {
		{notes = {true}},
	})
end

function test.collision_short_long(t)
	local _lines = {
		{notes = {{column = 1, type = "1"}}},
		{notes = {{column = 1, type = "2"}}, same = true},
		{notes = {{column = 1, type = "3"}}},
	}

	local plines = SphPreview:linesToPreviewLines(_lines)
	t:tdeq(plines, {
		{notes = {true}},
		{notes = {false}},
	})

	local _lines = {
		{notes = {{column = 1, type = "2"}}},
		{notes = {{column = 1, type = "1"}}, same = true},
		{notes = {{column = 1, type = "3"}}},
	}

	local plines = SphPreview:linesToPreviewLines(_lines)
	t:tdeq(plines, {
		{notes = {true}},
		{notes = {false}},
	})
end

function test.collision_long_short(t)
	local _lines = {
		{notes = {{column = 1, type = "2"}}},
		{notes = {{column = 1, type = "3"}}},
		{notes = {{column = 1, type = "1"}}, same = true},
	}

	local plines = SphPreview:linesToPreviewLines(_lines)
	t:tdeq(plines, {
		{notes = {true}},
		{notes = {false}},
	})

	local _lines = {
		{notes = {{column = 1, type = "2"}}},
		{notes = {{column = 1, type = "1"}}},
		{notes = {{column = 1, type = "3"}}, same = true},
	}

	local plines = SphPreview:linesToPreviewLines(_lines)
	t:tdeq(plines, {
		{notes = {true}},
		{notes = {false}},
	})
end

function test.collision_short_inside_long(t)
	local _lines = {
		{notes = {{column = 1, type = "2"}}},
		{notes = {{column = 1, type = "1"}}},
		{notes = {{column = 1, type = "3"}}},
	}

	local plines = SphPreview:linesToPreviewLines(_lines)
	t:tdeq(plines, {
		{notes = {true}},
		{notes = {}},
		{notes = {false}},
	})
end

function test.collision_long_inside_long(t)
	local _lines = {
		{notes = {{column = 1, type = "2"}}},
		{notes = {{column = 1, type = "2"}}},
		{notes = {{column = 1, type = "3"}}},
		{notes = {{column = 1, type = "3"}}},
	}

	local plines = SphPreview:linesToPreviewLines(_lines)
	t:tdeq(plines, {
		{notes = {true}},
		{notes = {}},
		{notes = {}},
		{notes = {false}},
	})
end

function test.collision_long_long_merge(t)
	local _lines = {
		{notes = {{column = 1, type = "2"}}},
		{notes = {{column = 1, type = "3"}}},
		{notes = {{column = 1, type = "2"}}, same = true},
		{notes = {{column = 1, type = "3"}}},
	}

	local plines = SphPreview:linesToPreviewLines(_lines)
	t:tdeq(plines, {
		{notes = {true}},
		{notes = {}},
		{notes = {false}},
	})
end

function test.continuation_bytes(t)
	local s = {
		0b0, 0b0, 0b0, -- header

		-- Test frac_part with high bit (n = 128)
		0b01000000, -- new line
		0b00100000, -- frac add (int=0, frac_high=0)
		0b10000000, -- frac_low = 128 (high bit set!)

		-- Test double_den with high bit (n = 129)
		0b01010000, -- rel time, double, den=16, single=0 -> den = (0+1)*16 = 16
		0b10000001, -- numerator = 129 (high bit set!)
	}

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)

	t:tdeq(lines, {
		{offset = 128 / 1024},
		{time = {129, 16}},
	})
end

return test
