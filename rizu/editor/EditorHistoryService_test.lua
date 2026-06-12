local EditorHistoryService = require("rizu.editor.EditorHistoryService")

local test = {}

---@param t testing.T
function test.undo_redo_delegate_to_editor_changes(t)
	local calls = {}
	local service = EditorHistoryService()
	local context = {
		getEditorChanges = function()
			return {
				undo = function()
					table.insert(calls, "undo")
				end,
				redo = function()
					table.insert(calls, "redo")
				end,
			}
		end,
	}

	service:undo(context)
	service:redo(context)

	t:tdeq(calls, {"undo", "redo"})
end

return test
