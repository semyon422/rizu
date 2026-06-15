local EditorRhythmView = require("yi.views.editor.EditorRhythmView")

local test = {}

local function createNote()
	local calls = {}
	local note = {
		type = "short",
		noteType = "ShortNote",
		clearInteractionState = function()
			table.insert(calls, "clear")
		end,
		setPartInteractionState = function(_, part, over, selecting)
			table.insert(calls, ("state:%s:%s:%s"):format(part, tostring(over), tostring(selecting)))
		end,
	}
	return note, calls
end

---@param t testing.T
function test.draw_note_uses_shared_note_view_before_reporting_interaction(t)
	local note, calls = createNote()
	local oldLove = love
	love = {
		graphics = {
			inverseTransformPoint = function(x, y)
				return x, y
			end,
		},
		mouse = {
			getPosition = function()
				return -100, -100
			end,
		},
	}
	local notePart = {
		getSpriteBatch = function()
			return true
		end,
		getDimensions = function()
			return 20, 20
		end,
	}
	local noteView = {
		getNotePart = function(_, name)
			t:eq(name, "Head")
			return notePart
		end,
		getTransformParams = function()
			return 0, 0, 0, 1, 1, 0, 0
		end,
		draw = function()
			table.insert(calls, "draw")
		end,
	}
	local view = EditorRhythmView()
	view.chords = {}
	view.game = {
		resource_loader = {},
		editorModel = {
			getSelectionState = function()
				return {
					getRect = function()
						return nil
					end,
				}
			end,
		},
		noteSkinModel = {
			noteSkin = {
				getColumns = function()
					return {1}
				end,
			},
		},
	}
	function view:getNoteSkin()
		return self.game.noteSkinModel.noteSkin
	end
	function view:getNoteView(note_)
		t:eq(note_, note)
		return noteView
	end

	view:drawNote(note)
	love = oldLove

	t:tdeq(calls, {
		"draw",
		"clear",
		"state:body:false:false",
	})
	t:eq(noteView.graphicalNote, note)
	t:eq(noteView.rhythmView, view)
	t:eq(noteView.resource_loader, view.game.resource_loader)
end

---@param t testing.T
function test.short_note_interaction_uses_current_rhythm_transform(t)
	local note, calls = createNote()
	local oldLove = love
	love = {
		graphics = {
			inverseTransformPoint = function(x, y)
				return x - 100, y - 50
			end,
		},
		mouse = {
			getPosition = function()
				return 150, 60
			end,
		},
	}
	local notePart = {
		getSpriteBatch = function()
			return true
		end,
		getDimensions = function()
			return 20, 20
		end,
	}
	local noteView = {
		getNotePart = function()
			return notePart
		end,
		getTransformParams = function()
			return 40, 0, 0, 1, 1, 0, 0
		end,
		draw = function()
			table.insert(calls, "draw")
		end,
	}
	local view = EditorRhythmView()
	view.chords = {}
	view.game = {
		resource_loader = {},
		editorModel = {
			getSelectionState = function()
				return {
					getRect = function()
						return nil
					end,
				}
			end,
		},
		noteSkinModel = {
			noteSkin = {
				getColumns = function()
					return {1}
				end,
			},
		},
	}
	function view:getNoteSkin()
		return self.game.noteSkinModel.noteSkin
	end
	function view:getNoteView()
		return noteView
	end

	view:drawNote(note)
	love = oldLove

	t:tdeq(calls, {
		"draw",
		"clear",
		"state:body:true:false",
	})
end

return test
