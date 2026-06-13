local EditorTimingOverlayService = require("rizu.editor.EditorTimingOverlayService")

local test = {}

local function createContext(fields)
	return {
		getPoint = function()
			return fields.point
		end,
		getEditorSettings = function()
			return fields.editor
		end,
		getIntervalManager = function()
			return fields.intervalManager
		end,
		scrollTimePoint = function(_, point)
			table.insert(fields.calls, "scroll:" .. point.id)
		end,
		scrollSecondsDelta = function(_, delta)
			table.insert(fields.calls, "scroll-delta:" .. delta)
		end,
		getVisualPointFor = function(_, point)
			table.insert(fields.calls, "visual:" .. point.id)
			return fields.visualPoints[point]
		end,
	}
end

---@param t testing.T
function test.show_timings_setting_uses_editor_settings(t)
	local editor = {
		showTimings = false,
	}
	local service = EditorTimingOverlayService()
	local context = createContext({
		editor = editor,
	})

	t:eq(service:isShowTimings(context), false)

	service:setShowTimings(context, true)

	t:eq(editor.showTimings, true)
	t:eq(service:isShowTimings(context), true)
end

---@param t testing.T
function test.scroll_prev_next_use_adjacent_points(t)
	local calls = {}
	local service = EditorTimingOverlayService()
	local context = createContext({
		calls = calls,
		point = {
			prev = {
				id = "prev",
			},
			next = {
				id = "next",
			},
		},
	})

	service:scrollPrev(context)
	service:scrollNext(context)

	t:tdeq(calls, {"scroll:prev", "scroll:next"})
end

---@param t testing.T
function test.interval_commands_delegate_to_interval_manager(t)
	local calls = {}
	local point = {}
	local vertex = {
		point = point,
	}
	local service = EditorTimingOverlayService()
	local context = createContext({
		calls = calls,
		point = point,
		intervalManager = {
			isGrabbed = function()
				table.insert(calls, "is-grabbed")
				return true
			end,
			split = function(_, splitPoint)
				table.insert(calls, "split")
				t:eq(splitPoint, point)
			end,
			grab = function(_, grabbedVertex)
				table.insert(calls, "grab")
				t:eq(grabbedVertex, vertex)
			end,
			drop = function()
				table.insert(calls, "drop")
			end,
			merge = function(_, mergedPoint)
				table.insert(calls, "merge")
				t:eq(mergedPoint, point)
			end,
			update = function(_, updatedVertex, beats)
				table.insert(calls, "update:" .. beats)
				t:eq(updatedVertex, vertex)
			end,
		},
	})

	t:eq(service:isGrabbed(context), true)
	service:split(context, point)
	service:grab(context, vertex)
	service:drop(context)
	service:merge(context, point)
	service:update(context, vertex, 8)

	t:tdeq(calls, {
		"is-grabbed",
		"split",
		"grab",
		"drop",
		"merge",
		"scroll-delta:0",
		"update:8",
	})
end

---@param t testing.T
function test.comment_visual_point_uses_adjacent_point_at_same_time(t)
	local calls = {}
	local point = {
		absoluteTime = 1,
		next = {
			prev = {
				id = "next-prev",
				absoluteTime = 1,
			},
		},
	}
	local visualPoint = {}
	local service = EditorTimingOverlayService()
	local context = createContext({
		calls = calls,
		point = point,
		visualPoints = {
			[point.next.prev] = visualPoint,
		},
	})

	t:eq(service:getCommentVisualPoint(context, point), visualPoint)
	t:tdeq(calls, {"visual:next-prev"})
end

---@param t testing.T
function test.comment_visual_point_returns_nil_when_adjacent_time_differs(t)
	local calls = {}
	local point = {
		absoluteTime = 1,
		prev = {
			prev = {
				id = "prev-prev",
				absoluteTime = 2,
			},
		},
	}
	local service = EditorTimingOverlayService()
	local context = createContext({
		calls = calls,
		point = point,
		visualPoints = {},
	})

	t:eq(service:getCommentVisualPoint(context, point), nil)
	t:tdeq(calls, {})
end

return test
