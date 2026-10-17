local View = require("rizu.skin.View")

local lg = love.graphics

---@class rizu.skin.views.AccuracyView.Config
---@field x number? Horizontal offset from the top-right anchor.
---@field y number? Vertical offset from the top-right anchor.
---@field anchor rizu.skin.ViewAnchor? Anchor point in the parent viewport.
---@field origin rizu.skin.ViewAnchor? Point on this view aligned to its anchor.
---@field transform love.Transform? Local transform.
---@field visible boolean? Whether this view is drawn.

---@class rizu.skin.views.AccuracyView : rizu.skin.View
---@operator call: rizu.skin.views.AccuracyView
---@overload fun(font: love.Font, config: rizu.skin.views.AccuracyView.Config?): rizu.skin.views.AccuracyView
---@field font love.Font
---@field text string
local AccuracyView = View + {}

---@param font love.Font
---@param config rizu.skin.views.AccuracyView.Config?
function AccuracyView:new(font, config)
	assert(font and type(font.getWidth) == "function" and type(font.getHeight) == "function",
		"accuracy view requires a Love font")
	config = config or {}
	assert(type(config) == "table", "accuracy view config must be a table")

	self.font = font
	self.text = ""
	View.new(self, {
		anchor = config.anchor or "top_right",
		origin = config.origin or "top_right",
		x = config.x,
		y = config.y,
		width = font:getWidth(self.text),
		height = font:getHeight(),
		transform = config.transform,
		visible = config.visible,
	})
end

---@param game sphere.GameController
function AccuracyView:load(game)
	View.load(self, game)
	self:update(0, game)
end

---@param _dt number
---@param game sphere.GameController
function AccuracyView:update(_dt, game)
	local engine = game and game.rhythm_engine
	local score_engine = engine and engine.score_engine
	local accuracy_source = score_engine and score_engine.accuracySource
	local text = accuracy_source and accuracy_source.getAccuracyString
		and accuracy_source:getAccuracyString() or ""
	self.text = text
	self.width = self.font:getWidth(text)
end

function AccuracyView:draw()
	lg.setFont(self.font)
	lg.setColor(1, 1, 1, 1)
	lg.print(self.text, 0, 0)
end

return AccuracyView
