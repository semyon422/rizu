--- Tests for bancho Score model.

local Score = require("bancho.model.Score")
local Beatmap = require("bancho.model.Beatmap")
local Grade = require("bancho.constants.Grade")
local Mods = require("bancho.constants.Mods")

local test = {}

function test.fromSubmission(t)
	local score = Score:new()
	score:fromSubmission({
		"abc123", -- checksum
		"100", -- n300
		"50", -- n100
		"25", -- n50
		"10", -- ngeki
		"5", -- nkatu
		"3", -- nmiss
		"123456", -- score
		"500", -- max_combo
		"True", -- perfect
		"s", -- grade
		"0", -- mods
		"True", -- passed
		"0", -- mode
		"240101120000", -- play_time
		"20240101", -- osu_version
	})

	t:eq(score.n300, 100)
	t:eq(score.n100, 50)
	t:eq(score.n50, 25)
	t:eq(score.ngeki, 10)
	t:eq(score.nkatu, 5)
	t:eq(score.nmiss, 3)
	t:eq(score.score, 123456)
	t:eq(score.max_combo, 500)
	t:eq(score.perfect, true)
	t:eq(score.grade, Grade.S)
	t:eq(score.mods, 0)
	t:eq(score.passed, true)
	t:eq(score.mode, 0)
	t:eq(score.client_checksum, "abc123")
	t:eq(score.client_time, "240101120000")
end

function test.calculateAccuracy_osu(t)
	local score = Score:new()
	score.n300 = 100
	score.n100 = 50
	score.n50 = 25
	score.nmiss = 3
	score.mode = 0

	local acc = score:calculateAccuracy()
	-- (100*300 + 50*100 + 25*50) / (178 * 300) * 100 = 67.88...
	t:aeq(acc, 67.883895131086, 0.001)
end

function test.calculateAccuracy_taiko(t)
	local score = Score:new()
	score.n300 = 100
	score.n100 = 50
	score.nmiss = 3
	score.mode = 1

	local acc = score:calculateAccuracy()
	-- (100 + 50*0.5) / 153 * 100 = 81.69...
	t:aeq(acc, 81.699346405229, 0.001)
end

function test.calculateAccuracy_mania_scorev2(t)
	local score = Score:new()
	score.n300 = 100
	score.n100 = 50
	score.n50 = 25
	score.ngeki = 10
	score.nkatu = 5
	score.nmiss = 3
	score.mode = 3
	score.mods = Mods.SCOREV2

	local acc = score:calculateAccuracy()
	t:ne(acc, 0)
end

function test.computeOnlineChecksum(t)
	local score = Score:new()
	score:fromSubmission({
		"test_checksum",
		"100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"0", "240101120000", "20240101"
	})

	local checksum = score:computeOnlineChecksum(
		"testuser",
		"abc123def456789012345678",
		"20240101",
		"client_hash_abc123",
		""
	)

	-- Verify it returns a valid MD5 hex string (32 chars, hex only)
	t:eq(#checksum, 32)
	t:ne(checksum:match("^[0-9a-f]+$"), nil)
end

function test.computeOnlineChecksum_deterministic(t)
	local score1 = Score:new()
	score1:fromSubmission({
		"checksum", "100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"0", "240101120000", "20240101"
	})

	local score2 = Score:new()
	score2:fromSubmission({
		"checksum", "100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"0", "240101120000", "20240101"
	})

	local cs1 = score1:computeOnlineChecksum("testuser", "abc123def456789012345678", "20240101", "client_hash", "")
	local cs2 = score2:computeOnlineChecksum("testuser", "abc123def456789012345678", "20240101", "client_hash", "")
	t:eq(cs1, cs2)
end

function test.computeOnlineChecksum_different_inputs(t)
	local score1 = Score:new()
	score1:fromSubmission({
		"checksum", "100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"0", "240101120000", "20240101"
	})

	local score2 = Score:new()
	score2:fromSubmission({
		"checksum", "100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"0", "240101120000", "20240101"
	})

	-- Different username produces different checksum
	local cs1 = score1:computeOnlineChecksum("user1", "abc123def456789012345678", "20240101", "client_hash", "")
	local cs2 = score2:computeOnlineChecksum("user2", "abc123def456789012345678", "20240101", "client_hash", "")
	t:ne(cs1, cs2)
end

function test.calculatePP_mania(t)
	local score = Score:new()
	score:fromSubmission({
		"checksum", "100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"3", "240101120000", "20240101"  -- mode 3 = mania
	})
	score:calculateAccuracy()

	local bmap = Beatmap:new()
	bmap.diff = 5.0  -- star rating
	bmap.od = 7

	local pp = score:calculatePP(bmap)
	t:ne(pp, 0)
	t:ne(score.pp, 0)
	t:eq(score.sr, 5.0)
end

function test.calculatePP_mania_high_accuracy(t)
	local score = Score:new()
	score:fromSubmission({
		"checksum", "500", "200", "50", "100", "50", "0",
		"999999", "1000", "False", "x", "0", "True",
		"3", "240101120000", "20240101"  -- mode 3 = mania
	})
	score:calculateAccuracy()

	local bmap = Beatmap:new()
	bmap.diff = 11.39
	bmap.od = 7

	local pp = score:calculatePP(bmap)
	t:ne(pp, 0)
	-- PP should be positive and reasonable for high accuracy on high SR
	t:ne(pp < 10, true)
end

function test.calculatePP_mania_deterministic(t)
	local bmap = Beatmap:new()
	bmap.diff = 5.0
	bmap.od = 7

	local score1 = Score:new()
	score1:fromSubmission({
		"checksum", "100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"3", "240101120000", "20240101"
	})
	score1:calculateAccuracy()
	local pp1 = score1:calculatePP(bmap)

	local score2 = Score:new()
	score2:fromSubmission({
		"checksum", "100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"3", "240101120000", "20240101"
	})
	score2:calculateAccuracy()
	local pp2 = score2:calculatePP(bmap)

	t:eq(pp1, pp2)
end

function test.calculatePP_other_modes_not_implemented(t)
	local score = Score:new()
	score:fromSubmission({
		"checksum", "100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"0", "240101120000", "20240101"  -- mode 0 = osu!std (not implemented)
	})
	score:calculateAccuracy()

	local bmap = Beatmap:new()
	bmap.diff = 5.0
	bmap.od = 7

	local pp = score:calculatePP(bmap)
	t:eq(pp, 0)
	t:eq(score.sr, 5.0)  -- SR still set
end

return test
