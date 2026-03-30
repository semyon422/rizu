local class = require("class")

local Button = require("yi.components.Button")
local TabButton = require("yi.components.TabButton")
local Rectangle = require("yi.components.Rectangle")
local Panel = require("yi.components.Panel")
local List = require("yi.components.List")
local Image = require("yi.components.Image")
local Label = require("yi.components.Label")

---@class yi.UIFactory
---@overload fun(resources: yi.Resources): yi.UIFactory
local UIFactory = class()

---@param resources yi.Resources
function UIFactory:new(resources)
	self.resources = assert(resources)
	self.colors = require("yi.Colors")
	self.atlas = assert(resources.atlas)
	self.quads = assert(resources.quads)
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
---@return yi.Rectangle
function UIFactory:Rectangle(params)
	params = params or {}
	return apply_view_params(Rectangle({
		atlas = params.atlas or self.atlas,
		quad = params.quad or self.quads.pixel,
		color = params.color or {1, 1, 1, 1},
	}), params)
end

---@param params table?
---@return ui.Panel
function UIFactory:Panel(params)
	params = params or {}
	return apply_view_params(Panel({
		atlas = params.atlas or self.atlas,
		rect_corner = params.rect_corner or self.quads.rect_corner,
		rect_corner_border = params.rect_corner_border or self.quads.rect_corner_border,
		pixel = params.pixel or self.quads.pixel,
		corners = params.corners,
		color = params.color or self.colors.slate_900_70,
		border_color = params.border_color or self.colors.white_90,
	}), params)
end

---@param params table?
---@return yi.Button
function UIFactory:Button(params)
	params = params or {}
	params.width = params.width or 240
	params.height = params.height or 45

	return apply_view_params(Button({
		atlas = params.atlas or self.atlas,
		button_quad = self.quads.button_rounded,
		pixel = params.pixel or self.quads.pixel,
		font = params.font or self.resources:getFont("oribtron_bold", 24),
		button_color = params.button_color or self.colors.cyan_400_10,
		text_color = params.text_color or self.colors.cyan_400,
		text = params.text or "",
		on_click = params.on_click,
	}), params)
end

---@param params table?
---@return yi.TabButton
function UIFactory:TabButton(params)
	params = params or {}

	return apply_view_params(TabButton({
		atlas = params.atlas or self.atlas,
		pixel = params.pixel or self.quads.pixel,
		tab = params.tab or self.quads.tab,
		tab_outline = params.tab_outline or self.quads.tab_outline,
		font = params.font or self.resources:getFont("bold", 32),
		text = params.text or "",
		text_color = params.text_color or self.colors.white,
		active_text_color = params.active_text_color or self.colors.white,
		inactive_text_color = params.inactive_text_color or self.colors.white_70,
		active_image_color = params.active_image_color or self.colors.black_80,
		inactive_image_color = params.inactive_image_color or self.colors.slate_800_80,
		line_width = params.line_width,
		text_padding_x = params.text_padding_x,
		active = params.active,
		on_click = params.on_click,
	}), params)
end

---@param params table?
---@return yi.List
function UIFactory:List(params)
	params = params or {}
	return apply_view_params(List(params), params)
end

---@param params table?
---@return yi.Image
function UIFactory:Image(params)
	params = params or {}
	local quad = assert(self.quads[params.image], "No such image")
	return apply_view_params(Image({
		atlas = self.atlas,
		quad = quad,
		color = params.color or {1, 1, 1, 1}
	}), params)
end

---@param params table?
---@return yi.Label
function UIFactory:Label(params)
	params = params or {}
	assert(params.font, "Font is required")
	assert(params.font_size, "Font size is required")
	return apply_view_params(Label({
		font = self.resources:getFont(params.font, params.font_size),
		text = params.text,
		color = params.color or self.colors.white
	}), params)
end

return UIFactory
