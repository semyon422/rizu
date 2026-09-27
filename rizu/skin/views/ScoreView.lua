local View = require("rizu.skin.View")

local lg = love.graphics

---@class rizu.skin.views.ScoreView.Config
---@field x number? Horizontal offset from the top-right anchor.
---@field y number? Vertical offset from the top-right anchor.
---@field transform love.Transform? Local transform.
---@field visible boolean? Whether this view is drawn.
---@field color number[]? Text color.

---@class rizu.skin.views.ScoreView : rizu.skin.View
---@operator call: rizu.skin.views.ScoreView
---@overload fun(font: love.Font, config: rizu.skin.views.ScoreView.Config?): rizu.skin.views.ScoreView
---@field font love.Font
---@field text string
---@field color number[]
local ScoreView = View + {}

---@param font love.Font
---@param config rizu.skin.views.ScoreView.Config?
function ScoreView:new(font, config)
	assert(font and type(font.getWidth) == "function" and type(font.getHeight) == "function",
		"score view requires a Love font")
	config = config or {}
	assert(type(config) == "table", "score view config must be a table")

	self.font = font
	self.text = ""
	self.color = config.color or {1, 1, 1, 1}
	View.new(self, {
		anchor = "top_right",
		origin = "top_right",
		x = config.x,
		y = config.y,
		width = font:getWidth(self.text),
		height = font:getHeight(),
		transform = config.transform,
		visible = config.visible,
	})
end

---@param game sphere.GameController
function ScoreView:load(game)
	View.load(self, game)
	self:update(0, game)
end

---@param _dt number
---@param game sphere.GameController
function ScoreView:update(_dt, game)
	local engine = game and game.rhythm_engine
	local score_engine = engine and engine.score_engine
	local score_source = score_engine and score_engine.scoreSource
	local text = score_source and score_source.getScoreString
		and score_source:getScoreString() or ""
	self.text = text
	self.width = self.font:getWidth(text)
end

function ScoreView:draw()
	lg.setFont(self.font)
	lg.setColor(self.color[1], self.color[2], self.color[3], self.color[4] or 1)
	lg.print(self.text, 0, 0)
end

return ScoreView
