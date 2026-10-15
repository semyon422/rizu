local ModalManager = require("ui.ModalManager")

local test = {}

---@return ui.ModalManager manager
---@return table log
local function manager()
	local log = {}
	local self = setmetatable({}, {__index = ModalManager})
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

return test
