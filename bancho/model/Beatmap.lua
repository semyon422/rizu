--- Beatmap metadata container.

local RankedStatus = require("bancho.constants.RankedStatus")

local class = require("class")

---@class bancho.model.Beatmap
---@operator call: bancho.model.Beatmap
---@field md5 string
---@field id integer
---@field set_id integer
---@field artist string
---@field title string
---@field version string
---@field creator string
---@field total_length integer
---@field max_combo integer
---@field status integer RankedStatus.*
---@field mode integer vanilla mode (0-3)
---@field bpm number
---@field cs number circle size
---@field od number overall difficulty
---@field ar number approach rate
---@field hp number drain
---@field diff number star rating
local Beatmap = class()

function Beatmap:new()
	self.md5 = ""
	self.id = 0
	self.set_id = 0
	self.artist = ""
	self.title = ""
	self.version = ""
	self.creator = ""
	self.total_length = 0
	self.max_combo = 0
	self.status = RankedStatus.PENDING
	self.mode = 0
	self.bpm = 0
	self.cs = 0
	self.od = 0
	self.ar = 0
	self.hp = 0
	self.diff = 0
	return self
end

--- Full osu! formatted name: "Artist - Title [Version]".
---@return string
function Beatmap:fullName()
	return self.artist .. " - " .. self.title .. " [" .. self.version .. "]"
end

--- Whether the map has a ranked leaderboard.
---@return boolean
function Beatmap:hasLeaderboard()
	return RankedStatus.hasLeaderboard(self.status)
end

--- Whether scores on this map award ranked PP.
---@return boolean
function Beatmap:awardsRankedPP()
	return RankedStatus.awardsRankedPP(self.status)
end

return Beatmap
