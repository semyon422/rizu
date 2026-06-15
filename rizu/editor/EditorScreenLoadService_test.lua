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
	local editorViewServices = {}
	local retainedViews = {
		{
			load = function()
				table.insert(calls, "retained-load:1")
			end,
			unload = function()
				table.insert(calls, "retained-unload:1")
			end,
			updateTransform = function()
				table.insert(calls, "retained-transform:1")
			end,
		},
		{
			load = function()
				table.insert(calls, "retained-load:2")
			end,
			unload = function()
				table.insert(calls, "retained-unload:2")
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
	return service, screen, editorViewServices, retainedViews
end

---@param t testing.T
function test.enter_loads_editor_screen_views(t)
	local calls = {}
	local service, screen, editorViewServices, retainedViews = createScreen(calls)

	local started = service:enter(screen)

	t:eq(started, true)
	t:eq(screen.editor_loaded, true)
	t:eq(screen.loading, false)
	t:eq(screen.editorViewServices, editorViewServices)
	t:eq(screen.editor_retained_views, retainedViews)
	t:eq(screen.snap_grid_transform.id, "transform-3")
	t:eq(screen.views[1], retainedViews[1])
	t:eq(screen.views[2], retainedViews[2])
	t:ne(screen.transform, screen.snap_grid_transform)
	t:tdeq(calls, {
		"editor-load",
		"services-new",
		"transform",
		"transform",
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
	t:eq(screen.snap_grid_transform, nil)
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
	t:eq(screen.editor_sequence_view, nil)
	t:eq(screen.snap_grid_transform, nil)
	t:eq(#screen.views, 0)
	t:eq(calls[#calls - 2], "editor-unload")
	t:eq(calls[#calls - 1], "retained-unload:1")
	t:eq(calls[#calls], "retained-unload:2")
end

return test
