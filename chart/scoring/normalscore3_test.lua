local normalscore = require("chart.scoring.normalscore3")

local test = {}

local function norm_values(n, mu, sigma)
	math.randomseed(0)
	local values = {}

	while true do
		local u, v
		local s = 0
		while s == 0 or s >= 1 do
			u = math.random() * 2 - 1
			v = math.random() * 2 - 1
			s = u ^ 2 + v ^ 2
		end

		local z_0 = u * math.sqrt(-2 * math.log(s) / s)
		local z_1 = v * math.sqrt(-2 * math.log(s) / s)

		values[#values + 1] = z_0 * sigma + mu
		if #values == n then break end
		values[#values + 1] = z_1 * sigma + mu
		if #values == n then break end
	end

	return values
end

function test.basic(t)
	local ns = normalscore:new()

	local function press(t, range, name)
		if t >= range[1] and t <= range[2] then
			ns:hit(name, t)
			return
		end
		ns:miss(name)
	end

	local sigma = 0.02
	local mu = 1000

	local values1 = norm_values(1e4, mu, sigma)
	local range1 = {-0.02 + mu, 0.02 + mu}
	for _, v in ipairs(values1) do
		press(v, range1, "range1")
	end

	local values2 = norm_values(1e4, mu, sigma)
	local range2 = {-0.03 + mu, 0.03 + mu}
	for _, v in ipairs(values2) do
		press(v, range2, "range2")
	end

	ns:update()

	t:lt(math.abs(ns.score - sigma) / sigma, 0.01)
	t:assert(ns.ranges.range1[1] > 0)
	t:assert(ns.ranges.range1[2] > 0)
end

local function is_inf(score)
	return math.abs(score) == math.huge
end

local function is_nan(score)
	return score ~= score
end

local function is_valid(score)
	return not is_inf(score) and not is_nan(score)
end

function test.test1(t)
	local ns = normalscore:new()
	ns:hit("A", 0.1)
	ns:update()
	t:assert(is_valid(ns.score))
end

function test.test2(t)
	local ns = normalscore:new()
	ns:miss("A")
	ns:update()
	t:assert(is_inf(ns.score))
end

function test.test3(t)
	local ns = normalscore:new()
	ns:hit("A", 0.1)
	ns:miss("A")
	ns:update()
	t:assert(is_inf(ns.score))
end

function test.test4(t)
	local ns = normalscore:new()
	ns:hit("A", 0.1)
	ns:hit("A", 0.11)
	ns:miss("B")
	ns:update()
	t:assert(is_valid(ns.score))
end

function test.test5(t)
	local ns = normalscore:new()
	ns:hit("A", 0.1)
	ns:hit("B", 0.11)
	ns:miss("B")
	ns:update()
	t:assert(is_valid(ns.score))
end

function test.test6(t)
	local ns = normalscore:new()
	ns:hit("A", 0.1)
	ns:hit("A", 0.11)
	ns:hit("B", 0.12)
	ns:hit("B", 0.13)
	ns:miss("B")
	ns:update()
	t:assert(is_valid(ns.score))
end

-- a case with inf/nan sigma_m, fix it later
function test.test7(t)
	local ns = normalscore:new()

	ns.ranges.a = {0.1223646190068, -0.010260595034254}


	ns.samples_count = 37
	ns.hit_counts.a = 35
	ns.sample_counts.a = 37
	ns.mean_sums.a = 0.011442789872754 * ns.hit_counts.a

	local a, b = ns:eq1i(0.00041512071994903, "a")
	-- print(a, b, a / b)
end

function test.test8(t)
	local ns = normalscore:new()
	ns:hit("A", 0.1)
	ns:miss("B")
	ns:miss("B")
	ns:update()
	t:assert(is_inf(ns.score))
end

return test
