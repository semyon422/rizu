local Colors = require("ui.Colors")
local Label = require("ui.views.Label")
local NineSlice = require("gui.NineSlice")
local Resources = require("ui.Resources")

---@class ui.views.ModalHeader : ui.views.NineSlice
---@operator call: ui.views.ModalHeader
---@field title ui.views.Label
---@field subtitle ui.views.Label
local ModalHeader = NineSlice + {}

local HEIGHT = 112
local PADDING_X = 48

---@param title string
---@param subtitle? string
function ModalHeader:new(title, subtitle)
	NineSlice.new(self, Resources.nine_slices.modal_header, Colors.text)
	self:anchorFixed(0, 0, 0, HEIGHT):fillWidth(0, 0)

	self.title = self:add(Label({
		font_name = "bold",
		font_size = 36,
		text = title,
	}))
	self.title:setPosition(PADDING_X, 24)

	self.subtitle = self:add(Label({
		font_name = "regular",
		font_size = 16,
		text = subtitle or "",
		color = Colors.muted,
	}))
	self.subtitle:setPosition(PADDING_X, 72)
end

return ModalHeader
