local UserInterface = require("gui.UserInterface")
local View = require("gui.View")

local test = {}

local modifiers = {control = true, shift = false, alt = false, super = false}

---@return gui.UserInterface
---@return string[]
local function createInterface()
	local order = {}
	local target = View()
	target.onMouseDown = function(_, e)
		order[#order + 1] = ("down:%d:%d:%s"):format(e.x, e.y, tostring(e.control_pressed))
		return true
	end
	target.onMouseUp = function(_, e)
		order[#order + 1] = ("up:%d:%d"):format(e.x, e.y)
		return true
	end
	local screen_manager = {
		acceptInputs = function(_, inputs)
			inputs.mouse_hits[1] = target
			inputs.mouse_target = target
		end,
		receive = function() end,
		update = function() order[#order + 1] = "update" end,
	}
	return UserInterface(screen_manager), order
end

---@param t testing.T
function test.receive_queues_copied_events_until_update(t)
	local ui, order = createInterface()
	local event = {name = "mousepressed", 10, 20, 1}
	ui:receive(event, modifiers)
	event[1] = 999

	t:tdeq(order, {})
	ui:update(0)
	t:tdeq(order, {"down:10:20:true", "update"})
end

---@param t testing.T
function test.queued_pointer_events_keep_order_and_event_coordinates(t)
	local ui, order = createInterface()
	ui:receive({name = "mousepressed", 10, 20, 1}, modifiers)
	ui:receive({name = "mousereleased", 30, 40, 1}, modifiers)

	ui:update(0)

	t:tdeq(order, {"down:10:20:true", "up:30:40", "update"})
end

return test
