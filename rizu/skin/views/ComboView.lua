local View = require("rizu.skin.View")

local lg = love.graphics

---@class rizu.skin.views.ComboView.Config
---@field x number? Horizontal offset from the center anchor.
---@field y number? Vertical offset from the center anchor.
---@field transform love.Transform? Local transform.
---@field visible boolean? Whether this view is drawn.
---@field color number[]? Text color.

---@class rizu.skin.views.ComboView : rizu.skin.View
---@operator call: rizu.skin.views.ComboView
---@overload fun(font: love.Font, config: rizu.skin.views.ComboView.Config?): rizu.skin.views.ComboView
---@field font love.Font
---@field text string
---@field color number[]
local ComboView = View + {}

---@param font love.Font
---@param config rizu.skin.views.ComboView.Config?
function ComboView:new(font, config)
	assert(font and type(font.getWidth) == "function" and type(font.getHeight) == "function",
		"combo view requires a Love font")
	config = config or {}
	assert(type(config) == "table", "combo view config must be a table")

	self.font = font
	self.text = ""
	self.color = config.color or {1, 1, 1, 1}
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
function ComboView:load(game)
	View.load(self, game)
	self:update(0, game)
end

---@param _dt number
---@param game sphere.GameController
function ComboView:update(_dt, game)
	local engine = game and game.rhythm_engine
	local score_engine = engine and engine.score_engine
	local combo_source = score_engine and score_engine.comboSource
	local combo = combo_source and combo_source.getCombo and combo_source:getCombo()
	self.text = combo == nil and "" or tostring(combo)
	self.width = self.font:getWidth(self.text)
end

function ComboView:draw()
	lg.setFont(self.font)
	lg.setColor(self.color[1], self.color[2], self.color[3], self.color[4] or 1)
	lg.print(self.text, 0, 0)
end

return ComboView
