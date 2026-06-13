local EditorNotesOverlayService = require("rizu.editor.EditorNotesOverlayService")

local test = {}

local function createContext(fields)
	return {
		getLogSpeed = function()
			return fields.logSpeed
		end,
		setLogSpeed = function(_, logSpeed)
			fields.logSpeed = logSpeed
			table.insert(fields.calls, "speed:" .. logSpeed)
		end,
		getEditorSettings = function()
			return fields.editor
		end,
		getMaxSnap = function()
			return fields.maxSnap
		end,
		getTools = function()
			return fields.tools
		end,
		getSelectedNotes = function()
			return fields.selectedNotes
		end,
	}
end

---@param t testing.T
function test.get_state_returns_settings_and_selected_note_sound(t)
	local selectedNote = {
		startNote = {
			sounds = {
				{"kick.wav"},
			},
		},
	}
	local tools = {"Select", "ShortNote"}
	local state = EditorNotesOverlayService():getState(createContext({
		calls = {},
		editor = {
			snap = 8,
			lockSnap = true,
			tool = "ShortNote",
		},
		logSpeed = 12,
		maxSnap = 192,
		tools = tools,
		selectedNotes = {
			[selectedNote.startNote] = selectedNote,
		},
	}))

	t:eq(state.logSpeed, 12)
	t:eq(state.snap, 8)
	t:eq(state.lockSnap, true)
	t:eq(state.tool, "ShortNote")
	t:eq(state.maxSnap, 192)
	t:eq(state.tools, tools)
	t:eq(state.hasSelectedNotes, true)
	t:eq(state.selectedNoteSound, "kick.wav")
end

---@param t testing.T
function test.set_log_speed_and_tool_hotkeys(t)
	local calls = {}
	local editor = {
		tool = "Select",
	}
	local service = EditorNotesOverlayService()
	local context = createContext({
		calls = calls,
		editor = editor,
		logSpeed = 12,
		maxSnap = 192,
		tools = {"Select", "ShortNote", "LongNote"},
		selectedNotes = {},
	})

	service:setLogSpeed(context, 20)

	t:eq(context:getLogSpeed(), 20)
	t:eq(service:getToolForHotkey(context:getTools(), "q"), "Select")
	t:eq(service:getToolForHotkey(context:getTools(), "e"), "LongNote")
	t:eq(service:getToolForHotkey(context:getTools(), "x"), nil)
	t:eq(service:setToolForHotkey(context, "e"), true)
	t:eq(editor.tool, "LongNote")
	t:eq(service:setToolForHotkey(context, "x"), false)
	t:eq(editor.tool, "LongNote")
	t:tdeq(calls, {"speed:20"})
end

---@param t testing.T
function test.setters_mutate_editor_settings(t)
	local editor = {
		snap = 4,
		lockSnap = false,
		tool = "Select",
	}
	local service = EditorNotesOverlayService()
	local context = createContext({
		calls = {},
		editor = editor,
		logSpeed = 12,
		maxSnap = 192,
		tools = {"Select"},
		selectedNotes = {},
	})

	service:setSnap(context, 16)
	service:setLockSnap(context, true)
	service:setTool(context, "LongNote")

	t:eq(editor.snap, 16)
	t:eq(editor.lockSnap, true)
	t:eq(editor.tool, "LongNote")
end

return test
