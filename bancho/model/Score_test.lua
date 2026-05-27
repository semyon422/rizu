--- Tests for bancho model Score.

local Score = require("bancho.model.Score")
local Grade = require("bancho.constants.Grade")

local test = {}

function test.score_fromSubmission(t)
	local s = Score:new():fromSubmission({
		"",                 -- [1] online_checksum
		"123",              -- [2] n300
		"45",               -- [3] n100
		"12",               -- [4] n50
		"5",                -- [5] ngeki
		"3",                -- [6] nkatu
		"2",                -- [7] nmiss
		"123456",           -- [8] score
		"500",              -- [9] max_combo
		"True",             -- [10] perfect
		"xh",               -- [11] grade
		"1048576",          -- [12] mods
		"True",             -- [13] passed
		"0",                -- [14] gamemode
		"240101120000",     -- [15] play_time
		"",                 -- [16] osu_version
	})
	t:eq(s.n300, 123)
	t:eq(s.n100, 45)
	t:eq(s.n50, 12)
	t:eq(s.ngeki, 5)
	t:eq(s.nkatu, 3)
	t:eq(s.nmiss, 2)
	t:eq(s.score, 123456)
	t:eq(s.max_combo, 500)
	t:eq(s.perfect, true)
	t:eq(s.grade, Grade.XH)
	t:eq(s.passed, true)
	t:eq(s.mode, 0)
end

function test.accuracy_osu(t)
	local s = Score:new()
	s.n300 = 300; s.n100 = 10; s.n50 = 5; s.nmiss = 2; s.mode = 0
	local acc = s:calculateAccuracy()
	t:assert(acc > 95.9 and acc < 96.0, "acc=" .. tostring(acc))
end

function test.accuracy_osu_empty(t)
	local s = Score:new()
	s.n300 = 0; s.n100 = 0; s.n50 = 0; s.nmiss = 0; s.mode = 0
	t:eq(s:calculateAccuracy(), 0)
end

function test.accuracy_taiko(t)
	local s = Score:new()
	s.n300 = 200; s.n100 = 100; s.nmiss = 5; s.mode = 1
	local acc = s:calculateAccuracy()
	t:assert(acc > 81.9 and acc < 82.0, "acc=" .. tostring(acc))
end

function test.accuracy_catch(t)
	local s = Score:new()
	s.n300 = 300; s.n100 = 50; s.n50 = 10; s.nkatu = 5; s.nmiss = 3; s.mode = 2
	local acc = s:calculateAccuracy()
	t:assert(acc > 97.8 and acc < 97.9, "acc=" .. tostring(acc))
end

function test.accuracy_mania(t)
	local s = Score:new()
	s.n300 = 300; s.ngeki = 20; s.n100 = 50; s.nkatu = 10; s.n50 = 5; s.nmiss = 2; s.mode = 3
	local acc = s:calculateAccuracy()
	t:assert(acc > 88.9 and acc < 89.0, "acc=" .. tostring(acc))
end

function test.grade_fromString(t)
	t:eq(Grade.fromString("xh"), Grade.XH)
	t:eq(Grade.fromString("x"), Grade.X)
	t:eq(Grade.fromString("sh"), Grade.SH)
	t:eq(Grade.fromString("s"), Grade.S)
	t:eq(Grade.fromString("a"), Grade.A)
	t:eq(Grade.fromString("b"), Grade.B)
	t:eq(Grade.fromString("c"), Grade.C)
	t:eq(Grade.fromString("d"), Grade.D)
	t:eq(Grade.fromString("f"), Grade.F)
	t:eq(Grade.fromString("n"), Grade.N)
end

return test
