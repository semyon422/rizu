local Engine = require("yi.Engine")
local View = require("yi.views.View")
local Context = require("yi.Context")
local Inputs = require("ui.input.Inputs")
local LayoutBox = require("ui.layout.LayoutBox")
local FunctionTimer = require("time.FunctionTimer")

local timer = FunctionTimer(function() return 0 end)

local test = {}

---@class yi.MockView : yi.View
---@overload fun(): yi.MockView
local MockView = View + {}
function MockView:new()
	View.new(self)
	self.update_calls = 0
	self.load_calls = 0
	self.load_complete_calls = 0
end

function MockView:load()
	self.load_calls = self.load_calls + 1
end

function MockView:loadComplete()
	self.load_complete_calls = self.load_complete_calls + 1
end

function MockView:update(_)
	self.update_calls = self.update_calls + 1
end

---@param t testing.T
function test.mounting_lifecycle(t)
	local inputs = Inputs()
	local ctx = Context({}, inputs)
	local engine = Engine(inputs, ctx, timer)

	local v1 = MockView()
	engine.root:add(v1)

	t:eq(v1.state, View.State.AwaitsMount) -- The root is still not mounted here
	t:eq(v1.load_calls, 0)

	engine:load() -- Mounts the root
	t:eq(v1.state, View.State.Loaded)
	t:eq(v1.load_calls, 1)
	t:eq(v1.load_complete_calls, 0)

	engine:update(0.016, 0, 0)
	t:eq(v1.state, View.State.Active)
	t:eq(v1.load_complete_calls, 1)
	t:eq(v1.update_calls, 1)

	engine:update(0.016, 0, 0)
	t:eq(v1.state, View.State.Active)
	t:eq(v1.load_complete_calls, 1)
	t:eq(v1.update_calls, 2)
end

---@param t testing.T
function test.states_and_updates(t)
	local inputs = Inputs()
	local ctx = Context({}, inputs)
	local engine = Engine(inputs, ctx, timer)
	engine:load()

	local v_active = engine.root:add(MockView())
	local v_killed = engine.root:add(MockView())

	t:eq(v_active.state, View.State.Loaded)
	t:eq(v_killed.state, View.State.Loaded)

	-- First update to transition them to Active
	engine:update(0.016, 0, 0)
	t:eq(v_active.state, View.State.Active)
	t:eq(v_killed.state, View.State.Active)

	v_killed:kill()

	engine:update(0.016, 0, 0)

	-- Active should be updated again
	t:eq(v_active.update_calls, 2)
	-- Killed should NOT be updated this frame
	t:eq(v_killed.update_calls, 1)

	-- Check deferred lists
	t:eq(#engine.removal_deferred, 1)
	t:eq(engine.removal_deferred[1], v_killed)

	-- Only one will remain
	t:eq(#engine.root.children, 1)
	t:eq(engine.root.children[1], v_active)

	-- Verify destroyed
	t:eq(v_killed.children, nil)
end

---@param t testing.T
function test.layout_and_transforms(t)
	local inputs = Inputs()
	local ctx = Context({}, inputs)
	local engine = Engine(inputs, ctx, timer)
	engine:load()

	-- Set root size
	engine.root.layout_box:setWidth(1000)
	engine.root.layout_box:setHeight(1000)

	local v1 = engine.root:add(MockView())
	v1.layout_box:setWidth(100)
	v1.layout_box:setHeight(100)
	v1.transform:setX(10)
	v1.transform:setY(20)

	local v2 = v1:add(MockView())
	v2.layout_box:setWidth(50)
	v2.layout_box:setHeight(50)
	v2.transform:setX(5)
	v2.transform:setY(5)

	-- First update to resolve initial layout and transforms
	engine:update(0.016, 0, 0)

	local x, y = v1.transform.love_transform:transformPoint(0, 0)
	t:eq(x, 10)
	t:eq(y, 20)

	local x2, y2 = v2.transform.love_transform:transformPoint(0, 0)
	t:eq(x2, 15) -- 10 + 5
	t:eq(y2, 25) -- 20 + 5

	-- Change V1 position via transform
	v1.transform:setX(50)
	v1.transform:setY(60)
	engine:update(0.016, 0, 0)

	x, y = v1.transform.love_transform:transformPoint(0, 0)
	t:eq(x, 50)
	t:eq(y, 60)

	x2, y2 = v2.transform.love_transform:transformPoint(0, 0)
	t:eq(x2, 55) -- 50 + 5
	t:eq(y2, 65) -- 60 + 5
end

---@param t testing.T
function test.layout_update_on_removal(t)
	local inputs = Inputs()
	local ctx = Context({}, inputs)
	local engine = Engine(inputs, ctx, timer)
	engine:load()

	-- Set root size
	engine.root.layout_box:setWidth(1000)
	engine.root.layout_box:setHeight(1000)

	local container = engine.root:add(MockView())
	container.layout_box:setArrange(LayoutBox.Arrange.FlowRow)
	container.layout_box:setWidth(200)
	container.layout_box:setHeight(100)

	local v1 = container:add(MockView())
	v1.layout_box:setWidth(50)
	v1.layout_box:setHeight(50)

	local v2 = container:add(MockView())
	v2.layout_box:setWidth(50)
	v2.layout_box:setHeight(50)

	-- First update to resolve initial layout
	engine:update(0.016, 0, 0)

	-- Check initial positions
	local x1, y1 = v1.transform.love_transform:transformPoint(0, 0)
	t:eq(x1, 0)
	t:eq(y1, 0)

	local x2, y2 = v2.transform.love_transform:transformPoint(0, 0)
	t:eq(x2, 50)
	t:eq(y2, 0)

	-- Kill v1
	v1:kill()
	engine:update(0.016, 0, 0)

	-- Now v2 should have moved to (0, 0) relative to container
	x2, y2 = v2.transform.love_transform:transformPoint(0, 0)
	t:eq(x2, 0)
	t:eq(y2, 0)

	-- Add v3
	local v3 = container:add(MockView())
	v3.layout_box:setWidth(50)
	v3.layout_box:setHeight(50)

	engine:update(0.016, 0, 0)
	-- v2 is at (0, 0), v3 is at (50, 0)
	x2, y2 = v2.transform.love_transform:transformPoint(0, 0)
	t:eq(x2, 0)
	local x3, y3 = v3.transform.love_transform:transformPoint(0, 0)
	t:eq(x3, 50)

	v2:kill()
	engine:update(0.016, 0, 0)

	-- v3 should move to (0, 0)
	x3, y3 = v3.transform.love_transform:transformPoint(0, 0)
	t:eq(x3, 0)
end

---@param t testing.T
function test.arranges(t)
	local inputs = Inputs()
	local ctx = Context({}, inputs)
	local engine = Engine(inputs, ctx, timer)
	engine:load()

	engine.root.layout_box:setDimensions(1000, 1000)
	engine.root.layout_box:setAlignItems(LayoutBox.AlignItems.Start)

	local container = engine.root:add(MockView())
	container.layout_box:setArrange(LayoutBox.Arrange.FlowCol)

	local n1 = container:add(MockView())
	local n2 = container:add(MockView())
	n1.layout_box:setDimensions(64, 32)
	n2.layout_box:setDimensions(64, 32)

	engine:update(0.016, 0, 0)

	t:eq(container.layout_box.x.size, 64)
	t:eq(container.layout_box.y.size, 64)
end

---@param t testing.T
function test.enabled_toggling(t)
	local inputs = Inputs()
	local ctx = Context({}, inputs)
	local engine = Engine(inputs, ctx, timer)
	engine:load()

	local container = engine.root:add(MockView())
	local child = container:add(MockView())

	-- First update to resolve initial states
	engine:update(0.016, 0, 0)
	engine.rebuild_command_buffer = false -- Reset manually for testing

	t:eq(child.enabled, true)
	t:eq(#container.children, 1)
	t:eq(#container.disabled_children, 0)

	-- Disable the child
	child:setEnabled(false)

	t:eq(child.enabled, false)
	t:eq(#container.children, 0)
	t:eq(#container.disabled_children, 1)
	t:eq(child.just_changed_enabled, true)

	-- Update engine
	engine:update(0.016, 0, 0)

	t:eq(child.just_changed_enabled, false)

	-- Enable the child
	child:setEnabled(true)

	t:eq(child.enabled, true)
	t:eq(#container.children, 1)
	t:eq(#container.disabled_children, 0)
	t:eq(child.just_changed_enabled, true)

	-- Update engine
	engine:update(0.016, 0, 0)

	t:eq(child.just_changed_enabled, false)
end

---@param t testing.T
function test.remove_disabled_view(t)
	local inputs = Inputs()
	local ctx = Context({}, inputs)
	local engine = Engine(inputs, ctx, timer)
	engine:load()

	local container = engine.root:add(MockView())
	local child = container:add(MockView())

	engine:update(0.016, 0, 0)

	-- Disable the child
	child:setEnabled(false)
	engine:update(0.016, 0, 0)

	t:eq(#container.children, 0)
	t:eq(#container.disabled_children, 1)

	-- Kill the disabled child
	child:kill()

	-- Update engine to process the kill
	engine:update(0.016, 0, 0)

	t:eq(#container.disabled_children, 0, "Disabled child should be removed from disabled_children upon kill")
	t:eq(child.children, nil, "Child should be destroyed")
end

return test
