local Setting = require("rizu.config.Setting")
local Checkbox = require("rizu.config.kinds.Checkbox")
local Choice = require("rizu.config.kinds.Choice")
local Range = require("rizu.config.kinds.Range")
local Textbox = require("rizu.config.kinds.Textbox")

local test = {}

---@param t testing.T
function test.setting_instantiation(t)
	local s = Setting("range", 0.5)
	t:eq(s.kind, "range")
	t:eq(s.default_value, 0.5)
	t:eq(s.is_deferred, false)
	t:eq(s.is_experemental, false)
	t:eq(s.is_restart_required, false)

	s:setDeferred(true)
	t:eq(s.is_deferred, true)

	s:setExperemental(true)
	t:eq(s.is_experemental, true)

	s:setRestartRequired(true)
	t:eq(s.is_restart_required, true)

	local s2 = Setting("checkbox", true):setDeferred(true):setExperemental(true):setRestartRequired(true)
	t:eq(s2.default_value, true)
	t:eq(s2.is_deferred, true)
	t:eq(s2.is_experemental, true)
	t:eq(s2.is_restart_required, true)
end

---@param t testing.T
function test.checkbox_instantiation(t)
	local cb = Checkbox(false):setDeferred(true)
	t:eq(cb.kind, "checkbox")
	t:eq(cb.default_value, false)
	t:eq(cb.is_deferred, true)
end

---@param t testing.T
function test.choice_instantiation(t)
	local fmt = function(v) return "Item " .. tostring(v) end
	local dd = Choice("pause", {"none", "pause", "quit"}, fmt):setDeferred(true)
	t:eq(dd.kind, "choice")
	t:eq(dd.default_value, "pause")
	t:eq(dd.is_deferred, true)
	t:tdeq(dd.options, {"none", "pause", "quit"})
	t:eq(dd.format("A"), "Item A")
end

---@param t testing.T
function test.range_instantiation(t)
	local sl = Range(1.0, 0.5, 3.0, 0.1):setRestartRequired(true)
	t:eq(sl.kind, "range")
	t:eq(sl.default_value, 1.0)
	t:eq(sl.min_value, 0.5)
	t:eq(sl.max_value, 3.0)
	t:eq(sl.step, 0.1)
	t:eq(sl.is_restart_required, true)
end

---@param t testing.T
function test.textbox_instantiation(t)
	local tb1 = Textbox("hello", true, 32):setExperemental(true)
	t:eq(tb1.kind, "textbox")
	t:eq(tb1.default_value, "hello")
	t:eq(tb1.is_secret, true)
	t:eq(tb1.max_characters, 32)
	t:eq(tb1.is_experemental, true)

	local tb2 = Textbox("world")
	t:eq(tb2.default_value, "world")
	t:eq(tb2.is_secret, false)
	t:eq(tb2.max_characters, nil)
end

return test
