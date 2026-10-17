local EditorViewState = require("rizu.editor.state.EditorViewState")

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
	state:setDragging(true, "scroll")

	t:eq(state:getOverlayState(), "notes")
	t:eq(state:isDragging(), true)
	t:eq(state:isDragging("scroll"), true)
	t:eq(state:isDragging("chartSlider"), false)

	state:setDragging(false, "scroll")

	t:eq(state:isDragging(), false)
	t:eq(state.draggingOwner, nil)
end

return test
