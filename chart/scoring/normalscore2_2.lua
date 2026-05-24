local erfunc = require("chart.scoring.erfunc")

local normalscore = {}

normalscore.samples_count = 0
normalscore.hit_count = 0
normalscore.miss_count = 0
normalscore.mean_sum = 0
normalscore.mean = 0
normalscore.variance_sum = 0
normalscore.variance = 0
normalscore.score_squared = 0
normalscore.score = 0
normalscore.score_adjusted = 0
normalscore.ratio_score = 0
normalscore.miss_addition = 0

local mt = {__index = normalscore}

function normalscore:new()
	local ns = {
		ranges = {},
		hit_counts = {},
		samples_counts = {},
	}
	return setmetatable(ns, mt)
end

function normalscore:eq1i(sigma, name)
	local N = self.samples_count
	local range = self.ranges[name]
	local t_L, t_R = range[1], range[2]
	local H_i = self.hit_counts[name]
	local N_i = self.samples_counts[name]

	local s = 1 / (sigma * math.sqrt(2))
	return
		N_i / (2 * N) * (erfunc.erf(t_R * s) - erfunc.erf(t_L * s)) - H_i / N,
		(-t_R * math.exp(-(t_R * s) ^ 2) + t_L * math.exp(-(t_L * s) ^ 2)) / (sigma ^ 2 * math.sqrt(2 * math.pi))
end

function normalscore:eq1(sigma)
	local sum1 = 0
	local sum2 = 0
	for name in pairs(self.ranges) do
		local s1, s2 = self:eq1i(sigma, name)
		sum1 = sum1 + s1
		sum2 = sum2 + s2
	end
	return sum1 / sum2
end

function normalscore:get_range(range_name)
	local ranges = self.ranges

	local range = ranges[range_name]
	if range then
		return range
	end

	ranges[range_name] = {0, 0}
	self.hit_counts[range_name] = 0
	self.samples_counts[range_name] = 0

	return ranges[range_name]
end

function normalscore:hit(range_name, delta_time)
	local range = self:get_range(range_name)

	range[1] = math.min(range[1], delta_time)
	range[2] = math.max(range[2], delta_time)

	self.samples_count = self.samples_count + 1
	self.samples_counts[range_name] = self.samples_counts[range_name] + 1

	self.hit_count = self.hit_count + 1
	self.hit_counts[range_name] = self.hit_counts[range_name] + 1

	self.mean_sum = self.mean_sum + delta_time
	self.mean = self.mean_sum / self.hit_count

	self.variance_sum = self.variance_sum + delta_time ^ 2
	self.variance = self.variance_sum / self.hit_count
end

function normalscore:miss(range_name)
	self:get_range(range_name)

	self.samples_count = self.samples_count + 1
	self.samples_counts[range_name] = self.samples_counts[range_name] + 1

	self.miss_count = self.miss_count + 1
end

function normalscore:update()
	local N = self.hit_count + self.miss_count

	if self.miss_count > 0 and self.hit_count > 0 then
		local tau_0 = erfunc.erfinv(self.hit_count / N)

		local sum = 0
		local sum_weights = 0
		for name, range in pairs(self.ranges) do
			local t_L, t_R = range[1], range[2]
			sum = sum + (t_R - t_L) / (2 * tau_0 * math.sqrt(2)) * self.hit_counts[name]
			sum_weights = sum_weights + self.hit_counts[name]
		end
		local sigma_m = sum / sum_weights

		local x
		local k = 1
		repeat
			x = sigma_m
			sigma_m = sigma_m - self:eq1(sigma_m)
			k = k + 1
		until x == sigma_m or k > 20
		self.ratio_score = sigma_m

		local sum_NdT = 0
		for name, range in pairs(self.ranges) do
			local t_L, t_R = range[1], range[2]
			local tau_L = t_L / (sigma_m * math.sqrt(2))
			local tau_R = t_R / (sigma_m * math.sqrt(2))
			sum_NdT = sum_NdT +
				(tau_R * math.exp(-tau_R ^ 2) - tau_L * math.exp(-tau_L ^ 2)) /
				math.sqrt(math.pi) * self.samples_counts[name]
		end

		self.miss_addition = sigma_m ^ 2 * (self.miss_count + sum_NdT) / N
	elseif self.miss_count > 0 and self.hit_count == 0 then
		self.ratio_score = math.huge
		self.miss_addition = math.huge
	end

	local score_squared = self.variance_sum / math.max(N, 1) + self.miss_addition

	self.score_squared = score_squared
	self.score = math.sqrt(score_squared)
	self.score_adjusted = math.sqrt(score_squared - self.mean ^ 2)
end

return normalscore
