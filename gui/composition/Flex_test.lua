local Flex = require("gui.composition.Flex")

local test = {}

---@param opts {width: number?, height: number?}
local function child(opts)
	opts._is_node = true
	opts.box = {}
	function opts:measure() end
	function opts:grow(w, h)
		self.width = w
		self.height = h
		self.box.w = w
		self.box.h = h
	end
	function opts:arrange()
		self.box.x = self.layout_x
		self.box.y = self.layout_y
	end
	return opts
end

---@param opts {width: number?, height: number?}
local function view(opts)
	opts._is_view = true
	opts.box = {}
	return opts
end

local function layout(node, w, h)
	node:measure()
	node:grow(w, h)
	node:arrange()
end

---@param t testing.T
function test.row_star_and_fixed_sizes(t)
	local a = child{width = 10, height = 10}
	local b = child{width = 10, height = 10}
	local c = child{width = 10, height = 10}
	local flex = Flex{
		direction = "row",
		sizes = {100, "*", 50},
		gap = 10,
		a, b, c,
	}
	layout(flex, 1000, 100)

	t:eq(a.box.x, 0)
	t:eq(a.box.w, 100)
	t:eq(b.box.x, 110)
	t:eq(b.box.w, 830)
	t:eq(c.box.x, 950)
	t:eq(c.box.w, 50)
end

---@param t testing.T
function test.row_percentage_sizes(t)
	local a = child{width = 10, height = 10}
	local b = child{width = 10, height = 10}
	local flex = Flex{
		direction = "row",
		sizes = {"40%", "60%"},
		a, b,
	}
	layout(flex, 1000, 100)

	t:eq(a.box.w, 400)
	t:eq(b.box.w, 600)
	t:eq(b.box.x, 400)
end

---@param t testing.T
function test.row_justify_center_without_stars(t)
	local a = child{width = 50, height = 10}
	local b = child{width = 50, height = 10}
	local flex = Flex{
		direction = "row",
		sizes = {50, 50},
		justify = "center",
		a, b,
	}
	layout(flex, 1000, 100)

	t:eq(a.box.x, 450)
	t:eq(b.box.x, 500)
end

---@param t testing.T
function test.row_justify_space_between_without_stars(t)
	local a = child{width = 50, height = 10}
	local b = child{width = 50, height = 10}
	local c = child{width = 50, height = 10}
	local flex = Flex{
		direction = "row",
		sizes = {50, 50, 50},
		justify = "space-between",
		a, b, c,
	}
	layout(flex, 1000, 100)

	t:eq(a.box.x, 0)
	t:eq(b.box.x, 475)
	t:eq(c.box.x, 950)
end

---@param t testing.T
function test.column_sizes(t)
	local a = child{width = 10, height = 10}
	local b = child{width = 10, height = 10}
	local c = child{width = 10, height = 10}
	local flex = Flex{
		direction = "column",
		sizes = {70, "*", 70},
		gap = 5,
		a, b, c,
	}
	layout(flex, 200, 1000)

	t:eq(a.box.h, 70)
	t:eq(b.box.h, 850)
	t:eq(b.box.y, 75)
	t:eq(c.box.y, 930)
	t:eq(c.box.h, 70)
end

---@param t testing.T
function test.padding_offsets_content(t)
	local a = child{width = 10, height = 10}
	local flex = Flex{
		direction = "row",
		padding = {5, 10, 15, 20},
		sizes = {"*"},
		a,
	}
	layout(flex, 1000, 100)

	t:eq(a.box.x, 5)
	t:eq(a.box.y, 10)
	t:eq(a.box.w, 975)
	t:eq(a.box.h, 75)
end

---@param t testing.T
function test.no_sizes_uses_intrinsic_widths_for_views(t)
	local a = view{width = 100, height = 10}
	local b = view{width = 200, height = 10}
	local c = child{width = 10, height = 10}
	local flex = Flex{
		direction = "row",
		gap = 10,
		a, b, c,
	}
	layout(flex, 1000, 100)

	t:eq(a.box.width, 100)
	t:eq(b.box.width, 200)
	t:eq(c.box.w, 680)
	t:eq(b.box.x, 110)
	t:eq(c.box.x, 320)
end

---@param t testing.T
function test.stars_absorb_all_available_space_so_justify_is_ignored(t)
	local a = child{width = 10, height = 10}
	local b = child{width = 10, height = 10}
	local flex = Flex{
		direction = "row",
		sizes = {"*", "*"},
		justify = "center",
		a, b,
	}
	layout(flex, 1000, 100)

	t:eq(a.box.x, 0)
	t:eq(a.box.w, 500)
	t:eq(b.box.x, 500)
	t:eq(b.box.w, 500)
end

return test
