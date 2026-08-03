local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local FormControl = require("ui.views.form.FormControl")

---@class ui.modals.config.GameplayViewportPreview : ui.views.form.FormControl
---@operator call: ui.modals.config.GameplayViewportPreview
---@field ui_config ui.UiConfig
---@field label_font love.Font
---@field resolution_font love.Font
local GameplayViewportPreview = FormControl + {}

local WIDTH = 635
local HEIGHT = 300
local PREVIEW_WIDTH = 430
local PREVIEW_PADDING = 12
local DETAILS_X = 458

---@param ui_config ui.UiConfig
function GameplayViewportPreview:new(ui_config)
	FormControl.new(self)
	self.ui_config = ui_config
	self.label_font = Resources.getFont("medium", 16)
	self.resolution_font = Resources.getFont("bold", 24)
	self:setSize(WIDTH, HEIGHT)
end

---@return boolean selectable
function GameplayViewportPreview:canBeSelected()
	return false
end

function GameplayViewportPreview:draw()
	local lg = love.graphics
	local screen_width, screen_height = lg.getDimensions()
	local keys = self.ui_config.keys
	local scale_x = self.ui_config:getNumber(keys.gameplay_viewport_sx)
	local scale_y = self.ui_config:getNumber(keys.gameplay_viewport_sy)
	local align_x = self.ui_config:getNumber(keys.gameplay_viewport_x)
	local align_y = self.ui_config:getNumber(keys.gameplay_viewport_y)

	local available_width = PREVIEW_WIDTH - PREVIEW_PADDING * 2
	local available_height = HEIGHT - PREVIEW_PADDING * 2
	local preview_scale = math.min(available_width / screen_width, available_height / screen_height)
	local outer_width = screen_width * preview_scale
	local outer_height = screen_height * preview_scale
	local outer_x = PREVIEW_PADDING + (available_width - outer_width) / 2
	local outer_y = PREVIEW_PADDING + (available_height - outer_height) / 2
	local viewport_width = outer_width * scale_x
	local viewport_height = outer_height * scale_y
	local viewport_x = outer_x + align_x * (outer_width - viewport_width)
	local viewport_y = outer_y + align_y * (outer_height - viewport_height)

	Painter.setColorTable(Colors.elements)
	lg.rectangle("fill", outer_x, outer_y, outer_width, outer_height)
	Painter.setColorTable(Colors.outline)
	Painter.rectangleLineFixed(outer_x, outer_y, outer_width, outer_height, 2)

	Painter.setColorTable(Colors.accent)
	Painter.setOpacity(0.28)
	lg.rectangle("fill", viewport_x, viewport_y, viewport_width, viewport_height)
	Painter.setOpacity(1)
	Painter.rectangleLineFixed(viewport_x, viewport_y, viewport_width, viewport_height, 2)

	Painter.setColorTable(Colors.text_muted)
	lg.setFont(self.label_font)
	lg.printf("Final resolution", DETAILS_X, 96, WIDTH - DETAILS_X, "left")

	local final_width = math.floor(screen_width * scale_x + 0.5)
	local final_height = math.floor(screen_height * scale_y + 0.5)
	Painter.setColorTable(Colors.text)
	lg.setFont(self.resolution_font)
	lg.printf(("%d × %d"):format(final_width, final_height), DETAILS_X, 126, WIDTH - DETAILS_X, "left")
end

return GameplayViewportPreview
