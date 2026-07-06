local Anchor = require("gui.composition.Anchor")

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

local function layout(node, w, h)
	node:measure()
	node:grow(w, h)
	node:arrange()
end

---@param t testing.T
function test.measure_sums_children_for_fit_size(t)
	local a = child{width = 100, height = 50}
	local b = child{width = 200, height = 80}
	local anchor = Anchor{a, b}
	anchor:measure()

	t:eq(anchor.width, 300)
	t:eq(anchor.height, 130)
end

---@param t testing.T
function test.pivot_center_positions_in_middle_of_available(t)
	local a = child{width = 50, height = 30}
	local anchor = Anchor{
		pivot = {0.5, 0.5},
		a,
	}
	layout(anchor, 1000, 1000)

	t:eq(anchor.width, 50)
	t:eq(anchor.height, 30)
	t:eq(a.box.x, 475)
	t:eq(a.box.y, 485)
end

---@param t testing.T
function test.pivot_bottom_right(t)
	local a = child{width = 50, height = 30}
	local anchor = Anchor{
		pivot = {1, 1},
		a,
	}
	layout(anchor, 1000, 1000)

	t:eq(a.box.x, 950)
	t:eq(a.box.y, 970)
end

---@param t testing.T
function test.grow_passes_measured_size_to_children(t)
	local a = child{width = 50, height = 30}
	local anchor = Anchor{a}
	layout(anchor, 1000, 1000)

	t:eq(a.box.w, 50)
	t:eq(a.box.h, 30)
end

---@param t testing.T
function test.offset_shifts_position(t)
	local a = child{width = 50, height = 30}
	local anchor = Anchor{
		x = 100,
		y = 200,
		pivot = {0, 0},
		a,
	}
	layout(anchor, 1000, 1000)

	t:eq(a.box.x, 100)
	t:eq(a.box.y, 200)
end

return test
