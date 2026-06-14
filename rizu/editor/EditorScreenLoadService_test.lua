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
	local editorViewServices = {}
	local retainedViews = {
		{
			load = function()
				table.insert(calls, "retained-load:1")
			end,
			updateTransform = function()
				table.insert(calls, "retained-transform:1")
			end,
		},
		{
			load = function()
				table.insert(calls, "retained-load:2")
			end,
			updateTransform = function()
				table.insert(calls, "retained-transform:2")
			end,
		},
	}
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
		views = {},
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
		viewServicesFactory = function()
			table.insert(calls, "services-new")
			return editorViewServices
		end,
		retainedViewsFactory = function(loadedScreen)
			table.insert(calls, "retained-new")
			assert(loadedScreen == screen)
			return retainedViews
		end,
	})
	return service, screen, sequenceView, snapGridView, editorViewServices, retainedViews
end

---@param t testing.T
function test.enter_loads_editor_screen_views(t)
	local calls = {}
	local service, screen, sequenceView, snapGridView, editorViewServices, retainedViews = createScreen(calls)

	local started = service:enter(screen)

	t:eq(started, true)
	t:eq(screen.editor_loaded, true)
	t:eq(screen.loading, false)
	t:eq(screen.sequence_view, sequenceView)
	t:eq(screen.snap_grid_view, snapGridView)
	t:eq(screen.editorViewServices, editorViewServices)
	t:eq(screen.editor_retained_views, retainedViews)
	t:eq(screen.views[1], retainedViews[1])
	t:eq(screen.views[2], retainedViews[2])
	t:eq(snapGridView.editorViewServices, editorViewServices)
	t:eq(sequenceView.game, screen.game)
	t:eq(sequenceView.subscreen, "editor")
	t:eq(snapGridView.game, screen.game)
	t:ne(screen.transform, snapGridView.transform)
	t:tdeq(calls, {
		"editor-load",
		"services-new",
		"snap-new",
		"transform",
		"transform",
		"sequence-new",
		"sequence-config",
		"sequence-load",
		"retained-new",
		"retained-load:1",
		"retained-transform:1",
		"retained-load:2",
		"retained-transform:2",
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
	t:eq(screen.editorViewServices, nil)
	t:eq(screen.editor_retained_views, nil)
	t:eq(screen.snap_grid_view, nil)
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
	t:eq(screen.editorViewServices, nil)
	t:eq(screen.editor_retained_views, nil)
	t:eq(screen.snap_grid_view, nil)
	t:eq(#screen.views, 0)
	t:eq(calls[#calls - 1], "editor-unload")
	t:eq(calls[#calls], "sequence-unload")
end

return test
