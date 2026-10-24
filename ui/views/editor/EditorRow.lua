local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---A row of an editor panel: a muted label on the left and a flat field on the right.
---Without a label the field takes the whole row. Everything is drawn as filled rectangles.
---@class ui.views.editor.EditorRow : gui.View
---@operator call: ui.views.editor.EditorRow
---@field label_text string?
---@field font love.Font
local EditorRow = View + {}

EditorRow.HEIGHT = 30
EditorRow.TEXT_X = 8 -- text inset inside a field
local LABEL_SHARE = 0.4
local GAP = 8

---@param label string?
---@param width number
function EditorRow:new(label, width)
	View.new(self)
	self.label_text = label
	self.font = Resources.getFont("regular", 16)
	self.handles_mouse_input = true
	self:setSize(width, EditorRow.HEIGHT)
end

---@return number x
---@return number width
function EditorRow:getField()
	if not self.label_text then return 0, self.width end
	local x = math.floor(self.width * LABEL_SHARE) + GAP
	return x, self.width - x
end

---@param color gui.Color
---@param x number
---@param y number
---@param width number
---@param height number
function EditorRow.fillRect(color, x, y, width, height)
	Painter.setColorTable(color)
	Resources.sprites.pixel:draw(x, y, 0, width, height)
end

---@param text string
---@param x number
---@param width number
---@param align "left"|"center"
function EditorRow:printText(text, x, width, align)
	love.graphics.setFont(self.font)
	local y = math.floor((self.height - self.font:getHeight()) / 2)
	local px, py, pw, ph = Painter.addScissor(x, 0, width, self.height)
	if align == "center" then
		love.graphics.printf(text, x, y, width, "center")
	else
		love.graphics.print(text, x, y)
	end
	Painter.restoreScissor(px, py, pw, ph)
end

function EditorRow:drawLabel()
	if not self.label_text then return end
	Painter.setColorTable(Colors.muted)
	self:printText(self.label_text, 0, self:getField() - GAP, "left")
end

return EditorRow
