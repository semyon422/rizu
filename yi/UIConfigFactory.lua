local class = require("class")

local SectionLabel = require("yi.components.config.SectionLabel")
local GroupLabel = require("yi.components.config.GroupLabel")
local Checkbox = require("yi.components.config.Checkbox")
local Slider = require("yi.components.config.Slider")
local PanelSelect = require("yi.components.config.PanelSelect")
local Rectangle = require("yi.components.Rectangle")

---@class yi.UIConfigFactory
---@overload fun(resources: yi.Resources): yi.UIConfigFactory
local UIConfigFactory = class()

---@param resources yi.Resources
function UIConfigFactory:new(resources)
	self.resources = assert(resources)
	self.colors = require("yi.Colors")
end

---@generic T: ui.View
---@param view T
---@param params table
---@return T
local function apply_view_params(view, params)
	---@cast view ui.View
	if params.x then
		view.x = params.x
	end
	if params.y then
		view.y = params.y
	end
	if params.width then
		view.width = params.width
	end
	if params.height then
		view.height = params.height
	end
	if params.anchor then
		view.anchor = params.anchor
	end
	if params.origin then
		view.origin = params.origin
	end
	if params.visible ~= nil then
		view.visible = params.visible
	end
	if params.rotation then
		view.rotation = params.rotation
	end
	if params.scale_x then
		view.scale_x = params.scale_x
	end
	if params.scale_y then
		view.scale_y = params.scale_y
	end
	if params.box then
		view.box = params.box
	end
	if params.handles_mouse_input ~= nil then
		view.handles_mouse_input = params.handles_mouse_input
	end
	if params.handles_keyboard_input ~= nil then
		view.handles_keyboard_input = params.handles_keyboard_input
	end
	if params.width_percent ~= nil then
		view.width_percent = params.width_percent
	end
	if params.height_percent ~= nil then
		view.height_percent = params.height_percent
	end
	if params.is_focusable ~= nil then
		view.is_focusable = params.is_focusable
	end
	return view
end

---@param params table?
---@return yi.config.SectionLabel
function UIConfigFactory:SectionLabel(params)
	params = params or {}
	return apply_view_params(SectionLabel({
		font = self.resources:getFont("bold", 36),
		text = params.text,
		color = self.colors.text_section,
		accent_color = self.colors.cyan_400,
		accent_width = params.accent_width or 16,
		accent_height = params.accent_height or 16,
		gap = params.gap or 18,
	}), params)
end

---@param params table?
---@return yi.config.GroupLabel
function UIConfigFactory:GroupLabel(params)
	params = params or {}
	return apply_view_params(GroupLabel({
		font = self.resources:getFont("medium", 22),
		text = params.text,
		color = self.colors.text_subsection,
		marker_text = params.marker_text or "//",
		marker_color = self.colors.text_muted,
		marker_alpha_scale = params.marker_alpha_scale or 0.8,
		gap = params.gap or 2,
	}), params)
end

---@param params table?
---@return yi.config.Checkbox
function UIConfigFactory:Checkbox(params)
	params = params or {}
	return apply_view_params(Checkbox({
		atlas = params.atlas or self.resources.atlas,
		pixel = params.pixel or self.resources.quads.pixel,
		font = self.resources:getFont("medium", 24),
		text = params.text or "",
		color = self.colors.text_label,
		box_color = self.colors.white_70,
		check_color = self.colors.cyan_400,
		text_idle_alpha_scale = params.text_idle_alpha_scale or 0.78,
		text_active_alpha_scale = params.text_active_alpha_scale or 1,
		checkbox_size = params.checkbox_size or 28,
		line_width = params.line_width or 2,
		gap = params.gap or 16,
		animation_duration = params.animation_duration or 0.08,
		pulse_decay = params.pulse_decay or 10,
		checked = params.checked or false,
		on_change = params.on_change,
	}), params)
end

	---@param params table?
---@return yi.Rectangle
function UIConfigFactory:Separator(params)
	params = params or {}
	params.width_percent = params.width_percent or 1
	params.height = params.height or 2
	return apply_view_params(Rectangle({
		atlas = params.atlas or self.resources.atlas,
		quad = params.quad or self.resources.quads.pixel,
		color = self.colors.white_10,
	}), params)
end

---@param params table?
---@return yi.config.Slider
function UIConfigFactory:Slider(params)
	params = params or {}
	local min = params.min or 0
	local max = params.max or 1
	local value_format = params.value_format or "%.2f"
	local format_value = params.format_value or function(value)
		return value_format:format(value)
	end
	params.width = params.width or 640
	return apply_view_params(Slider({
		atlas = params.atlas or self.resources.atlas,
		pixel = params.pixel or self.resources.quads.pixel,
		label_font = self.resources:getFont("medium", 24),
		value_font = self.resources:getFont("bold", 24),
		text = params.text or "",
		color = self.colors.text_label,
		value_color = self.colors.text_section,
		accent_color = self.colors.cyan_400,
		track_color = self.colors.white_40,
		handle_color = params.handle_color or self.colors.white,
		label_idle_alpha_scale = params.label_idle_alpha_scale or 0.78,
		label_active_alpha_scale = params.label_active_alpha_scale or 1,
		value_idle_alpha_scale = params.value_idle_alpha_scale or 0.9,
		value_active_alpha_scale = params.value_active_alpha_scale or 1,
		value = params.value or min,
		min = min,
		max = max,
		step = params.step or 0,
		width = params.width,
		track_height = params.track_height or 4,
		handle_width = params.handle_width or 8,
		label_gap = params.label_gap or 18,
		animation_duration = params.animation_duration or 0.08,
		value_format = value_format,
		format_value = format_value,
		on_change = params.on_change,
	}), params)
end

---@param params table?
---@return yi.config.PanelSelect
function UIConfigFactory:PanelSelect(params)
	params = params or {}
	local items = assert(params.items, "PanelSelect items are required")
	local padding_y = params.padding_y or 16
	local panel_height = params.panel_height or 72
	local font = self.resources:getFont("medium", 24)
	local item_font = self.resources:getFont("regular", 24)
	local format_item = params.format_item or function(item)
		if type(item) == "table" then
			return item.text or ""
		end
		return tostring(item or "")
	end
	params.width_percent = params.width_percent or 1
	params.height = params.height or (font:getHeight() + padding_y + panel_height)
	return apply_view_params(PanelSelect({
		text = params.text or "",
		atlas = params.atlas or self.resources.atlas,
		pixel = params.pixel or self.resources.quads.pixel,
		font = font,
		item_font = item_font,
			items = items,
			format_item = format_item,
			color = self.colors.text_muted,
			label_color = self.colors.text_label,
			selected_color = self.colors.text_label,
			frame_color = self.colors.cyan_400,
		frame_idle_alpha = params.frame_idle_alpha or 0.5,
		frame_active_alpha = params.frame_active_alpha or 0.85,
			label_idle_alpha_scale = params.label_idle_alpha_scale or 0.78,
		label_active_alpha_scale = params.label_active_alpha_scale or 1,
		padding_x = params.padding_x or 16,
		padding_y = padding_y,
		gap = params.gap or 16,
		panel_height = panel_height,
		frame_width = params.frame_width or 2,
		selected_index = params.selected_index or 1,
		scroll_animation_speed = params.scroll_animation_speed or 16,
		frame_animation_speed = params.frame_animation_speed or 20,
		width = params.width or 480,
		height = params.height,
		on_change = params.on_change,
	}), params)
end

return UIConfigFactory
