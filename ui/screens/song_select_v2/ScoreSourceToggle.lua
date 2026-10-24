local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local ToolbarBackground = require("ui.screens.song_select_v2.ToolbarBackground")

---Switches the leaderboard between local and online scores, styled like the toolbar controls.
---@class ui.screens.song_select_v2.ScoreSourceToggle : gui.View
---@operator call: ui.screens.song_select_v2.ScoreSourceToggle
---@field labels string[]
---@field cell_widths number[]
local ScoreSourceToggle = View + {}

local SOURCES = {"local", "online"}
local PADDING = 16

---@param scores rizu.api.Scores
---@param localization ui.localization.Localization
function ScoreSourceToggle:new(scores, localization)
	View.new(self)
	self.scores = scores
	self.font = Resources.getFont("bold", 14)
	self.background = ToolbarBackground()
	self.labels = {}
	self.cell_widths = {}
	local width = 0
	for i, source in ipairs(SOURCES) do
		self.labels[i] = localization:get("song_select.score_source_" .. source)
		self.cell_widths[i] = self.font:getWidth(self.labels[i]) + PADDING * 2
		width = width + self.cell_widths[i]
	end
	self:setWidth(width)
	self.handles_mouse_input = true
end

---@param e gui.HoverEvent
function ScoreSourceToggle:onHover(e)
	if self.effective_enabled then
		Sounds.play("hover")
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function ScoreSourceToggle:onMouseClick(e)
	if e.button ~= 1 or not self.effective_enabled then
		return
	end
	local x = self.world_transform:inverseTransformPoint(e.x, e.y)
	local source = x < self.cell_widths[1] and SOURCES[1] or SOURCES[2]
	if source ~= self.scores:getSource() then
		self.scores:setSource(source)
		Sounds.play("click")
	end
	return true
end

function ScoreSourceToggle:draw()
	Painter.snapToPixel()
	local ui_scale = assert(self.screen).ui_scale
	self.background:draw(self.width, self.height, ui_scale, self.mouse_over)

	local selected = self.scores:getSource()
	local text_y = math.floor((self.height - self.font:getHeight()) / 2)
	love.graphics.setFont(self.font)
	local x = 0
	for i, source in ipairs(SOURCES) do
		local width = self.cell_widths[i]
		if source == selected then
			love.graphics.push()
			love.graphics.translate(x, 0)
			self.background:draw(width, self.height, ui_scale, true)
			love.graphics.pop()
		end
		Painter.setColorTable(source == selected and Colors.accent or self.mouse_over and Colors.text or Colors.muted)
		love.graphics.printf(self.labels[i], x, text_y, width, "center")
		x = x + width
	end
end

return ScoreSourceToggle
