local View = require("gui.View")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")

---@class ui.screens.song_select.GameplayModifiers : gui.View
---@operator call: ui.screens.song_select.GameplayModifiers
---@field batch love.Text
local GameplayModifiers = View + {}

function GameplayModifiers:new()
	View.new(self)
	self.batch = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self:setSize(0, self.batch:getFont():getHeight())
end

---@param rbf ui.factories.ReplayBaseFactory
function GameplayModifiers:bind(rbf)
	local ss = rbf:getScoreSystem()
	local co = rbf:getColumnOrderType()
	local cs = {Colors.grade_x, ss}

	if rbf:isConst() then
		table.insert(cs, Colors.text_muted)
		table.insert(cs, " CONST")
	end

	if co ~= "" then
		table.insert(cs, Colors.text_muted)
		table.insert(cs, " " .. co)
	end

	if rbf:isTapOnly() then
		table.insert(cs, Colors.text_muted)
		table.insert(cs " " .. "No LN")
	end

	self.batch:set(cs)
end

function GameplayModifiers:draw()
	love.graphics.draw(self.batch, -self.batch:getWidth())
end

return GameplayModifiers
