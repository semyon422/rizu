local View = require("rizu.skin.View")

local lg = love.graphics

---@class rizu.skin.views.CurrentJudgeView.Config
---@field x number? Horizontal offset from the center anchor.
---@field y number? Vertical offset from the center anchor.
---@field transform love.Transform? Local transform.
---@field visible boolean? Whether this view is drawn.
---@field color number[]? Text color.
---@field duration number? Time in seconds to show a judgement before hiding it.

---@class rizu.skin.views.CurrentJudgeView : rizu.skin.View
---@operator call: rizu.skin.views.CurrentJudgeView
---@overload fun(font: love.Font, config: rizu.skin.views.CurrentJudgeView.Config?): rizu.skin.views.CurrentJudgeView
---@field font love.Font
---@field text string
---@field color number[]
---@field duration number
---@field elapsed number
---@field sequence_index integer
---@field score_engine rizu.ScoreEngine?
local CurrentJudgeView = View + {}

---@param font love.Font
---@param config rizu.skin.views.CurrentJudgeView.Config?
function CurrentJudgeView:new(font, config)
	assert(font and type(font.getWidth) == "function" and type(font.getHeight) == "function",
		"current judge view requires a Love font")
	config = config or {}
	assert(type(config) == "table", "current judge view config must be a table")
	local duration = config.duration or 0.8
	assert(type(duration) == "number" and duration >= 0 and duration < math.huge,
		"judgement duration must be a non-negative finite number")

	self.font = font
	self.text = ""
	self.color = config.color or {1, 1, 1, 1}
	self.duration = duration
	self.elapsed = duration
	self.sequence_index = 0
	self.score_engine = nil
	View.new(self, {
		anchor = "center",
		origin = "center",
		x = config.x,
		y = config.y,
		width = font:getWidth(self.text),
		height = font:getHeight(),
		transform = config.transform,
		visible = config.visible,
	})
end

---@param game sphere.GameController
function CurrentJudgeView:load(game)
	View.load(self, game)
	self.text = ""
	self.elapsed = self.duration
	self.sequence_index = 0
	self.score_engine = nil
	self.width = self.font:getWidth(self.text)
end

---@param dt number
---@param game sphere.GameController
function CurrentJudgeView:update(dt, game)
	local engine = game and game.rhythm_engine
	local score_engine = engine and engine.score_engine
	local sequence = score_engine and score_engine.sequence
	local judges_source = score_engine and score_engine.judgesSource
	---@type {[string]: rizu.JudgesSlice}[]?
	local judge_sequence = sequence
	if not judge_sequence or not judges_source then
		self.text = ""
		self.width = self.font:getWidth(self.text)
		self.elapsed = self.duration
		self.score_engine = score_engine
		self.sequence_index = 0
		return
	end

	if self.score_engine ~= score_engine then
		self.score_engine = score_engine
		self.sequence_index = 0
		self.text = ""
		self.elapsed = self.duration
	end

	self.elapsed = math.min(self.duration, self.elapsed + dt)
	local latest_index = #judge_sequence
	if latest_index > self.sequence_index then
		for index = self.sequence_index + 1, latest_index do
			local slice = judge_sequence[index]
			local judge_slice = slice and slice[judges_source:getKey()]
			local judge = judge_slice and (judge_slice.visual_judge or judge_slice.judge_index)
			if judge then
				local names = judges_source.getJudgeNames and judges_source:getJudgeNames()
				if judge < 0 and names then
					judge = #names + judge + 1
				end
				local name = names and names[judge]
				self.text = name and name:gsub("_", " "):upper() or ""
				self.width = self.font:getWidth(self.text)
				self.elapsed = 0
			end
		end
		self.sequence_index = latest_index
	end
end

function CurrentJudgeView:draw()
	if self.elapsed >= self.duration or self.text == "" then return end
	local alpha = self.color[4] or 1
	if self.duration > 0 then
		alpha = alpha * (1 - self.elapsed / self.duration)
	end
	lg.setFont(self.font)
	lg.setColor(self.color[1], self.color[2], self.color[3], alpha)
	lg.printf(self.text, 0, 0, self.width, "center")
end

return CurrentJudgeView
