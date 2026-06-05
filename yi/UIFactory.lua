local class = require("class")

local Rectangle = require("yi.components.Rectangle")
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

---@generic T: gui.View
---@param view T
---@param params table
---@return T
local function apply_view_params(view, params)
	---@cast view gui.View
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
	if params.pivot then
		view.pivot = params.pivot
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
		fit_box = (params.fit_box == nil) and true or params.fit_box,
		blend_mode = params.blend_mode or "alpha"
	}), params)
end

---@param params table?
---@return yi.Image
function UIFactory:Image(params)
	params = params or {}
	local quad = assert(self.quads[params.image], "No such image")
	return apply_view_params(Image({
		atlas = self.atlas,
		quad = quad,
		color = params.color or {1, 1, 1, 1},
		fit_box = params.fit_box or false,
		size_scale = params.size_scale or 1
	}), params)
end

---@param params table?
---@return yi.Label
function UIFactory:Label(params)
	params = params or {}
	assert(params.font, "Font is required")
	assert(params.font_size, "Font size is required")
	params.text = params.text or ""
	return apply_view_params(Label({
		resources = self.resources,
		font_name = params.font,
		font_size = params.font_size,
		text = params.text,
		color = params.color or self.colors.white
	}), params)
end

return UIFactory
