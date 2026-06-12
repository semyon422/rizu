local EditorTestFactory = require("rizu.editor.EditorTestFactory")

local test = {}

---@param t testing.T
function test.override_column_over(t)
	local editorModel = EditorTestFactory.createEditorModel()
	editorModel.noteService.columnService.columnOver = 3

	t:eq(editorModel.noteService.columnService:getColumnOver(), 3)
end

---@param t testing.T
function test.inverse_mouse_column(t)
	local editorModel = EditorTestFactory.createEditorModel()
	editorModel.getMousePosition = function()
		return 11, 0
	end
	editorModel:setNoteSkin({
		getInverseColumnPosition = function(_, x)
			return x - 7
		end,
	})

	t:eq(editorModel.noteService.columnService:getColumnOver(), 4)
end

return test
