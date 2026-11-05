local class = require("class")
local time_util = require("time_util")
local brand = require("brand")

local ModifierModel = require("sphere.models.ModifierModel")

---@class sea.ChartPage
---@operator call: sea.ChartPage
local ChartPage = class()

---@param user sea.User
---@param chartmeta sea.Chartmeta
---@param chartdiff sea.Chartdiff
---@param chartplays sea.Chartplay[]
function ChartPage:new(user, chartmeta, chartdiff, chartplays)
	self.user = user
	self.chartmeta = chartmeta
	self.chartdiff = chartdiff
	self.chartplays = chartplays
	self.rating_calc = self:getPreferredRatingCalc()
end

---@return string
function ChartPage:getPreferredRatingCalc()
	return self.user.preferred_rating_calc or "enps"
end

---@return string?
function ChartPage:getBackgroundUrl()
	if self.chartmeta.format == "osu" then
		return ("https://assets.ppy.sh/beatmaps/%i/covers/cover.jpg?%i"):format(self.chartmeta.osu_beatmapset_id, os.time())
	end
end

---@return string?
function ChartPage:getDownloadUrl()
	if self.chartmeta.format == "osu" then
		return ("https://osu.ppy.sh/beatmapsets/%i"):format(self.chartmeta.osu_beatmapset_id)
	end
end

---@return string
function ChartPage:getGameName()
	local f = self.chartmeta.format

	if f == "osu" then
		return "osu!"
	elseif f == "bms" then
		return "BMS"
	elseif f == "ksm" then
		return "K-Shoot MANIA"
	elseif f == "midi" then
		return "MIDI"
	elseif f == "o2jam" then
		return "o2jam"
	elseif f == "sphere" then
		return brand:lower()
	elseif f == "quaver" then
		return "Quaver"
	elseif f == "stepmania" then
		return "StepMania"
	end

	return "Unknown game"
end

---@return number
function ChartPage:getDifficulty()
	if self.rating_calc == "pp" then
		return self.chartdiff.osu_diff
	end
	return self.chartdiff.enps_diff
end

---@return number
function ChartPage:getDifficultyHue()
	local x = 0

	if self.rating_calc == "pp" then
		x = math.min(10, self.chartdiff.osu_diff) / 10
	elseif self.rating_calc == "enps" then
		x = math.min(self.chartdiff.enps_diff, 35) / 35
	end

	return ((-x + 0.6) % 1) * 360
end

function ChartPage:getDifficultyPostfix()
	if self.rating_calc == "pp" then
		return "☆"
	end
	return "ENPS"
end

---@return string
function ChartPage:getDuration()
	return time_util.format((self.chartdiff.duration or 0))
end

---@return number
function ChartPage:getDurationHue()
	local x = math.min(self.chartdiff.duration * 0.8, 420) / 420
	return ((-x + 0.6) % 1) * 360
end

---@return number
function ChartPage:getLnPercent()
	return (self.chartdiff.judges_count - self.chartdiff.notes_count) / self.chartdiff.notes_count
end

---@param time number
function ChartPage:formatTimeAgo(time)
	local time_ago = os.time() - time
	local days = math.floor(time_ago / (60 * 60 * 24))
	local hours = math.floor(time_ago / (60 * 60))
	local minutes = math.floor(time_ago / 60)

	if minutes < 60 then
		return ("%imin"):format(minutes)
	elseif hours < 24 then
		return ("%ih"):format(hours)
	else
		return ("%id"):format(days)
	end
end

---@param cpv sea.Chartplay
---@return string
function ChartPage:formatModifiers(cpv)
	local modifiers = ""

	if #cpv.modifiers ~= 0 then
		modifiers = ModifierModel:getString(cpv.modifiers)
		modifiers = modifiers .. " "
	end

	if cpv.const then
		modifiers = modifiers .. "CONST "
	end

	if cpv.tap_only then
		modifiers = modifiers .. "TAP "
	end

	if modifiers == "" then
		modifiers = "-"
	end

	return modifiers
end

---@param cpv sea.Chartplay
---@return number
function ChartPage:getRating(cpv)
	if self.rating_calc == "pp" then
		return cpv.rating_pp
	end

	return cpv.rating
end

function ChartPage:getScores()
	local scores = {}

	for rank, cpv in ipairs(self.chartplays) do
		table.insert(scores, {
			rank = rank,
			username = "Username",
			country_code = "gb",
			grade = cpv:getGrade(),
			accuracy = cpv.accuracy,
			norm_accuracy = cpv:getNormAccuracy(),
			perfect_count = cpv.judges[1],
			not_perfect_count = cpv.not_perfect_count,
			miss_count = cpv.miss_count,
			modifiers = self:formatModifiers(cpv),
			rate = cpv.rate,
			rating = self:getRating(cpv),
			time_ago = self:formatTimeAgo(cpv.submitted_at)
		})
	end

	return scores
end

return ChartPage
