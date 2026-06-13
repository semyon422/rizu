local EditorActionService = require("rizu.editor.EditorActionService")

local test = {}

local function createContext(pressed)
	local calls = {}
	local context = {
		save = function()
			table.insert(calls, "save")
		end,
		copyNotes = function(_, cut)
			table.insert(calls, cut and "cut" or "copy")
		end,
		pasteNotes = function()
			table.insert(calls, "paste")
		end,
		flipNotes = function()
			table.insert(calls, "flip")
		end,
		undo = function()
			table.insert(calls, "undo")
		end,
		redo = function()
			table.insert(calls, "redo")
		end,
		deleteNotes = function()
			table.insert(calls, "delete")
			return 3
		end,
		getCopiedNoteCount = function()
			return 2
		end,
		notify = function(_, message)
			table.insert(calls, "notify:" .. message)
		end,
		isEditorCommandRequested = function()
			return pressed.command == true
		end,
		keypressed = function(key)
			return pressed[key] == true
		end,
	}
	return context, calls
end

---@param t testing.T
function test.command_hotkeys_dispatch_actions(t)
	local cases = {
		{s = true, expected = {"save", "notify:saved"}},
		{c = true, expected = {"copy", "notify:copy 2 notes"}},
		{x = true, expected = {"cut", "notify:cut 2 notes"}},
		{v = true, expected = {"paste", "notify:paste 2 notes"}},
		{h = true, expected = {"flip", "notify:flip"}},
		{z = true, expected = {"undo", "notify:undo"}},
		{y = true, expected = {"redo", "notify:redo"}},
	}

	for _, case in ipairs(cases) do
		case.command = true
		local context, calls = createContext(case)

		EditorActionService():handleHotkeys(context)

		t:tdeq(calls, case.expected)
	end
end

---@param t testing.T
function test.delete_does_not_require_command_modifier(t)
	local context, calls = createContext({
		command = false,
		delete = true,
	})

	EditorActionService():handleHotkeys(context)

	t:tdeq(calls, {"delete", "notify:delete 3 notes"})
end

---@param t testing.T
function test.command_hotkeys_ignore_without_modifier(t)
	local context, calls = createContext({
		command = false,
		s = true,
		c = true,
	})

	EditorActionService():handleHotkeys(context)

	t:tdeq(calls, {})
end

return test
