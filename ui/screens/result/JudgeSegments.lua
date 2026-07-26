local View = require("gui.View")
local SpringValue = require("gui.anim.SpringValue")
local JudgeSegmentsShader = require("ui.screens.result.JudgeSegmentsShader")

---@class ui.screens.result.JudgeSegments : gui.View
---@operator call: ui.screens.result.JudgeSegments
---@field springs gui.anim.SpringValue[]
---@field shaders {[integer]: love.Shader}
---@field shader love.Shader?
---@field judge_count integer?
local JudgeSegments = View + {}

local judge_colors = {
	{0, 0.7, 1, 1},
	{1, 1, 0, 1},
	{0, 1, 0.5, 1},
	{0.3, 0.5, 1, 1},
	{1, 0, 1, 1},
}

local miss_color = {1, 0, 0, 1}
local minimum_visible_share = 0.01

---@param judges integer[]
---@param total integer
---@return number[] shares
local function calculateShares(judges, total)
	---@type number[]
	local shares = {}
	---@type integer[]
	local remaining_indices = {}
	local remaining_total = total
	local remaining_share = 1

	for i, count in ipairs(judges) do
		shares[i] = 0
		if count > 0 then
			remaining_indices[#remaining_indices + 1] = i
		end
	end

	while #remaining_indices > 0 do
		local constrained_index
		for _, index in ipairs(remaining_indices) do
			if judges[index] / remaining_total * remaining_share < minimum_visible_share then
				constrained_index = index
				break
			end
		end

		if not constrained_index then
			for _, index in ipairs(remaining_indices) do
				shares[index] = judges[index] / remaining_total * remaining_share
			end
			break
		end

		shares[constrained_index] = minimum_visible_share
		remaining_total = remaining_total - judges[constrained_index]
		remaining_share = remaining_share - minimum_visible_share
		for i, index in ipairs(remaining_indices) do
			if index == constrained_index then
				table.remove(remaining_indices, i)
				break
			end
		end
	end

	return shares
end

function JudgeSegments:new()
	View.new(self)
	---@type gui.anim.SpringValue[]
	self.springs = {}
	for i = 1, 5 do
		self.springs[i] = SpringValue({value = (i - 1) * 0.2})
	end
	---@type {[integer]: love.Shader}
	self.shaders = {}
	self:setSize(490, 490)
end

function JudgeSegments:load()
	for count = 3, 6 do
		self.shaders[count] = JudgeSegmentsShader(count)
	end
end

function JudgeSegments:unload()
	for _, shader in pairs(self.shaders) do
		shader:release()
	end
	self.shaders = {}
	self.shader = nil
end

---@param judges_source rizu.IJudgesSource
function JudgeSegments:bind(judges_source)
	local judges = judges_source:getJudges()
	local total = judges_source:getJudgesTotal()
	if total == 0 then
		total = 1
	end

	local judge_count = #judges
	self.judge_count = judge_count

	local shares = calculateShares(judges, total)
	local current = 0
	for i = 1, judge_count - 1 do
		current = current + shares[i]
		self.springs[i]:set(current)
	end

	self.shader = self.shaders[judge_count]
	if not self.shader then
		return
	end

	local gap = 0.004
	self.shader:send("u_innerRadius", 0.92)
	self.shader:send("u_outerRadius", 1.0)
	self.shader:send("u_gapWidth", gap)

	local colors = {}
	for i = 1, judge_count - 1 do
		colors[#colors + 1] = judge_colors[i]
	end
	colors[#colors + 1] = miss_color
	self.shader:send("u_colors", unpack(colors))
end

---@param dt number
function JudgeSegments:update(dt)
	for i = 1, 5 do
		self.springs[i]:update(dt)
	end

	if not self.shader or not self.judge_count then
		return
	end

	local thresholds = {}
	for i = 1, self.judge_count - 1 do
		thresholds[#thresholds + 1] = self.springs[i]:get()
	end
	thresholds[#thresholds + 1] = 1
	self.shader:send("u_thresholds", unpack(thresholds))
end

function JudgeSegments:draw()
	if not self.shader then
		return
	end
	love.graphics.setShader(self.shader)
	love.graphics.rectangle("fill", 0, 0, self.width, self.height)
	love.graphics.setShader()
end

return JudgeSegments
