local EditorModel = require("rizu.editor.EditorModel")

local test = {}

---@return rizu.editor.EditorModel
local function createEditorModel()
	---@type rizu.editor.EditorModel
	local editorModel = {
		configModel = {
			configs = {
				settings = {
					editor = {
						speed = 0,
						snap = 999,
					},
				},
			},
		},
		session = {
			point = {},
		},
	}
	setmetatable(editorModel, {__index = EditorModel})
	return editorModel
end

---@param t testing.T
function test.get_settings_normalizes_speed_and_snap(t)
	local editorModel = createEditorModel()
	local editor = editorModel:getSettings()

	t:eq(editor.speed, 1)
	t:eq(editor.snap, EditorModel.max_snap)
end

---@param t testing.T
function test.set_session_point_clones_point(t)
	local editorModel = createEditorModel()
	local point = {
		absoluteTime = 1.25,
		clone = function(self, target)
			target.absoluteTime = self.absoluteTime
			target.cloned = true
		end,
	}

	editorModel:setSessionPoint(point)

	t:eq(editorModel:getSessionTime(), 1.25)
	t:eq(editorModel.session.point.cloned, true)
end

return test
