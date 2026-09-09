local class = require("class")

---@alias chart.osu.PathPoint {[1]: number, [2]: number}

---@class chart.osu.SliderPath
---@operator call: chart.osu.SliderPath
---@field points chart.osu.PathPoint[]
---@field distances number[]
local SliderPath = class()

local max_points = 16384
local max_work = 250000

---@param p chart.osu.PathPoint
---@param q chart.osu.PathPoint
---@return number
local function distance(p, q)
	return ((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2) ^ 0.5
end

---@param p chart.osu.PathPoint
---@param q chart.osu.PathPoint
---@param t number
---@return chart.osu.PathPoint
local function lerp(p, q, t)
	return {p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t}
end

---@param p chart.osu.PathPoint
function SliderPath:add(p)
	assert(p[1] == p[1] and p[2] == p[2] and math.abs(p[1]) < math.huge and math.abs(p[2]) < math.huge,
		"invalid slider coordinate")
	local last = self.points[#self.points]
	if last and distance(last, p) == 0 then return end
	assert(#self.points < max_points, "slider path point budget exceeded")
	self.points[#self.points + 1] = {p[1], p[2]}
end

---@param controls chart.osu.PathPoint[]
---@param depth integer?
function SliderPath:bezier(controls, depth)
	depth = depth or 0
	self.work = self.work + (#controls) ^ 2
	assert(self.work <= max_work and depth <= 32, "slider curve work budget exceeded")
	local flat = true
	for i = 2, #controls - 1 do
		local x = controls[i - 1][1] - 2 * controls[i][1] + controls[i + 1][1]
		local y = controls[i - 1][2] - 2 * controls[i][2] + controls[i + 1][2]
		if x * x + y * y > 0.25 then flat = false; break end
	end
	if #controls <= 2 then
		for _, p in ipairs(controls) do self:add(p) end
		return
	end
	---@type chart.osu.PathPoint[], chart.osu.PathPoint[], chart.osu.PathPoint[]
	local work, left, right = {}, {}, {}
	for i, p in ipairs(controls) do work[i] = p end
	for level = #controls, 1, -1 do
		left[#left + 1] = work[1]
		right[level] = work[level]
		for i = 1, level - 1 do work[i] = lerp(work[i], work[i + 1], 0.5) end
	end
	if flat then
		-- Smooth the subdivided control polygon rather than the original polygon.
		---@type chart.osu.PathPoint[]
		local combined = {}
		for _, p in ipairs(left) do combined[#combined + 1] = p end
		for i = 2, #right do combined[#combined + 1] = right[i] end
		self:add(controls[1])
		for i = 2, #controls - 1 do
			self:add(lerp(lerp(combined[2 * i - 2], combined[2 * i], 0.5), combined[2 * i - 1], 0.5))
		end
		self:add(controls[#controls])
	else
		self:bezier(left, depth + 1)
		self:bezier(right, depth + 1)
	end
end

---@param controls chart.osu.PathPoint[]
function SliderPath:bezierParts(controls)
	local part = {controls[1]}
	for i = 2, #controls do
		local p, previous = controls[i], controls[i - 1]
		if distance(p, previous) == 0 then
			self:bezier(part)
			part = {p}
		else
			part[#part + 1] = p
		end
	end
	self:bezier(part)
end

---@param controls chart.osu.PathPoint[]
---@return boolean
function SliderPath:perfect(controls)
	if #controls ~= 3 then return false end
	local a, b, c = unpack(controls)
	local bx, by, cx, cy = b[1] - a[1], b[2] - a[2], c[1] - a[1], c[2] - a[2]
	local cross = bx * cy - by * cx
	if math.abs(cross) < 1e-7 then return false end
	local bl, cl = bx * bx + by * by, cx * cx + cy * cy
	local x = a[1] + (bl * cy - cl * by) / (2 * cross)
	local y = a[2] + (bx * cl - cx * bl) / (2 * cross)
	local radius = distance(a, {x, y})
	local start = math.atan2(a[2] - y, a[1] - x)
	local finish = math.atan2(c[2] - y, c[1] - x)
	local sweep = (finish - start) % (2 * math.pi)
	if cross < 0 then sweep = sweep - 2 * math.pi end
	local step = 2 * math.acos(math.max(-1, 1 - 0.1 / radius))
	local count = math.max(2, math.ceil(math.abs(sweep) / step))
	assert(count < max_points, "slider arc point budget exceeded")
	for i = 0, count do
		local angle = start + sweep * i / count
		self:add({x + radius * math.cos(angle), y + radius * math.sin(angle)})
	end
	return true
end

---@param controls chart.osu.PathPoint[]
function SliderPath:catmull(controls)
	for i = 1, #controls - 1 do
		local p1, p2, p3 = controls[math.max(1, i - 1)], controls[i], controls[i + 1]
		local p4 = controls[i + 2] or lerp(p2, p3, 2)
		for j = 0, 50 do
			local t = j / 50
			---@type chart.osu.PathPoint
			local p = {}
			for axis = 1, 2 do
				local a, b, c, d = p1[axis], p2[axis], p3[axis], p4[axis]
				p[axis] = 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t ^ 2 + (3 * b - a - 3 * c + d) * t ^ 3)
			end
			self:add(p)
		end
	end
end

---@param curve_type string
---@param controls chart.osu.PathPoint[] Includes the slider head.
---@param length number Declared pixel length, not raw control polygon length.
function SliderPath:new(curve_type, controls, length)
	assert(#controls > 0 and #controls <= 1024, "invalid slider control point count")
	assert(length >= 0 and length < math.huge, "invalid slider length")
	self.points, self.distances, self.work = {}, {}, 0
	for _, p in ipairs(controls) do
		assert(p[1] == p[1] and p[2] == p[2] and math.abs(p[1]) < math.huge and math.abs(p[2]) < math.huge, "invalid slider coordinate")
	end
	if curve_type == "L" then
		for _, p in ipairs(controls) do self:add(p) end
	elseif curve_type == "C" then
		self:catmull(controls)
	elseif curve_type == "B" or curve_type == "P" then
		if curve_type ~= "P" or not self:perfect(controls) then self:bezierParts(controls) end
	else
		error("unsupported slider curve type: " .. curve_type)
	end
	if #self.points == 0 then self:add(controls[1]) end
	self.distances[1] = 0
	local total = 0
	for i = 2, #self.points do
		local segment = distance(self.points[i - 1], self.points[i])
		if total + segment >= length then
			self.points[i] = lerp(self.points[i - 1], self.points[i], (length - total) / segment)
			for j = #self.points, i + 1, -1 do self.points[j] = nil end
			self.distances[i] = length
			total = length
			break
		end
		total = total + segment
		self.distances[i] = total
	end
	if total < length and #self.points >= 2 then
		local n = #self.points
		local a, b = self.points[n - 1], self.points[n]
		self.points[n] = lerp(a, b, (length - self.distances[n - 1]) / distance(a, b))
		self.distances[n] = length
		total = length
	end
	self.length = total
end

---@param progress number
---@return number x
---@return number y
function SliderPath:position(progress)
	local target = math.max(0, math.min(1, progress)) * self.length
	if #self.points == 1 or target == 0 then return self.points[1][1], self.points[1][2] end
	local low, high = 2, #self.points
	while low < high do
		local mid = math.floor((low + high) / 2)
		if self.distances[mid] < target then low = mid + 1 else high = mid end
	end
	local before = self.distances[low - 1]
	local p = lerp(self.points[low - 1], self.points[low], (target - before) / (self.distances[low] - before))
	return p[1], p[2]
end

return SliderPath
