local ModalManager = require("ui.ModalManager")
local Inputs = require("gui.input.Inputs")
local Screen = require("gui.Screen")
local View = require("gui.View")

local test = {}

---@return ui.ModalManager manager
---@return table log
local function manager()
	local log = {}
	local self = setmetatable({}, {__index = ModalManager})
	self.popup_container = {} --[[@as any]]
	self.bg = {show = function() log[#log + 1] = "bg_show" end, hide = function() log[#log + 1] = "bg_hide" end}
	return self --[[@as ui.ModalManager]], log
end

local function view(name, log)
	return {
		show = function() log[#log + 1] = name .. "_show" end,
		hide = function() log[#log + 1] = name .. "_hide" end,
	}
end

---@param t testing.T
function test.locked_modal_cannot_be_closed_or_replaced(t)
	local m, log = manager()
	local busy, other = view("busy", log), view("other", log)
	t:eq(m:showModal(busy --[[@as any]]), true)
	busy.locked = true

	t:eq(m:hideModal(), false)
	t:eq(m:hideModal(busy --[[@as any]]), false)
	t:eq(m:showModal(other --[[@as any]]), false)
	t:eq(m.active_view, busy)

	busy.locked = false
	t:eq(m:showModal(other --[[@as any]]), true)
	t:eq(m.active_view, other)
	t:eq(m:hideModal(), true)
	t:eq(m.active_view, nil)
end

---@param t testing.T
function test.replacing_modal_closes_popup_holding_a_focus_scope(t)
	local s = Screen()
	local first, second, popup = View(), View(), View()
	for _, v in ipairs({first, second, popup}) do
		local modal = v --[[@as any]]
		modal.show, modal.hide = function() end, function() end
		s.root:add(v)
	end
	s:relayout()
	local inputs = Inputs()
	local m = manager()
	m.screen = {inputs = inputs} --[[@as any]]
	m:showModal(first --[[@as any]])
	inputs:pushFocusScope(popup)
	m.popup_container.owner = {close = function()
		inputs:popFocusScope(popup)
		m.popup_container.owner = nil
		return true
	end}

	m:showModal(second --[[@as any]])

	t:eq(#inputs.focus_scopes, 1)
	t:eq(inputs.focus_scopes[1].root, second)
end

return test
