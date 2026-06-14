local EditorPlayfieldInputStateService = require("rizu.editor.EditorPlayfieldInputStateService")

local test = {}

---@param t testing.T
function test.get_state_reads_legacy_mouse_buttons(t)
	local calls = {}
	local service = EditorPlayfieldInputStateService({
		mousePressed = function(button)
			table.insert(calls, "pressed:" .. button)
			return button == 1
		end,
		mouseReleased = function(button)
			table.insert(calls, "released:" .. button)
			return button == 1
		end,
	})

	local state = service:getState()

	t:eq(state.leftPressed, true)
	t:eq(state.rightPressed, false)
	t:eq(state.leftReleased, true)
	t:tdeq(calls, {
		"pressed:1",
		"pressed:2",
		"released:1",
	})
end

return test
