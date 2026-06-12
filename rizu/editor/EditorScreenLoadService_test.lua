local EditorScreenLoadService = require("rizu.editor.EditorScreenLoadService")

local test = {}

local function createScreen(calls)
	local playfield = {
		newNoteskinTransform = function()
			table.insert(calls, "transform")
			return {
				id = "transform-" .. #calls,
			}
		end,
	}
	local sequenceView = {
		setSequenceConfig = function(_, loadedPlayfield)
			table.insert(calls, "sequence-config")
			assert(loadedPlayfield == playfield)
		end,
		load = function()
			table.insert(calls, "sequence-load")
		end,
		unload = function()
			table.insert(calls, "sequence-unload")
		end,
	}
	local snapGridView = {}
	local screen = {
		game = {
			editorController = {
				load = function()
					table.insert(calls, "editor-load")
				end,
				unload = function()
					table.insert(calls, "editor-unload")
				end,
			},
			noteSkinModel = {
				noteSkin = {
					playField = playfield,
				},
			},
		},
		editor_loaded = false,
		loading = false,
	}
	local service = EditorScreenLoadService({
		sequenceViewFactory = function()
			table.insert(calls, "sequence-new")
			return sequenceView
		end,
		snapGridViewFactory = function()
			table.insert(calls, "snap-new")
			return snapGridView
		end,
	})
	return service, screen, sequenceView, snapGridView
end

---@param t testing.T
function test.enter_loads_editor_screen_views(t)
	local calls = {}
	local service, screen, sequenceView, snapGridView = createScreen(calls)

	local started = service:enter(screen)

	t:eq(started, true)
	t:eq(screen.editor_loaded, true)
	t:eq(screen.loading, false)
	t:eq(screen.sequence_view, sequenceView)
	t:eq(screen.snap_grid_view, snapGridView)
	t:eq(sequenceView.game, screen.game)
	t:eq(sequenceView.subscreen, "editor")
	t:eq(snapGridView.game, screen.game)
	t:ne(screen.transform, snapGridView.transform)
	t:tdeq(calls, {
		"editor-load",
		"snap-new",
		"transform",
		"transform",
		"sequence-new",
		"sequence-config",
		"sequence-load",
	})
end

---@param t testing.T
function test.enter_is_ignored_while_loading_or_loaded(t)
	local calls = {}
	local service, screen = createScreen(calls)

	screen.loading = true
	t:eq(service:enter(screen), false)
	screen.loading = false
	screen.editor_loaded = true
	t:eq(service:enter(screen), false)

	t:tdeq(calls, {})
end

---@param t testing.T
function test.enter_failure_clears_loading_state(t)
	local calls = {}
	local service, screen = createScreen(calls)
	screen.game.editorController.load = function()
		table.insert(calls, "editor-load")
		error("load failed")
	end

	t:has_error(function()
		service:enter(screen)
	end)

	t:eq(screen.editor_loaded, false)
	t:eq(screen.loading, false)
	t:tdeq(calls, {"editor-load"})
end

---@param t testing.T
function test.exit_unloads_only_when_loaded(t)
	local calls = {}
	local service, screen = createScreen(calls)

	t:eq(service:exit(screen), false)
	t:eq(screen.loading, false)

	service:enter(screen)
	local unloaded = service:exit(screen)

	t:eq(unloaded, true)
	t:eq(screen.editor_loaded, false)
	t:eq(screen.loading, false)
	t:eq(calls[#calls - 1], "editor-unload")
	t:eq(calls[#calls], "sequence-unload")
end

return test
