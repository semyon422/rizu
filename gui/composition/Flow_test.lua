local Flow = require("gui.composition.Flow")

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
function test.row_lays_out_children_intrinsic_sizes(t)
	local a = child{width = 50, height = 30}
	local b = child{width = 80, height = 60}
	local flow = Flow{
		direction = "row",
		gap = 10,
		a, b,
	}
	layout(flow, 1000, 100)

	t:eq(a.box.x, 0)
	t:eq(a.box.y, 0)
	t:eq(a.box.w, 50)
	t:eq(a.box.h, 30)
	t:eq(b.box.x, 60)
	t:eq(b.box.y, 0)
	t:eq(b.box.w, 80)
	t:eq(b.box.h, 60)
end

---@param t testing.T
function test.row_does_not_grow_to_available(t)
	local a = child{width = 50, height = 30}
	local b = child{width = 80, height = 60}
	local flow = Flow{
		direction = "row",
		gap = 10,
		a, b,
	}
	layout(flow, 1000, 1000)

	t:eq(flow.width, 140)
	t:eq(flow.height, 60)
end

---@param t testing.T
function test.row_cross_align_center_within_fit_cross(t)
	local a = child{width = 50, height = 30}
	local b = child{width = 80, height = 60}
	local flow = Flow{
		direction = "row",
		align = 0.5,
		a, b,
	}
	layout(flow, 1000, 1000)

	t:eq(flow.height, 60)
	t:eq(a.box.y, 15)
	t:eq(a.box.h, 30)
	t:eq(b.box.y, 0)
	t:eq(b.box.h, 60)
end

---@param t testing.T
function test.row_cross_align_end_within_fit_cross(t)
	local a = child{width = 50, height = 30}
	local b = child{width = 80, height = 60}
	local flow = Flow{
		direction = "row",
		align = 1,
		a, b,
	}
	layout(flow, 1000, 1000)

	t:eq(a.box.y, 30)
	t:eq(b.box.y, 0)
end

---@param t testing.T
function test.child_without_intrinsic_cross_stays_zero(t)
	local a = child{width = 50}
	local flow = Flow{
		direction = "row",
		a,
	}
	layout(flow, 1000, 1000)

	t:eq(a.box.w, 50)
	t:eq(a.box.h, 0)
	t:eq(flow.height, 0)
end

---@param t testing.T
function test.padding_offsets_content_and_counts_in_size(t)
	local a = child{width = 10, height = 10}
	local flow = Flow{
		direction = "row",
		padding = {5, 10, 15, 20},
		a,
	}
	layout(flow, 1000, 100)

	t:eq(flow.width, 35)
	t:eq(flow.height, 35)
	t:eq(a.box.x, 5)
	t:eq(a.box.y, 10)
end

---@param t testing.T
function test.measure_reports_intrinsic_main_and_max_cross(t)
	local a = child{width = 50, height = 30}
	local b = child{width = 80, height = 60}
	local flow = Flow{
		direction = "row",
		gap = 10,
		a, b,
	}
	flow:measure()

	t:eq(flow.width, 140)
	t:eq(flow.height, 60)
end

---@param t testing.T
function test.measure_column_sums_heights(t)
	local a = child{width = 40, height = 20}
	local b = child{width = 60, height = 30}
	local flow = Flow{
		direction = "column",
		gap = 5,
		a, b,
	}
	flow:measure()

	t:eq(flow.width, 60)
	t:eq(flow.height, 55)
end

---@param t testing.T
function test.column_lays_out_sequentially(t)
	local a = child{width = 40, height = 20}
	local b = child{width = 60, height = 30}
	local flow = Flow{
		direction = "column",
		gap = 5,
		a, b,
	}
	layout(flow, 1000, 1000)

	t:eq(a.box.x, 0)
	t:eq(a.box.y, 0)
	t:eq(b.box.x, 0)
	t:eq(b.box.y, 25)
end

return test
