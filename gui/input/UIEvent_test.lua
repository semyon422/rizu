local UIEvent = require("gui.input.UIEvent")

local test = {}

---@param t testing.T
function test.constructor_all_false(t)
	local modifiers = {control = false, shift = false, alt = false, super = false}
	local e = UIEvent(modifiers)

	t:assert(not e.control_pressed, "control_pressed should be false")
	t:assert(not e.shift_pressed, "shift_pressed should be false")
	t:assert(not e.alt_pressed, "alt_pressed should be false")
	t:assert(not e.super_pressed, "super_pressed should be false")
	t:assert(not e.stop, "stop should be false")
end

---@param t testing.T
function test.constructor_all_true(t)
	local modifiers = {control = true, shift = true, alt = true, super = true}
	local e = UIEvent(modifiers)

	t:assert(e.control_pressed, "control_pressed should be true")
	t:assert(e.shift_pressed, "shift_pressed should be true")
	t:assert(e.alt_pressed, "alt_pressed should be true")
	t:assert(e.super_pressed, "super_pressed should be true")
end

---@param t testing.T
function test.constructor_mixed(t)
	local modifiers = {control = true, shift = false, alt = true, super = false}
	local e = UIEvent(modifiers)

	t:assert(e.control_pressed, "control_pressed should be true")
	t:assert(not e.shift_pressed, "shift_pressed should be false")
	t:assert(e.alt_pressed, "alt_pressed should be true")
	t:assert(not e.super_pressed, "super_pressed should be false")
end

---@param t testing.T
function test.stopPropagation(t)
	local modifiers = {control = false, shift = false, alt = false, super = false}
	local e = UIEvent(modifiers)

	t:assert(not e.stop, "stop should be false initially")
	e:stopPropagation()
	t:assert(e.stop, "stop should be true after stopPropagation")
end

return test
