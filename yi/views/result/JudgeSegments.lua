local View = require("gui.View")
local SpringValue = require("gui.anim.SpringValue")
local JudgeSegmentsShader = require("yi.views.result.JudgeSegmentsShader")

---@class yi.views.result.JudgeSegments : gui.View
---@operator call: yi.views.result.JudgeSegments
---@field springs gui.anim.SpringValue[]
local JudgeSegments = View + {}

local shaders = {} ---@type {[integer]: love.Shader}
local shaders_created = false

local judge_colors = {
	{0, 0.7, 1, 1},
	{1, 1, 0, 1},
	{0, 1, 0.5, 1},
	{0.3, 0.5, 1, 1},
	{1, 0, 1, 1},
}

local miss_color = {1, 0, 0, 1}

function JudgeSegments:new()
	View.new(self)

	if not shaders_created then
		shaders[3] = JudgeSegmentsShader(3)
		shaders[4] = JudgeSegmentsShader(4)
		shaders[5] = JudgeSegmentsShader(5)
		shaders[6] = JudgeSegmentsShader(6)
		shaders_created = true
	end

	self.springs = {}
	for i = 1, 5 do
		self.springs[i] = SpringValue({value = (i - 1) * 0.2})
	end

	self:setSize(700, 700)
end

---@param judges_source rizu.IJudgesSource
function JudgeSegments:bind(judges_source)
	local judges = judges_source:getJudges()
	local total = judges_source:getJudgesTotal()
	if total == 0 then total = 1 end

	local judge_count = #judges
	self.judge_count = judge_count

	local current = 0
	for i = 1, judge_count - 1 do
		current = current + (judges[i] or 0) / total
		self.springs[i]:set(current)
	end

	self.shader = shaders[judge_count]

	if not self.shader then
		return
	end

	local gap = 0.004
	self.shader:send("u_innerRadius", 0.83)
	self.shader:send("u_outerRadius", 0.90)
	self.shader:send("u_gapWidth", gap)
	self.shader:send("u_bgOffset", -gap * 2)

	local colors = {}
	for i = 1, judge_count - 1 do
		table.insert(colors, judge_colors[i])
	end
	table.insert(colors, miss_color)

	self.shader:send("u_colors", unpack(colors))
end

function JudgeSegments:update(dt)
	for i = 1, 5 do
		self.springs[i]:update(dt)
	end

	if not self.shader or not self.judge_count then
		return
	end

	local thresholds = {}
	for i = 1, self.judge_count - 1 do
		table.insert(thresholds, self.springs[i]:get())
	end
	table.insert(thresholds, 1)

	self.shader:send("u_thresholds", unpack(thresholds))
end

function JudgeSegments:draw()
	love.graphics.setShader(self.shader)
	love.graphics.rectangle("fill", 0, 0, self.width, self.height)
end

return JudgeSegments
