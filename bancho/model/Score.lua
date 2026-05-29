--- Score representation for osu! scores.
---
--- Supports parsing from submission data (colon-delimited string),
--- calculating accuracy per game mode, computing grades, and
--- computing the online checksum for score verification.

local Grade = require("bancho.constants.Grade")
local Mods = require("bancho.constants.Mods")
local osu_pp = require("chart.scoring.osu_pp")

local class = require("class")

--- Score submission status.
local SubmissionStatus = require("bancho.constants.SubmissionStatus")

--- Client anticheat flags (placeholder).
local ClientFlags = {NONE = 0}

--- MD5 hash via OpenSSL FFI.
--- Returns hex digest of the input string.
---@param input string
---@return string hex_md5
local function md5(input)
	local ffi = require("ffi")
	local C = ffi.load("crypto")

	ffi.cdef[[
		int EVP_Digest(const void *data, int count, unsigned char *md, unsigned int *md_len, const void *type, void *impl);
		const void *EVP_md5();
	]]

	local md = ffi.new("unsigned char[16]")
	local md_len = ffi.new("unsigned int[1]", 0)
	C.EVP_Digest(input, #input, md, md_len, C.EVP_md5(), nil)

	local hex = ""
	for i = 0, 15 do
		hex = hex .. string.format("%02x", md[i])
	end
	return hex
end

---@class bancho.model.Score
---@operator call: bancho.model.Score
---@field mode integer vanilla mode (0-3)
---@field mods integer mods bitmask
---@field n300 integer
---@field n100 integer
---@field n50 integer
---@field ngeki integer
---@field nkatu integer
---@field nmiss integer
---@field score integer
---@field max_combo integer
---@field perfect boolean
---@field grade bancho.Grade
---@field passed boolean
---@field accuracy number
---@field pp number
---@field sr number
---@field server_time number unix timestamp
---@field client_checksum string client-provided online checksum
---@field client_time string play time string (yyMMddHHmmss)
local Score = class()

function Score:new()
	self.mode = 0
	self.mods = 0
	self.n300 = 0
	self.n100 = 0
	self.n50 = 0
	self.ngeki = 0
	self.nkatu = 0
	self.nmiss = 0
	self.score = 0
	self.max_combo = 0
	self.perfect = false
	self.grade = Grade.N
	self.passed = false
	self.accuracy = 0
	self.pp = 0
	self.sr = 0
	self.server_time = 0
	self.client_checksum = ""
	self.client_time = ""
	return self
end

--- Parse a score from the colon-delimited submission string.
---
--- Format (1-based indexing):
---   [1] online_checksum
---   [2] n300
---   [3] n100
---   [4] n50
---   [5] ngeki
---   [6] nkatu
---   [7] nmiss
---   [8] score
---   [9] max_combo
---   [10] perfect (True/False)
---   [11] grade (letter)
---   [12] mods (int)
---   [13] passed (True/False)
---   [14] gamemode (int)
---   [15] play_time (yyMMddHHmmss)
---   [16] osu_version + client_flags
---@param data string[] colon-delimited submission fields
---@return bancho.model.Score self
function Score:fromSubmission(data)
	self.client_checksum = data[1] or ""
	self.n300 = tonumber(data[2])
	self.n100 = tonumber(data[3])
	self.n50 = tonumber(data[4])
	self.ngeki = tonumber(data[5])
	self.nkatu = tonumber(data[6])
	self.nmiss = tonumber(data[7])
	self.score = tonumber(data[8])
	self.max_combo = tonumber(data[9])
	self.perfect = data[10] == "True"
	self.grade = Grade.fromString(data[11])
	self.mods = tonumber(data[12])
	self.passed = data[13] == "True"
	self.mode = tonumber(data[14])
	self.client_time = data[15] or ""
	self.server_time = tonumber(data[15])
	return self
end

--- Calculate accuracy for the current score's game mode.
--- Stores the result in self.accuracy and returns it.
---@return number accuracy percentage (0-100)
function Score:calculateAccuracy()
	local mode_vn = self.mode % 4

	if mode_vn == 0 then
		-- osu!std
		local total = self.n300 + self.n100 + self.n50 + self.nmiss
		if total == 0 then self.accuracy = 0.0; return 0.0 end
		self.accuracy = 100.0 * ((self.n300 * 300 + self.n100 * 100 + self.n50 * 50) / (total * 300))
		return self.accuracy

	elseif mode_vn == 1 then
		-- taiko
		local total = self.n300 + self.n100 + self.nmiss
		if total == 0 then self.accuracy = 0.0; return 0.0 end
		self.accuracy = 100.0 * ((self.n100 * 0.5 + self.n300) / total)
		return self.accuracy

	elseif mode_vn == 2 then
		-- catch
		local total = self.n300 + self.n100 + self.n50 + self.nkatu + self.nmiss
		if total == 0 then self.accuracy = 0.0; return 0.0 end
		self.accuracy = 100.0 * (self.n300 + self.n100 + self.n50) / total
		return self.accuracy

	elseif mode_vn == 3 then
		-- mania
		local total = self.n300 + self.n100 + self.n50 + self.ngeki + self.nkatu + self.nmiss
		if total == 0 then self.accuracy = 0.0; return 0.0 end
		if self.mods ~= nil and bit.band(self.mods, Mods.SCOREV2) ~= 0 then
			-- ScoreV2: geki = 305, katu = 200, max = 305
			self.accuracy = 100.0 * ((self.n50 * 50 + self.n100 * 100 + self.nkatu * 200 + self.n300 * 300 + self.ngeki * 305) / (total * 305))
		else
			-- Default: geki = 300, katu = 200, max = 300
			self.accuracy = 100.0 * ((self.n50 * 50 + self.n100 * 100 + self.nkatu * 200 + (self.n300 + self.ngeki) * 300) / (total * 300))
		end
		return self.accuracy
	end

	self.accuracy = 0.0
	return 0.0
end

--- Calculate performance points (PP) for this score.
---
--- Uses the chart.scoring.osu_pp module which implements the mania PP formula.
--- For other modes (osu!, taiko, catch), returns 0 as those modes are not yet implemented.
---
---@param beatmap bancho.model.Beatmap beatmap with star rating and OD
---@return number pp
function Score:calculatePP(beatmap)
	local mode_vn = self.mode % 4

	local stars = beatmap.diff or 0
	local od = beatmap.od or 0

	-- Total number of hit objects
	local total_notes = self.n300 + self.n100 + self.n50 + self.ngeki + self.nkatu + self.nmiss

	-- Accuracy as ratio [0, 1]
	local acc_ratio = self.accuracy / 100

	if mode_vn == 3 then
		-- osu!mania
		self.pp = osu_pp.calc(acc_ratio, stars, total_notes, od)
		self.sr = stars
		return self.pp
	end

	-- Other modes not yet implemented
	self.pp = 0
	self.sr = stars
	return self.pp
end

--- Compute the online checksum for score verification.
---
--- The checksum is an MD5 hash of a specific string format that the osu! client
--- also computes. If the server's computed checksum doesn't match the client's
--- checksum, the score is rejected as tampered.
---
--- Format string (bancho.py reference):
--- "chickenmcnuggets{n300+n100}o15{n50}{ngeki}smustard{nkatu}{nmiss}uu{map_md5}{max_combo}{perfect}{username}{score}{grade}{mods}Q{passed}{mode}{osu_version}{play_time}{client_hash}{storyboard_md5}"
---
---@param username string player name
---@param map_md5 string beatmap MD5
---@param osu_version string osu! client version (e.g. "20240101")
---@param client_hash string decoded client hash
---@param storyboard_md5 string storyboard MD5 (may be empty)
---@return string hex_md5 computed checksum
function Score:computeOnlineChecksum(username, map_md5, osu_version, client_hash, storyboard_md5)
	local str = string.format(
		"chickenmcnuggets%d o15%d%dsmustard%d%duu%s%d%s%s%d%s%dQ%s%d%s%s%s%s",
		self.n100 + self.n300,
		self.n50,
		self.ngeki,
		self.nkatu,
		self.nmiss,
		map_md5,
		self.max_combo,
		self.perfect and "True" or "False",
		username,
		self.score,
		self.grade.label,
		self.mods,
		self.passed and "True" or "False",
		self.mode % 4,
		osu_version,
		self.client_time,
		client_hash,
		storyboard_md5 or ""
	)

	return md5(str)
end

return Score
