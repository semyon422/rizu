local Colors = require("ui.Colors")
local ModalCloseButton = require("ui.views.ModalCloseButton")
local NineSlice = require("gui.NineSlice")
local Resources = require("ui.Resources")

---@class ui.views.ModalFooter : gui.NineSlice
---@operator call: ui.views.ModalFooter
---@field close_button ui.views.ModalCloseButton
local ModalFooter = NineSlice + {}

local HEIGHT = 92
local PADDING_X = 48
local PADDING_Y = 22

---@param on_close fun()
---@param close_text string?
function ModalFooter:new(on_close, close_text)
	NineSlice.new(self, Resources.nine_slices.modal_footer, Colors.text)
	self:anchorFixed(0, -HEIGHT, 0, HEIGHT):fillWidth(0, 0):setAlignmentY(1)
	self.close_button = self:add(ModalCloseButton(on_close, close_text))
	self.close_button:setPosition(PADDING_X, PADDING_Y)
end

return ModalFooter
