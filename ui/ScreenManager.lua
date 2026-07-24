local class = require("class")

---Owns loaded screens, their draw order, and the single input screen.
---@class ui.ScreenManager
---@operator call: ui.ScreenManager
---@field screen_registry gui.Screen[]
---@field visible_screens gui.Screen[] Bottom-to-top draw order
---@field input_screen gui.Screen?
---@field private registered {[gui.Screen]: true}
local ScreenManager = class()

function ScreenManager:new()
	---@type gui.Screen[]
	self.screen_registry = {}
	---@type gui.Screen[]
	self.visible_screens = {}
	self.input_screen = nil
	---@type {[gui.Screen]: true}
	self.registered = {}
end

---@param screen gui.Screen
function ScreenManager:register(screen)
	assert(not self.registered[screen], "screen is already registered")
	self.registered[screen] = true
	self.screen_registry[#self.screen_registry + 1] = screen
	screen:load()
end

---@param screens gui.Screen[]
function ScreenManager:registerAll(screens)
	for i = 1, #screens do
		self:register(screens[i])
	end
end

---@param screen gui.Screen
---@return integer? index
function ScreenManager:getVisibleIndex(screen)
	for i = 1, #self.visible_screens do
		if self.visible_screens[i] == screen then
			return i
		end
	end
end

---@param screen gui.Screen
function ScreenManager:show(screen)
	assert(self.registered[screen], "screen is not registered")
	if not self:getVisibleIndex(screen) then
		self.visible_screens[#self.visible_screens + 1] = screen
	end
end

---@param screen gui.Screen
function ScreenManager:hide(screen)
	assert(screen ~= self.input_screen, "cannot hide the input screen")
	local index = self:getVisibleIndex(screen)
	if index then
		table.remove(self.visible_screens, index)
	end
end

---Changes the sole input screen. keep_previous_visible allows an exit transition
---to continue updating and drawing until hide(previous) is called.
---@param screen gui.Screen
---@param keep_previous_visible boolean?
---@return boolean changed
function ScreenManager:setScreen(screen, keep_previous_visible)
	assert(self.registered[screen], "screen is not registered")
	local previous = self.input_screen
	if previous == screen then
		return false
	end

	if previous and previous:exit() == false then
		return false
	end
	if previous and previous.inputs then
		previous.inputs:clearSubtree(previous.root)
		previous.inputs = nil
	end
	if previous and not keep_previous_visible then
		self.input_screen = nil
		self:hide(previous)
	end

	-- The entering screen is always the top-most visible navigation screen.
	local index = self:getVisibleIndex(screen)
	if index then
		table.remove(self.visible_screens, index)
	end
	self.visible_screens[#self.visible_screens + 1] = screen
	self.input_screen = screen
	screen:enter()
	return true
end

---@param w number
---@param h number
---@param ui_scale number
function ScreenManager:resize(w, h, ui_scale)
	for i = 1, #self.screen_registry do
		local screen = self.screen_registry[i]
		screen:setUIScale(ui_scale)
		screen:resize(w, h)
	end
end

---@param inputs gui.Inputs
function ScreenManager:acceptInputs(inputs)
	for i = 1, #self.visible_screens do
		self.visible_screens[i]:flush()
	end
	if self.input_screen then
		self.input_screen:acceptInputs(inputs)
	end
end

---@param dt number
function ScreenManager:update(dt)
	for i = 1, #self.visible_screens do
		self.visible_screens[i]:update(dt)
	end
end

function ScreenManager:draw()
	for i = 1, #self.visible_screens do
		self.visible_screens[i]:draw()
	end
end

function ScreenManager:unload()
	local input_screen = self.input_screen
	if input_screen then
		input_screen:exit()
	end
	for i = 1, #self.screen_registry do
		self.screen_registry[i]:unload()
	end
	self.input_screen = nil
	self.visible_screens = {}
	self.screen_registry = {}
	self.registered = {}
end

return ScreenManager
