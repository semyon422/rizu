local EditorPlayfieldHitTestService = require("rizu.editor.view.playfield.EditorPlayfieldHitTestService")

local test = {}

---@alias rizu.editor.HitTestResults {[any]: boolean}

---@class rizu.editor.TestEditorNote
---@field noteType string
---@field getInteractionState fun(): rizu.editor.EditorNoteInteractionState

---@param calls string[]
---@param results rizu.editor.HitTestResults
---@return rizu.editor.EditorPlayfieldHitTestService
local function createService(calls, results)
	return EditorPlayfieldHitTestService({
		mouseOver = function(id, over, layer)
			table.insert(calls, ("mouse:%s:%s:%s"):format(id, tostring(over), layer))
			if results[id] ~= nil then
				return results[id]
			end
			return over
		end,
		isOver = function(w, h, x, y)
			table.insert(calls, ("over:%s:%s:%s:%s"):format(w, h, x, y))
			return results.isOver
		end,
	})
end

---@param state {bodyOver: boolean}
---@return rizu.editor.TestEditorNote
local function createShortNote(state)
	return {
		noteType = "ShortNote",
		getInteractionState = function()
			return state
		end,
	}
end

---@param state {bodyOver: boolean, headOver: boolean, tailOver: boolean}
---@return rizu.editor.TestEditorNote
local function createLongNote(state)
	return {
		noteType = "LongNote",
		getInteractionState = function()
			return state
		end,
	}
end

---@param t testing.T
function test.short_note_input_uses_note_hover(t)
	local calls = {}
	local note = createShortNote({
		bodyOver = true,
	})
	local service = createService(calls, {
		[note] = false,
	})
	local input = service:getNoteInput(note, 1.5, {
		leftPressed = true,
		rightPressed = false,
		leftReleased = false,
	})

	t:eq(input.note, note)
	t:eq(input.mouseTime, 1.5)
	t:eq(input.leftPressed, true)
	t:eq(input.rightPressed, false)
	t:eq(input.bodyOver, false)
	t:tdeq(calls, {"mouse:" .. tostring(note) .. ":true:mouse"})
end

---@param t testing.T
function test.long_note_input_uses_body_head_tail_hover(t)
	local calls = {}
	local note = createLongNote({
		bodyOver = true,
		headOver = false,
		tailOver = false,
	})
	local noteId = tostring(note)
	local service = createService(calls, {
		[noteId .. "body"] = false,
		[noteId .. "head"] = true,
		[noteId .. "tail"] = false,
	})
	local input = service:getNoteInput(note, 2.5, {
		leftPressed = false,
		rightPressed = true,
		leftReleased = false,
	})

	t:eq(input.note, note)
	t:eq(input.mouseTime, 2.5)
	t:eq(input.leftPressed, false)
	t:eq(input.rightPressed, true)
	t:eq(input.bodyOver, false)
	t:eq(input.headOver, true)
	t:eq(input.tailOver, false)
	t:tdeq(calls, {
		"mouse:" .. noteId .. "body:true:mouse",
		"mouse:" .. noteId .. "head:false:mouse",
		"mouse:" .. noteId .. "tail:false:mouse",
	})
end

---@param t testing.T
function test.unknown_note_type_is_ignored(t)
	local calls = {}
	local service = createService(calls, {})

	---@diagnostic disable-next-line: missing-fields
	local input = service:getNoteInput({
		noteType = "Unsupported",
	}, 1.5, {
		leftPressed = true,
		rightPressed = false,
		leftReleased = false,
	})

	t:eq(input, nil)
	t:tdeq(calls, {})
end

---@param t testing.T
function test.column_input_uses_noteskin_column_bounds(t)
	local calls = {}
	local noteSkin = {
		unit = 64,
		getValue = function(_, value, columnIndex)
			return value + columnIndex
		end,
	}
	local head = {
		x = 10,
		w = 20,
	}
	local service = createService(calls, {
		isOver = true,
		["add note3"] = false,
	})
	local input = service:getColumnInput(noteSkin, head, 3, 4.5, {
		leftPressed = true,
		rightPressed = false,
		leftReleased = false,
	})

	t:eq(input.columnIndex, 3)
	t:eq(input.time, 4.5)
	t:eq(input.over, false)
	t:eq(input.leftPressed, true)
	t:tdeq(calls, {
		"over:23:64:13:0",
		"mouse:add note3:true:mouse",
	})
end

---@param t testing.T
function test.select_and_release_inputs_use_input_state(t)
	local calls = {}
	local service = createService(calls, {
		["editor select"] = true,
	})
	local inputState = {
		leftPressed = true,
		rightPressed = false,
		leftReleased = true,
	}

	local selectInput = service:getSelectInput(inputState)
	local releaseInput = service:getReleaseInput(5.5, inputState)

	t:eq(selectInput.over, true)
	t:eq(selectInput.leftPressed, true)
	t:eq(releaseInput.leftReleased, true)
	t:eq(releaseInput.mouseTime, 5.5)
	t:tdeq(calls, {"mouse:editor select:true:mouse"})
end

return test
