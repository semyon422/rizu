local test = {}

local View = require("gui.View")
local Box = require("gui.Box")

local CountingView = View + {}

function CountingView:new()
	View.new(self)
	self.layout_updates = 0
end

function CountingView:onLayoutUpdate()
	self.layout_updates = self.layout_updates + 1
end

---@param t testing.T
function test.apply_layout_runs_on_each_explicit_layout_pass(t)
	local view = CountingView()
	view.box = Box()
	view.box:update(10, 20, 100, 50, 1)

	view:applyLayout()
	t:eq(view.layout_updates, 1)

	view:applyLayout()
	t:eq(view.layout_updates, 2)

	view.ui_scale = 2
	view:applyLayout()
	t:eq(view.layout_updates, 3)

	view.box:update(10, 20, 120, 50, 2)
	view:applyLayout()
	t:eq(view.layout_updates, 4)
end

---@param t testing.T
function test.refresh_aliases_apply_layout(t)
	local view = CountingView()
	view.box = Box()
	view.box:update(0, 0, 10, 10, 1)

	view:applyLayout()
	t:eq(view.layout_updates, 1)
end

return test
