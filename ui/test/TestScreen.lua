local Screen = require("gui.Screen")
local ThreeColumns = require("ui.test.ThreeColumns")
local NineAnchors = require("ui.test.NineAnchors")
local OrbitOffsetTransform = require("ui.test.OrbitOffsetTransform")
local Opacity = require("ui.test.Opacity")
local FlexList = require("ui.test.FlexList")
local Checkbox = require("ui.test.Checkbox")
local Animations = require("ui.test.Animations")
local Animations2 = require("ui.test.Animations2")
local LayoutTransitions = require("ui.test.LayoutTransitions")

---@alias ui.test.BuildFn fun(root: gui.View)
---@alias ui.test.UpdateFn fun(screen: ui.test.TestScreen, dt: number)

---@class ui.test.TestCase
---@field name string
---@field build ui.test.BuildFn
---@field update ui.test.UpdateFn?

---@type ui.test.TestCase[]
local cases = {
	Animations2,
	ThreeColumns,
	NineAnchors,
	OrbitOffsetTransform,
	Opacity,
	FlexList,
	Checkbox,
	Animations,
	LayoutTransitions,
}

---@class ui.test.TestScreen: gui.Screen
---@operator call: ui.test.TestScreen
---@field private cases ui.test.TestCase[]
---@field private current_index integer
local TestScreen = Screen + {}

function TestScreen:new()
	Screen.new(self)
	self.cases = cases
	self.current_index = 1
	self:switchTo(1)
end

---@private
---@param index integer
function TestScreen:switchTo(index)
	local count = #self.cases
	index = ((index - 1) % count) + 1
	self.current_index = index

	local root = self.root
	root:clear()
	self.cases[index].build(root)

	if root.width > 0 and root.height > 0 then
		self:relayout()
	end
end

---@param event table
function TestScreen:receive(event)
	if event.name ~= "keypressed" then
		return
	end
	local key = event[1]
	if key == "left" then
		self:switchTo(self.current_index - 1)
	elseif key == "right" then
		self:switchTo(self.current_index + 1)
	elseif key == "+" then
		self:setUIScale(self.ui_scale * 1.1)
	elseif key == "-" then
		self:setUIScale(self.ui_scale / 1.1)
	end
end

---@param dt number
function TestScreen:update(dt)
	Screen.update(self, dt)
	local current_case = self.cases[self.current_index]
	if current_case.update then
		current_case.update(self, dt)
	end
end

return TestScreen
