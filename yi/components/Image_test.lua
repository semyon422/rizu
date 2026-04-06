local Box = require("ui.Box")
local Image = require("yi.components.Image")

local test = {}

local function make_quad(width, height)
	return {
		getViewport = function()
			return 0, 0, width, height
		end
	}
end

---@param width number
---@param height number
---@param mode yi.ImageMode?
local function make_image(width, height, mode)
	return Image({
		atlas = {},
		quad = make_quad(width, height),
		mode = mode,
	})
end

---@param view yi.Image
---@param box ui.Box
local function attach(view, box)
	view.box = box
	view:refresh()
end

---@param t testing.T
function test.none_mode_keeps_original_size(t)
	local box = Box()
	box:update(0, 0, 200, 300)

	local image = make_image(100, 50)
	attach(image, box)

	t:eq(image.width, 100)
	t:eq(image.height, 50)
	t:eq(image.layout_scale_x, 1)
	t:eq(image.layout_scale_y, 1)

	local x, y = image.transform:transformPoint(image.width, image.height)
	t:eq(x, 100)
	t:eq(y, 50)
end

---@param t testing.T
function test.stretch_mode_fills_box(t)
	local box = Box()
	box:update(0, 0, 200, 300)

	local image = make_image(100, 50, "stretch")
	attach(image, box)

	t:eq(image.layout_scale_x, 2)
	t:eq(image.layout_scale_y, 6)

	local x, y = image.transform:transformPoint(image.width, image.height)
	t:eq(x, 200)
	t:eq(y, 300)
end

---@param t testing.T
function test.fit_mode_preserves_aspect_ratio_inside_box(t)
	local box = Box()
	box:update(0, 0, 200, 300)

	local image = make_image(100, 50, "fit")
	attach(image, box)

	t:eq(image.layout_scale_x, 2)
	t:eq(image.layout_scale_y, 2)

	local x, y = image.transform:transformPoint(image.width, image.height)
	t:eq(x, 200)
	t:eq(y, 100)
end

---@param t testing.T
function test.fit_mode_respects_pivot(t)
	local box = Box()
	box:update(0, 0, 200, 300)

	local image = make_image(100, 50, "fit")
	image.pivot = {0.5, 0.5}
	attach(image, box)

	local x1, y1 = image.transform:transformPoint(0, 0)
	local x2, y2 = image.transform:transformPoint(image.width, image.height)

	t:eq(x1, 0)
	t:eq(y1, 100)
	t:eq(x2, 200)
	t:eq(y2, 200)
end

return test
