local erfunc = require("libchart.erfunc")

---@class normalscore
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
normalscore.ratio_score = 0
normalscore.miss_addition = 0

local mt = {__index = normalscore}

---@return normalscore
function normalscore:new()
	local ns = {
		ranges = {},
		mean_sums = {},
		hit_counts = {},
		sample_counts = {},
	}
	return setmetatable(ns, mt)
end

---@param sigma number
---@param name any
---@return number
---@return number
function normalscore:eq1i(sigma, name)
	local N = self.samples_count
	local H_i = self.hit_counts[name]
	local N_i = self.sample_counts[name]
	local mean_i = self.mean_sums[name] / H_i

	local range = self.ranges[name]
	local t_L, t_R = range[1], range[2]
	if t_L == t_R then -- both nil or equal
		t_L, t_R = self:get_max_range()
		mean_i = self.mean
	end
	t_L, t_R = t_L - mean_i, t_R - mean_i

	local s = 1 / (sigma * math.sqrt(2))
	return
		N_i / (2 * N) * (erfunc.erf(t_R * s) - erfunc.erf(t_L * s)) - H_i / N,
		(-t_R * math.exp(-(t_R * s) ^ 2) + t_L * math.exp(-(t_L * s) ^ 2)) / (sigma ^ 2 * math.sqrt(2 * math.pi))
end

---@param sigma number
---@return number
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

---@param range_name any
---@return table
function normalscore:get_range(range_name)
	local ranges = self.ranges

	local range = ranges[range_name]
	if range then
		return range
	end

	ranges[range_name] = {}
	self.mean_sums[range_name] = 0
	self.hit_counts[range_name] = 0
	self.sample_counts[range_name] = 0

	return ranges[range_name]
end

---@return number
---@return number
function normalscore:get_max_range()
	local ranges = self.ranges

	local l, r = math.huge, -math.huge
	for _, range in pairs(ranges) do
		if range[1] then
			l = math.min(l, range[1])
			r = math.max(r, range[2])
		end
	end

	return l, r
end

---@param range table
---@return number
---@return number
function normalscore:unpack_range(range)
	if range[1] then
		return range[1], range[2]
	end
	return self:get_max_range()
end

---@param range_name any
---@param delta_time number
function normalscore:hit(range_name, delta_time)
	local range = self:get_range(range_name)

	range[1] = math.min(range[1] or delta_time, delta_time)
	range[2] = math.max(range[2] or delta_time, delta_time)

	self.samples_count = self.samples_count + 1
	self.sample_counts[range_name] = self.sample_counts[range_name] + 1

	self.hit_count = self.hit_count + 1
	self.hit_counts[range_name] = self.hit_counts[range_name] + 1

	self.mean_sum = self.mean_sum + delta_time
	self.mean_sums[range_name] = self.mean_sums[range_name] + delta_time
	self.mean = self.mean_sum / self.hit_count

	self.variance_sum = self.variance_sum + delta_time ^ 2
	self.variance = self.variance_sum / self.hit_count
end

---@param range_name any
function normalscore:miss(range_name)
	self:get_range(range_name)

	self.samples_count = self.samples_count + 1
	self.sample_counts[range_name] = self.sample_counts[range_name] + 1

	self.miss_count = self.miss_count + 1
end

function normalscore:update()
	local mean = self.mean
	local H, M, N = self.hit_count, self.miss_count, self.samples_count

	if M == 0 and H == 0 then
		self.score_squared = 0
		self.score = 0
		return
	end

	if M == 0 and H > 0 then
		self.score_squared = self.variance - mean ^ 2
		self.score = math.sqrt(self.score_squared)
		return
	end

	if M > 0 and H == 0 then
		self.score_squared = math.huge
		self.score = math.huge
		return
	end

	local minL, maxR = self:get_max_range()
	if minL == maxR then
		local s = M == 0 and 0 or math.huge
		self.score_squared = s
		self.score = s
		return
	end

	-- initial estimate using t_0 = (maxR - minL) / 2
	local sigma_m_init = (maxR - minL) / (2 * erfunc.erfinv(H / N) * math.sqrt(2))
	local sigma_m = sigma_m_init

	local x
	local k = 1
	repeat
		x = sigma_m
		sigma_m = sigma_m - self:eq1(sigma_m)
		k = k + 1
		if sigma_m ~= sigma_m or math.abs(sigma_m) == math.huge then -- quick hack, fix this later
			sigma_m = sigma_m_init
			break
		end
	until x == sigma_m or k > 20
	self.ratio_score = sigma_m

	local sum_NdT = 0
	for name, range in pairs(self.ranges) do
		local t_L, t_R = self:unpack_range(range)
		local tau_L = (t_L - mean) / (sigma_m * math.sqrt(2))
		local tau_R = (t_R - mean) / (sigma_m * math.sqrt(2))
		sum_NdT = sum_NdT +
			(tau_R * math.exp(-tau_R ^ 2) - tau_L * math.exp(-tau_L ^ 2)) /
			math.sqrt(math.pi) * self.sample_counts[name]
	end

	self.miss_addition = sigma_m ^ 2 * (self.miss_count + sum_NdT) / N

	local score_squared = H / N * (self.variance - mean ^ 2) + self.miss_addition

	self.score_squared = score_squared
	self.score = math.sqrt(score_squared)
end

return normalscore
