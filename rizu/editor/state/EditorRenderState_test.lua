local EditorRenderState = require("rizu.editor.state.EditorRenderState")

local test = {}

---@param t testing.T
function test.note_skin(t)
	local renderState = EditorRenderState()
	local noteSkin = {}

	t:eq(renderState:getNoteSkin(), nil)

	renderState:setNoteSkin(noteSkin)

	t:eq(renderState:getNoteSkin(), noteSkin)
end

return test
