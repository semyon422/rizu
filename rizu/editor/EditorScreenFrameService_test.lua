local EditorScreenFrameService = require("rizu.editor.EditorScreenFrameService")

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
		sequence_view = {
			update = function(_, dt)
				table.insert(calls, "sequence-update:" .. dt)
			end,
			draw = function()
				table.insert(calls, "sequence-draw")
			end,
			receive = function(_, event)
				table.insert(calls, "sequence:" .. event.name)
			end,
		},
		snap_grid_view = {
			draw = function()
				table.insert(calls, "snap-draw")
			end,
		},
	}
end

local function createService(calls)
	return EditorScreenFrameService({
		layout = {
			draw = function()
				table.insert(calls, "layout")
			end,
		},
		editorViewConfig = function()
			table.insert(calls, "config")
		end,
		waveformView = function()
			table.insert(calls, "waveform")
		end,
		onsetsView = function()
			table.insert(calls, "onsets")
		end,
		onsetsDistView = function()
			table.insert(calls, "onsets-dist")
		end,
		footer = function()
			table.insert(calls, "footer")
		end,
		editorViewOverlay = function()
			table.insert(calls, "overlay")
		end,
		foreground = function()
			table.insert(calls, "foreground")
		end,
		container = function(id, active)
			table.insert(calls, id and ("container:" .. id .. ":" .. tostring(active)) or "container:end")
		end,
		transform = function(transform)
			table.insert(calls, "transform:" .. transform)
			return "love-transform"
		end,
		graphics = {
			replaceTransform = function(transform)
				table.insert(calls, "replace:" .. transform)
			end,
		},
		baseScreen = {
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
		"transform:screen-transform",
		"replace:love-transform",
		"model-update",
		"sequence-update:0.5",
	})
end

---@param t testing.T
function test.draw_order_when_loaded(t)
	local calls = {}
	local screen = createScreen(calls)

	t:eq(createService(calls):draw(screen), true)

	t:tdeq(calls, {
		"container:yi editor screen:true",
		"layout",
		"config",
		"sequence-draw",
		"snap-draw",
		"waveform",
		"onsets",
		"onsets-dist",
		"footer",
		"overlay",
		"foreground",
		"container:end",
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
