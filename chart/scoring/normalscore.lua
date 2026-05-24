local erfunc = require("chart.scoring.erfunc")

local normalscore = {}

normalscore.hit_count = 0
normalscore.miss_count = 0
normalscore.mean_sum = 0
normalscore.mean = 0
normalscore.variance_sum = 0
normalscore.variance = 0
normalscore.score = 0
normalscore.score_adjusted = 0

function normalscore:new()
	return setmetatable({}, {__index = self})
end

function normalscore:hit(delta_time, hit_timing_window)
	if math.abs(delta_time) <= hit_timing_window then
		self.hit_count = self.hit_count + 1
		self.mean_sum = self.mean_sum + delta_time
		self.variance_sum = self.variance_sum + delta_time ^ 2
		self.mean = self.mean_sum / self.hit_count
		self.variance = self.variance_sum / self.hit_count
	else
		self.miss_count = self.miss_count + 1
	end

	local score_squared = self.variance
	if self.miss_count > 0 then
		local N = self.hit_count + self.miss_count
		local hit_ratio = self.hit_count / N
		local s = erfunc.erfinv(hit_ratio)

		score_squared =
			self.variance_sum / N +
			(hit_timing_window / s) ^ 2 * (1 + 2 * s / math.sqrt(math.pi) * math.exp(-s ^ 2) - hit_ratio) / 2
	end

	self.score = math.sqrt(score_squared)
	self.score_adjusted = math.sqrt(score_squared - self.mean ^ 2)
end

return normalscore
