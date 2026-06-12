local EditorViewState = require("rizu.editor.EditorViewState")

local test = {}

---@param t testing.T
function test.defaults_to_info_tab_and_not_dragging(t)
	local state = EditorViewState()

	t:eq(state:getOverlayState(), "info")
	t:eq(state:isDragging(), false)
end

---@param t testing.T
function test.stores_overlay_and_dragging_state(t)
	local state = EditorViewState()

	state:setOverlayState("notes")
	state:setDragging(true)

	t:eq(state:getOverlayState(), "notes")
	t:eq(state:isDragging(), true)

	state:setDragging(false)

	t:eq(state:isDragging(), false)
end

return test
