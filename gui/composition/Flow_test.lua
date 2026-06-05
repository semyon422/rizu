local transform = {}

function transform:setTransformation() end

love = love or {}
love.timer = love.timer or {
	getTime = os.clock,
}
love.math = love.math or {}
love.math.newTransform = love.math.newTransform or function()
	return transform
end

local Flow = require("gui.composition.Flow")

local test = {}

---@param width number
---@param height number
---@return gui.View
local function view(width, height)
	return {
		_is_view = true,
		width = width,
		height = height,
	}
end

---@param t testing.T
function test.row_fits_children_instead_of_available_space(t)
	local left = view(10, 8)
	local right = view(20, 12)
	local flow = Flow({
		gap = 5,
		align = 0.5,
		left,
		right,
	})

	flow:measure()
	t:eq(flow.width, 35)
	t:eq(flow.height, 12)

	flow:grow(200, 100)
	t:eq(flow.width, 35)
	t:eq(flow.height, 12)
	t:eq(left.box.width, 10)
	t:eq(left.box.height, 8)
	t:eq(right.box.width, 20)
	t:eq(right.box.height, 12)

	flow:arrange()
	t:eq(left.box.x, 0)
	t:eq(left.box.y, 2)
	t:eq(right.box.x, 15)
	t:eq(right.box.y, 0)
end

---@param t testing.T
function test.column_fits_children_and_aligns_cross_axis(t)
	local top = view(10, 20)
	local bottom = view(30, 5)
	local flow = Flow({
		direction = "column",
		gap = 3,
		align = 0.5,
		top,
		bottom,
	})

	flow:measure()
	t:eq(flow.width, 30)
	t:eq(flow.height, 28)

	flow:grow(200, 100)
	t:eq(flow.width, 30)
	t:eq(flow.height, 28)
	t:eq(top.box.width, 10)
	t:eq(top.box.height, 20)
	t:eq(bottom.box.width, 30)
	t:eq(bottom.box.height, 5)

	flow:arrange()
	t:eq(top.box.x, 10)
	t:eq(top.box.y, 0)
	t:eq(bottom.box.x, 0)
	t:eq(bottom.box.y, 23)
end

---@param t testing.T
function test.row_fits_nested_flows(t)
	local nested_left = view(10, 8)
	local nested_right = view(20, 12)
	local nested = Flow({
		gap = 5,
		nested_left,
		nested_right,
	})
	local right = view(7, 6)
	local flow = Flow({
		gap = 3,
		align = 0.5,
		nested,
		right,
	})

	flow:measure()
	t:eq(nested.width, 35)
	t:eq(nested.height, 12)
	t:eq(flow.width, 45)
	t:eq(flow.height, 12)

	flow:grow(200, 100)
	flow:arrange()

	t:eq(nested_left.box.x, 0)
	t:eq(nested_left.box.y, 0)
	t:eq(nested_right.box.x, 15)
	t:eq(nested_right.box.y, 0)
	t:eq(right.box.x, 38)
	t:eq(right.box.y, 3)
end

return test
