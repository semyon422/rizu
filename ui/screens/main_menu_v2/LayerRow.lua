local ButtonsRow = require("ui.modals.config.rows.ButtonsRow")
local ChartCarousel = require("ui.screens.song_select_v2.ChartCarousel")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SettingRow = require("ui.modals.config.rows.SettingRow")

---A background layer: its picture, name and file, with the buttons on the right.
---@class ui.screens.main_menu_v2.LayerRow : ui.modals.config.rows.ButtonsRow
---@operator call: ui.screens.main_menu_v2.LayerRow
---@field name string
---@field file_name string
---@field image love.Image?
local LayerRow = ButtonsRow + {}

local HEIGHT = 80
local THUMB_WIDTH, THUMB_HEIGHT = 96, 54
local TEXT_GAP = 14

---@param name string
---@param file_name string
---@param image love.Image?
---@param buttons ui.views.form.ButtonRow.Button[]
function LayerRow:new(name, file_name, image, buttons)
	ButtonsRow.new(self, {buttons = buttons})
	self.name = name
	self.file_name = file_name
	self.image = image
	self:setHeight(HEIGHT)
end

---@return number x
function LayerRow:getButtonsX()
	local width = -ButtonsRow.GAP
	for _, button_width in ipairs(self.button_widths) do
		width = width + button_width + ButtonsRow.GAP
	end
	return self.width - SettingRow.PADDING_X - width
end

function LayerRow:draw()
	ButtonsRow.draw(self)
	local x = SettingRow.PADDING_X
	local y = math.floor((self.height - THUMB_HEIGHT) / 2)
	Painter.setColorTable(Colors.background)
	Resources.sprites.pixel:draw(x, y, 0, THUMB_WIDTH, THUMB_HEIGHT)
	local image = self.image
	if image then
		local width, height = image:getDimensions()
		local scale = math.max(THUMB_WIDTH / width, THUMB_HEIGHT / height)
		local px, py, pw, ph = Painter.addScissor(x, y, THUMB_WIDTH, THUMB_HEIGHT)
		Painter.setColorRgb(1, 1, 1)
		love.graphics.draw(image, x + THUMB_WIDTH / 2, y + THUMB_HEIGHT / 2, 0, scale, scale, width / 2, height / 2)
		Painter.restoreScissor(px, py, pw, ph)
	end

	local text_x = x + THUMB_WIDTH + TEXT_GAP
	local text_width = self:getButtonsX() - TEXT_GAP - text_x
	local name_font = Resources.getFont("bold", 16)
	local file_font = Resources.getFont("medium", 13)
	local top = math.floor((self.height - name_font:getHeight() - file_font:getHeight() - 2) / 2)
	love.graphics.setFont(name_font)
	Painter.setColorTable(Colors.text)
	love.graphics.print(ChartCarousel.fitText(name_font, self.name, text_width), text_x, top)
	love.graphics.setFont(file_font)
	Painter.setColorTable(Colors.muted)
	love.graphics.print(ChartCarousel.fitText(file_font, self.file_name, text_width), text_x, top + name_font:getHeight() + 2)
end

return LayerRow
