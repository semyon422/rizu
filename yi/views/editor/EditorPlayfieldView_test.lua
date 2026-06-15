local EditorPlayfieldView = require("yi.views.editor.EditorPlayfieldView")

local test = {}

local function createNoteSkin()
	local Head = {
		x = {20, 40},
		w = {20, 20},
		h = {10, 10},
	}
	return {
		baseOffset = 20,
		fullWidth = 40,
		unit = 10,
		columnsCount = 2,
		notes = {
			ShortNote = {
				Head = Head,
			},
		},
		getValue = function(_, value, column)
			if type(value) == "table" then
				return value[column]
			end
			return value
		end,
		getInverseColumnPosition = function(_, x)
			if x >= 20 and x < 40 then
				return 1
			elseif x >= 40 and x < 60 then
				return 2
			end
		end,
		getInverseTimePosition = function(_, y)
			return y - 10
		end,
	}
end

local function withLove(mouseX, mouseY, f)
	local oldLove = love
	love = {
		graphics = {
			getDimensions = function()
				return 800, 600
			end,
		},
		mouse = {
			getPosition = function()
				return mouseX, mouseY
			end,
		},
	}
	local ok, err = xpcall(f, debug.traceback)
	love = oldLove
	if not ok then
		error(err)
	end
end

---@return yi.views.editor.EditorPlayfieldView
local function createView()
	return EditorPlayfieldView({
		transform = {100, 50, 0, 1, 1, 0, 0, 0, 0},
		game = {
			noteSkinModel = {
				noteSkin = createNoteSkin(),
			},
			editorModel = {
				getSettings = function()
					return {
						speed = 2,
					}
				end,
				getSessionTime = function()
					return 20
				end,
			},
		},
	})
end

---@param t testing.T
function test.column_input_uses_screen_to_playfield_transform(t)
	withLove(150, 50, function()
		local calls = {}
		local view = createView()
		local noteService = {
			setColumnOver = function(_, column)
				table.insert(calls, "column:" .. tostring(column))
			end,
			addNote = function(_, time, column)
				table.insert(calls, ("add:%s:%s"):format(time, column))
			end,
		}
		local context = {
			getViewState = function()
				return {
					getOverlayState = function()
						return "notes"
					end,
				}
			end,
			getEditorSettings = function()
				return {
					tool = "ShortNote",
				}
			end,
			getNoteService = function()
				return noteService
			end,
		}

		t:eq(view:getMouseColumn(), 2)
		t:eq(view:getMouseTime(), 25)
		t:eq(view:processColumnInputs(context, {
			leftPressed = true,
			rightPressed = false,
			leftReleased = false,
		}), true)

		t:tdeq(calls, {
			"column:2",
			"add:22.5:key2",
		})
	end)
end

---@param t testing.T
function test.note_input_sets_transformed_hover_column_before_grab(t)
	withLove(150, 50, function()
		local calls = {}
		local view = createView()
		local note = {
			noteType = "ShortNote",
			getInteractionState = function()
				return {
					bodyOver = true,
				}
			end,
		}
		local noteService = {
			setColumnOver = function(_, column)
				table.insert(calls, "column:" .. tostring(column))
			end,
			grabNotes = function(_, part, mouseTime)
				table.insert(calls, ("grab:%s:%s"):format(part, mouseTime))
			end,
		}
		local context = {
			getViewState = function()
				return {
					getOverlayState = function()
						return "notes"
					end,
				}
			end,
			selectNote = function(_, selectedNote)
				t:eq(selectedNote, note)
				table.insert(calls, "select")
			end,
			getNoteService = function()
				return noteService
			end,
		}

		t:eq(view:processNote(note, context, {
			leftPressed = true,
			rightPressed = false,
			leftReleased = false,
		}), true)

		t:tdeq(calls, {
			"column:2",
			"select",
			"grab:body:25",
		})
	end)
end

---@param t testing.T
function test.selection_start_uses_playfield_local_mouse_position(t)
	withLove(150, 50, function()
		local calls = {}
		local view = createView()
		local context = {
			getViewState = function()
				return {
					getOverlayState = function()
						return "notes"
					end,
				}
			end,
			getEditorSettings = function()
				return {
					tool = "Select",
				}
			end,
			selectStartAt = function(_, mx, my, mouseTime)
				table.insert(calls, ("select:%s:%s:%s"):format(mx, my, mouseTime))
			end,
		}

		t:eq(view:processSelectInput(context, {
			leftPressed = true,
			rightPressed = false,
			leftReleased = false,
		}), true)

		t:tdeq(calls, {
			"select:50:0:25",
		})
	end)
end

---@param t testing.T
function test.note_inputs_are_ignored_outside_notes_tab(t)
	withLove(150, 50, function()
		local calls = {}
		local view = createView()
		local context = {
			getViewState = function()
				return {
					getOverlayState = function()
						return "info"
					end,
				}
			end,
			getEditorSettings = function()
				return {
					tool = "ShortNote",
				}
			end,
			getNoteService = function()
				return {
					setColumnOver = function(_, column)
						table.insert(calls, "column:" .. tostring(column))
					end,
					addNote = function()
						table.insert(calls, "add")
					end,
				}
			end,
		}

		t:eq(view:processColumnInputs(context, {
			leftPressed = true,
			rightPressed = false,
			leftReleased = false,
		}), false)

		t:tdeq(calls, {})
	end)
end

return test
