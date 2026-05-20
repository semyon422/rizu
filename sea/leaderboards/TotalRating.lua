local class = require("class")
local erfunc = require("chart.scoring.erfunc")
local RatingCalc = require("sea.leaderboards.RatingCalc")

---@class sea.TotalRating
---@operator call: sea.TotalRating
---@field accuracy number
---@field rating number
---@field rating_msd number
---@field rating_pp number
---@field chartmeta_level number
---@field difftable_level number
local TotalRating = class()

TotalRating.avg_count = 20

-- 50% = 0.047
TotalRating.start_accuracy = 0.032 / (erfunc.erfinv(0.5) * math.sqrt(2))

function TotalRating:new()
	self.accuracy = 0
	self.rating = 0
	self.rating_msd = 0
	self.rating_pp = 0
	self.chartmeta_level = 0
	self.difftable_level = 0
end

---@param cpvs sea.Chartplayview[]
function TotalRating:calc(cpvs)
	self:new()

	local accuracy = self.accuracy
	local rating = self.rating
	local rating_msd = self.rating_msd
	local rating_pp = self.rating_pp
	local chartmeta_level = self.chartmeta_level
	local difftable_level = self.difftable_level

	local avg_count = self.avg_count
	local _avg_count = 0

	for i, cp in ipairs(cpvs) do
		if i <= avg_count then
			_avg_count = _avg_count + 1
			accuracy = accuracy + cp.accuracy
			rating = rating + cp.rating
			rating_msd = rating_msd + cp.rating_msd
			chartmeta_level = rating_msd + (cp.chartmeta_level or 0)
			difftable_level = rating_msd + (cp.difftable_level or 0)
		end
		rating_pp = rating_pp + cp.rating_pp * 0.95 ^ (i - 1)
	end

	local missing = avg_count - _avg_count
	if missing > 0 then
		accuracy = accuracy + missing * self.start_accuracy
	end

	self.accuracy = accuracy / avg_count
	self.rating = rating / avg_count
	self.rating_msd = rating_msd / avg_count
	self.rating_pp = rating_pp
	self.chartmeta_level = chartmeta_level / avg_count
	self.difftable_level = difftable_level / avg_count
end

---@param rating_calc sea.RatingCalc
---@return number
function TotalRating:get(rating_calc)
	return self[RatingCalc:column(rating_calc)]
end

return TotalRating
