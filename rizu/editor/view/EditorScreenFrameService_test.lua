local EditorScreenFrameService = require("rizu.editor.view.EditorScreenFrameService")

local test = {}

local function createScreen(calls)
	return {
		editor_loaded = true,
		transform = "screen-transform",
		game = {
			editorModel = {
				update = function()
					table.insert(calls, "model-update")
				end,
			},
			editorController = {
				receive = function(_, event)
					table.insert(calls, "controller:" .. event.name)
				end,
			},
		},
	editor_sequence_view = {
		receive = function(_, event)
			table.insert(calls, "sequence:" .. event.name)
		end,
	},
	editor_snap_grid_view = {
		receive = function(_, event)
			table.insert(calls, "snap:" .. event.name)
		end,
	},
	editor_playfield_view = {
		receive = function(_, event)
			table.insert(calls, "playfield:" .. event.name)
		end,
	},
	}
end

local function createService(calls)
	return EditorScreenFrameService({
		layout = {
			update = function()
				table.insert(calls, "layout")
			end,
		},
		transform = function(transform)
			table.insert(calls, "transform:" .. transform)
			return "love-transform"
		end,
		graphics = {
			push = function(kind)
				table.insert(calls, "push:" .. kind)
			end,
			replaceTransform = function(transform)
				table.insert(calls, "replace:" .. transform)
			end,
			pop = function()
				table.insert(calls, "pop")
			end,
		},
		baseScreen = {
			update = function(_, dt)
				table.insert(calls, "screen-update:" .. dt)
			end,
			draw = function()
				table.insert(calls, "screen-draw")
			end,
			receive = function(_, event)
				table.insert(calls, "screen:" .. event.name)
			end,
		},
	})
end

---@param t testing.T
function test.update_ignored_when_not_loaded(t)
	local calls = {}
	local screen = createScreen(calls)
	screen.editor_loaded = false

	t:eq(createService(calls):update(screen, 0.5), false)
	t:tdeq(calls, {})
end

---@param t testing.T
function test.update_order_when_loaded(t)
	local calls = {}
	local screen = createScreen(calls)

	t:eq(createService(calls):update(screen, 0.5), true)

	t:tdeq(calls, {
		"push:all",
		"transform:screen-transform",
		"replace:love-transform",
		"model-update",
		"pop",
		"screen-update:0.5",
	})
end

---@param t testing.T
function test.update_includes_screen_views_when_attached(t)
	local calls = {}
	local screen = createScreen(calls)
	screen.editor_retained_views = {{}}

	t:eq(createService(calls):update(screen, 0.5), true)

	t:tdeq(calls, {
		"push:all",
		"transform:screen-transform",
		"replace:love-transform",
		"model-update",
		"pop",
		"screen-update:0.5",
	})
end

---@param t testing.T
function test.draw_order_when_loaded(t)
	local calls = {}
	local screen = createScreen(calls)

	t:eq(createService(calls):draw(screen), true)

	t:tdeq(calls, {
		"layout",
		"screen-draw",
	})
end

---@param t testing.T
function test.draw_uses_screen_views_when_attached(t)
	local calls = {}
	local screen = createScreen(calls)
	screen.editor_retained_views = {{}}

	t:eq(createService(calls):draw(screen), true)

	t:tdeq(calls, {
		"layout",
		"screen-draw",
	})
end

---@param t testing.T
function test.draw_ignored_when_not_loaded(t)
	local calls = {}
	local screen = createScreen(calls)
	screen.editor_loaded = false

	t:eq(createService(calls):draw(screen), false)
	t:tdeq(calls, {})
end

---@param t testing.T
function test.receive_order_when_loaded(t)
	local calls = {}
	local screen = createScreen(calls)

	t:eq(createService(calls):receive(screen, {name = "event"}), true)

	t:tdeq(calls, {
		"snap:event",
		"playfield:event",
		"controller:event",
		"sequence:event",
		"screen:event",
	})
end

---@param t testing.T
function test.receive_ignored_when_not_loaded(t)
	local calls = {}
	local screen = createScreen(calls)
	screen.editor_loaded = false

	t:eq(createService(calls):receive(screen, {name = "event"}), false)
	t:tdeq(calls, {})
end

return test
