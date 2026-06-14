local Align = require("gui.composition.Align")
local Box = require("gui.Box")

local test = {}

---@param width number
---@param height number
---@return gui.View
local function view(width, height)
	local b = Box()
	b.width = width
	b.height = height
	return {
		_is_view = true,
		width = width,
		height = height,
		box = b,
	}
end

---@param t testing.T
function test.row_fills_height_and_aligns_x(t)
	local v = view(100, 50)
	local align = Align({
		direction = "row",
		align = 1.0, -- Align to right/end
		v,
	})

	align:measure()
	t:eq(align.width, 100)
	t:eq(align.height, 50)

	align:grow(500, 300)
	t:eq(align.width, 500)
	t:eq(align.height, 300)
	t:eq(v.width, 100) -- width is intact
	t:eq(v.height, 300) -- height is stretched to match fill_y (direction row)
	t:eq(v.box.width, 100)
	t:eq(v.box.height, 300)

	align:arrange()
	t:eq(v.box.x, 400) -- (500 - 100) * 1.0 = 400
	t:eq(v.box.y, 0)
end

---@param t testing.T
function test.column_fills_width_and_aligns_y(t)
	local v = view(100, 50)
	local align = Align({
		direction = "column",
		align = 0.5, -- Align to center
		v,
	})

	align:measure()
	t:eq(align.width, 100)
	t:eq(align.height, 50)

	align:grow(500, 300)
	t:eq(align.width, 500)
	t:eq(align.height, 300)
	t:eq(v.width, 500) -- width is stretched to match fill_x (direction column)
	t:eq(v.height, 50) -- height is intact
	t:eq(v.box.width, 500)
	t:eq(v.box.height, 50)

	align:arrange()
	t:eq(v.box.x, 0)
	t:eq(v.box.y, 125) -- (300 - 50) * 0.5 = 125
end

return test
