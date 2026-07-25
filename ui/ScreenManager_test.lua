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
	function screen:receive() self.received = (self.received or 0) + 1 end
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
function test.service_layer_draws_above_navigation_and_collects_input_first(t)
	local manager = ScreenManager()
	local navigation = newScreen()
	local overlay = newScreen()
	local order = {}
	function navigation:acceptInputs() order[#order + 1] = "navigation input" end
	function overlay:acceptInputs() order[#order + 1] = "overlay input" end
	function navigation:draw() order[#order + 1] = "navigation draw" end
	function overlay:draw() order[#order + 1] = "overlay draw" end
	manager:register(navigation)
	manager:setOverlay(overlay)
	manager:setScreen(navigation)

	manager:acceptInputs({})
	manager:draw()

	t:tdeq(order, {
		"overlay input",
		"navigation input",
		"navigation draw",
		"overlay draw",
	})
end

---@param t testing.T
function test.receive_targets_overlay_then_input_screen_only(t)
	local manager = ScreenManager()
	local input = newScreen()
	local inactive = newScreen()
	local overlay = newScreen()
	local order = {}
	function input:receive() order[#order + 1] = "input" end
	function inactive:receive() order[#order + 1] = "inactive" end
	function overlay:receive() order[#order + 1] = "overlay" end
	manager:registerAll({input, inactive})
	manager:setOverlay(overlay)
	manager:setScreen(input)

	manager:receive({name = "keypressed", "a"})

	t:tdeq(order, {"overlay", "input"})
end

---@param t testing.T
function test.handled_overlay_receive_stops_propagation(t)
	local manager = ScreenManager()
	local input = newScreen()
	local overlay = newScreen()
	function overlay:receive() return true end
	manager:register(input)
	manager:setOverlay(overlay)
	manager:setScreen(input)

	t:eq(manager:receive({name = "keypressed", ";"}), true)
	t:eq(input.received, nil)
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
