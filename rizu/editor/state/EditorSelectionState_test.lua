local EditorSelectionState = require("rizu.editor.state.EditorSelectionState")

local test = {}

---@param t testing.T
function test.start_update_and_finish(t)
	local selectionState = EditorSelectionState()

	selectionState:start(1, 2, 3)
	t:eq(selectionState:isActive(), true)
	t:eq(selectionState:getStartTime(), 3)
	t:tdeq(selectionState:getRect(), {1, 2, 1, 2})

	selectionState:update(4, 5, 6)
	t:tdeq(selectionState:getRect(), {1, 6, 4, 5})

	selectionState:finish()
	t:eq(selectionState:isActive(), false)
	t:eq(selectionState:getRect(), nil)
	t:eq(selectionState:getStartTime(), nil)
end

return test
