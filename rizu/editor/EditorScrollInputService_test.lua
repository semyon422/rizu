local EditorScrollInputService = require("rizu.editor.EditorScrollInputService")
local EditorViewState = require("rizu.editor.EditorViewState")

local test = {}

local function createModel(flags, calls)
	return {
		viewState = EditorViewState(),
		timer = {
			is_playing = false,
		},
		scroller = {
			scrollSecondsDelta = function(_, delta)
				table.insert(calls, "seconds:" .. delta)
			end,
			scrollSnaps = function(_, scroll)
				table.insert(calls, "snaps:" .. scroll)
			end,
		},
		isFineScrollRequested = function()
			return flags.fine == true
		end,
		isSnapChangeRequested = function()
			return flags.snap == true
		end,
		isSpeedChangeRequested = function()
			return flags.speed == true
		end,
		pause = function(self)
			table.insert(calls, "pause")
			self.timer.is_playing = false
		end,
		play = function(self)
			table.insert(calls, "play")
			self.timer.is_playing = true
		end,
		incSnap = function()
			table.insert(calls, "inc")
		end,
		decSnap = function()
			table.insert(calls, "dec")
		end,
		getLogSpeed = function()
			table.insert(calls, "get-speed")
			return 10
		end,
		setLogSpeed = function(_, speed)
			table.insert(calls, "set-speed:" .. speed)
		end,
	}
end

local noteSkin = {
	unit = 50,
	getInverseTimePosition = function(_, y)
		return y / 10
	end,
}

---@param t testing.T
function test.fine_scroll_overrides_and_restores_speed(t)
	local calls = {}
	local flags = {
		fine = true,
	}
	local editor = {
		speed = 2,
	}
	local model = createModel(flags, calls)
	local service = EditorScrollInputService()

	local state = service:update(model, noteSkin, editor, {
		mouseY = 20,
		dragActive = false,
	})

	t:eq(editor.speed, 200)
	t:eq(state.showMouseDelta, true)

	flags.fine = false
	service:update(model, noteSkin, editor, {
		mouseY = 20,
		dragActive = false,
	})

	t:eq(editor.speed, 2)
end

---@param t testing.T
function test.drag_scroll_pauses_and_resumes_playback(t)
	local calls = {}
	local flags = {
		fine = true,
	}
	local editor = {
		speed = 2,
	}
	local model = createModel(flags, calls)
	model.timer.is_playing = true
	local service = EditorScrollInputService()
	service.prevMouseY = 10

	service:update(model, noteSkin, editor, {
		mouseY = 30,
		dragActive = true,
	})

	t:eq(model.viewState:isDragging(), true)
	t:tdeq(calls, {"seconds:0.01", "pause"})

	flags.fine = false
	service:update(model, noteSkin, editor, {
		mouseY = 30,
		dragActive = false,
	})

	t:eq(model.viewState:isDragging(), false)
	t:tdeq(calls, {"seconds:0.01", "pause", "play"})
end

---@param t testing.T
function test.scroll_changes_snap_or_speed(t)
	local calls = {}
	local editor = {
		speed = 1,
	}

	EditorScrollInputService():update(createModel({snap = true}, calls), noteSkin, editor, {
		mouseY = 0,
		dragActive = false,
		scroll = 1,
	})
	EditorScrollInputService():update(createModel({snap = true}, calls), noteSkin, editor, {
		mouseY = 0,
		dragActive = false,
		scroll = -1,
	})
	EditorScrollInputService():update(createModel({speed = true}, calls), noteSkin, editor, {
		mouseY = 0,
		dragActive = false,
		scroll = 2,
	})

	t:tdeq(calls, {"inc", "dec", "get-speed", "set-speed:12"})
end

---@param t testing.T
function test.normal_scroll_preserves_current_double_scroll_semantics(t)
	local calls = {}
	local editor = {
		speed = 1,
	}
	local model = createModel({}, calls)
	model.timer.is_playing = true

	EditorScrollInputService():update(model, noteSkin, editor, {
		mouseY = 0,
		dragActive = false,
		scroll = -1,
	})

	t:tdeq(calls, {"snaps:-1", "snaps:-1"})
end

return test
