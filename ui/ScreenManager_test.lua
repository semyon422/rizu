local ScreenManager = require("ui.ScreenManager")

local test = {}

---@return gui.Screen
local function newScreen()
	---@type gui.Screen
	local screen = {
		loaded = 0,
		unloaded = 0,
		entered = 0,
		exited = 0,
		updated = 0,
		drawn = 0,
		accepted = 0,
		flushed = 0,
	}
	function screen:load() self.loaded = self.loaded + 1 end
	function screen:unload() self.unloaded = self.unloaded + 1 end
	function screen:enter() self.entered = self.entered + 1 end
	function screen:exit()
		self.exited = self.exited + 1
		return true
	end
	function screen:flush() self.flushed = self.flushed + 1 end
	function screen:acceptInputs() self.accepted = self.accepted + 1 end
	function screen:update() self.updated = self.updated + 1 end
	function screen:draw() self.drawn = self.drawn + 1 end
	function screen:setUIScale(scale) self.scale = scale end
	function screen:resize(w, h) self.width, self.height = w, h end
	return screen
end

---@param t testing.T
function test.register_loads_screens_once(t)
	local manager = ScreenManager()
	local first = newScreen()
	local second = newScreen()
	manager:registerAll({first, second})

	t:eq(first.loaded, 1)
	t:eq(second.loaded, 1)
	t:has_error(function() manager:register(first) end)
end

---@param t testing.T
function test.multiple_visible_screens_run_but_only_one_accepts_input(t)
	local manager = ScreenManager()
	local first = newScreen()
	local second = newScreen()
	manager:registerAll({first, second})
	manager:setScreen(first)
	manager:setScreen(second, true)

	manager:acceptInputs({})
	manager:update(0.1)
	manager:draw()

	t:tdeq(manager.visible_screens, {first, second})
	t:eq(first.updated, 1)
	t:eq(second.updated, 1)
	t:eq(first.drawn, 1)
	t:eq(second.drawn, 1)
	t:eq(first.accepted, 0)
	t:eq(second.accepted, 1)
end

---@param t testing.T
function test.exit_can_veto_screen_change(t)
	local manager = ScreenManager()
	local first = newScreen()
	local second = newScreen()
	function first:exit()
		self.exited = self.exited + 1
		return false
	end
	manager:registerAll({first, second})
	manager:setScreen(first)

	t:eq(manager:setScreen(second), false)
	t:eq(manager.input_screen, first)
	t:tdeq(manager.visible_screens, {first})
	t:eq(second.entered, 0)
end

---@param t testing.T
function test.hide_removes_transition_screen(t)
	local manager = ScreenManager()
	local first = newScreen()
	local second = newScreen()
	manager:registerAll({first, second})
	manager:setScreen(first)
	manager:setScreen(second, true)
	manager:hide(first)

	t:tdeq(manager.visible_screens, {second})
end

return test
