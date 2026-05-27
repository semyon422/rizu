--- Score representation for osu! scores.
---
--- Supports parsing from submission data (colon-delimited string),
--- calculating accuracy per game mode, and computing grades.

local Grade = require("bancho.constants.Grade")
local Mods = require("bancho.constants.Mods")

local class = require("class")

--- Score submission status.
local SubmissionStatus = require("bancho.constants.SubmissionStatus")

--- Client anticheat flags (placeholder).
local ClientFlags = {NONE = 0}

---@class bancho.model.Score
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
function Score:fromSubmission(data)
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
	self.server_time = tonumber(data[15])
	return self
end

--- Calculate accuracy for the current score's game mode.
function Score:calculateAccuracy()
	local mode_vn = self.mode % 4

	if mode_vn == 0 then
		-- osu!std
		local total = self.n300 + self.n100 + self.n50 + self.nmiss
		if total == 0 then return 0.0 end
		return 100.0 * ((self.n300 * 300 + self.n100 * 100 + self.n50 * 50) / (total * 300))

	elseif mode_vn == 1 then
		-- taiko
		local total = self.n300 + self.n100 + self.nmiss
		if total == 0 then return 0.0 end
		return 100.0 * ((self.n100 * 0.5 + self.n300) / total)

	elseif mode_vn == 2 then
		-- catch
		local total = self.n300 + self.n100 + self.n50 + self.nkatu + self.nmiss
		if total == 0 then return 0.0 end
		return 100.0 * (self.n300 + self.n100 + self.n50) / total

	elseif mode_vn == 3 then
		-- mania
		local total = self.n300 + self.n100 + self.n50 + self.ngeki + self.nkatu + self.nmiss
		if total == 0 then return 0.0 end
		if self.mods ~= nil and bit.band(self.mods, Mods.SCOREV2) ~= 0 then
			-- ScoreV2: geki = 305, katu = 200, max = 305
			return 100.0 * ((self.n50 * 50 + self.n100 * 100 + self.nkatu * 200 + self.n300 * 300 + self.ngeki * 305) / (total * 305))
		end
		-- Default: geki = 300, katu = 200, max = 300
		return 100.0 * ((self.n50 * 50 + self.n100 * 100 + self.nkatu * 200 + (self.n300 + self.ngeki) * 300) / (total * 300))
	end

	return 0.0
end

return Score
