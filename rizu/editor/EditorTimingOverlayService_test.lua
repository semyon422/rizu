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
function test.get_state_returns_point_display_and_vertex_controls(t)
	local point = {
		prev = {},
		next = {},
		_vertex = {
			beats = 4,
		},
		vertex = {
			getTempo = function()
				return 150
			end,
		},
	}
	setmetatable(point, {
		__tostring = function()
			return "timing-point"
		end,
	})
	local service = EditorTimingOverlayService()
	local context = createContext({
		editor = {
			showTimings = true,
		},
		point = point,
		intervalManager = {
			isGrabbed = function()
				return false
			end,
		},
	})

	local state = service:getState(context)

	t:eq(state.point, point)
	t:eq(state.pointLabel, "timing-point")
	t:eq(state.pointStatusLabel, "Timing vertex")
	t:eq(state.showTimings, true)
	t:eq(state.canScrollPrev, true)
	t:eq(state.canScrollNext, true)
	t:eq(state.isGrabbed, false)
	t:eq(state.canSplit, false)
	t:eq(state.canGrab, true)
	t:eq(state.canDrop, false)
	t:eq(state.canMerge, true)
	t:eq(state.canEditBeats, true)
	t:eq(state.vertexActionLabel, "grab")
	t:eq(state.vertex, point._vertex)
	t:eq(state.tempoLabel, "Tempo: 150 bpm")
	t:eq(state.beats, 4)
	t:eq(state.beatsLabel, "beats 4")
end

---@param t testing.T
function test.get_state_exposes_split_action_without_vertex(t)
	local service = EditorTimingOverlayService()
	local context = createContext({
		editor = {
			showTimings = false,
		},
		point = {},
		intervalManager = {
			isGrabbed = function()
				return false
			end,
		},
	})

	local state = service:getState(context)

	t:eq(state.canSplit, true)
	t:eq(state.canGrab, false)
	t:eq(state.canDrop, false)
	t:eq(state.canMerge, false)
	t:eq(state.canEditBeats, false)
	t:eq(state.pointStatusLabel, "Timing point")
	t:eq(state.vertexActionLabel, "split")
end

---@param t testing.T
function test.get_state_exposes_drop_action_while_grabbed(t)
	local service = EditorTimingOverlayService()
	local context = createContext({
		editor = {
			showTimings = false,
		},
		point = {
			_vertex = {
				beats = 4,
			},
		},
		intervalManager = {
			isGrabbed = function()
				return true
			end,
		},
	})

	local state = service:getState(context)

	t:eq(state.canSplit, false)
	t:eq(state.canGrab, false)
	t:eq(state.canDrop, true)
	t:eq(state.canMerge, false)
	t:eq(state.canEditBeats, false)
	t:eq(state.pointStatusLabel, "Grabbed timing vertex")
	t:eq(state.vertexActionLabel, "drop")
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
function test.handle_navigation_input_uses_pressed_buttons(t)
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

	service:handleNavigationInput(context, {
		prevPressed = true,
		nextPressed = false,
	})
	service:handleNavigationInput(context, {
		prevPressed = false,
		nextPressed = true,
	})

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
function test.handle_vertex_input_splits_without_vertex(t)
	local calls = {}
	local point = {}
	local service = EditorTimingOverlayService()
	local context = createContext({
		calls = calls,
		point = point,
		intervalManager = {
			split = function(_, splitPoint)
				table.insert(calls, "split")
				t:eq(splitPoint, point)
			end,
		},
	})

	service:handleVertexInput(context, {
		point = point,
		pointLabel = "",
		showTimings = false,
		canScrollPrev = false,
		canScrollNext = false,
		isGrabbed = false,
	}, {
		splitPressed = true,
		grabPressed = false,
		dropPressed = false,
		mergePressed = false,
	})

	t:tdeq(calls, {"split"})
end

---@param t testing.T
function test.handle_vertex_input_grabs_without_updating_same_frame(t)
	local calls = {}
	local vertex = {
		beats = 4,
	}
	local service = EditorTimingOverlayService()
	local context = createContext({
		calls = calls,
		intervalManager = {
			grab = function(_, grabbedVertex)
				table.insert(calls, "grab")
				t:eq(grabbedVertex, vertex)
			end,
			update = function()
				table.insert(calls, "update")
			end,
		},
	})

	service:handleVertexInput(context, {
		point = {},
		pointLabel = "",
		showTimings = false,
		canScrollPrev = false,
		canScrollNext = false,
		isGrabbed = false,
		vertex = vertex,
		beats = 4,
		beatsLabel = "beats 4",
	}, {
		splitPressed = false,
		grabPressed = true,
		dropPressed = false,
		mergePressed = false,
		beats = 8,
	})

	t:tdeq(calls, {"grab"})
end

---@param t testing.T
function test.handle_vertex_input_drops_then_allows_visible_vertex_controls(t)
	local calls = {}
	local point = {}
	local vertex = {
		point = point,
		beats = 4,
	}
	local service = EditorTimingOverlayService()
	local context = createContext({
		calls = calls,
		intervalManager = {
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

	service:handleVertexInput(context, {
		point = {},
		pointLabel = "",
		showTimings = false,
		canScrollPrev = false,
		canScrollNext = false,
		isGrabbed = true,
		vertex = vertex,
		beats = 4,
		beatsLabel = "beats 4",
	}, {
		splitPressed = false,
		grabPressed = false,
		dropPressed = true,
		mergePressed = true,
		beats = 8,
	})

	t:tdeq(calls, {"drop", "merge", "scroll-delta:0", "update:8"})
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
function test.comment_state_uses_visual_point_comment_draft(t)
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
	local visualPoint = {
		comment = "saved",
	}
	local service = EditorTimingOverlayService()
	local context = createContext({
		calls = calls,
		point = point,
		visualPoints = {
			[point.next.prev] = visualPoint,
		},
	})

	local commentState = service:getCommentState(context, {
		point = point,
		pointLabel = "",
		showTimings = false,
		canScrollPrev = false,
		canScrollNext = false,
		isGrabbed = false,
	})

	t:ne(commentState, nil)
	---@cast commentState rizu.editor.EditorTimingCommentState
	t:eq(commentState.visualPoint, visualPoint)
	t:eq(commentState.value, "saved")

	service:setCommentDraft(commentState, "draft")

	t:eq(visualPoint.temp_comment, "draft")
	t:eq(commentState.value, "draft")
	t:tdeq(calls, {"visual:next-prev"})
end

---@param t testing.T
function test.comment_state_returns_nil_without_visual_point(t)
	local service = EditorTimingOverlayService()
	local context = createContext({
		calls = {},
		point = {
			absoluteTime = 1,
		},
		visualPoints = {},
	})

	t:eq(service:getCommentState(context, {
		point = context:getPoint(),
		pointLabel = "",
		showTimings = false,
		canScrollPrev = false,
		canScrollNext = false,
		isGrabbed = false,
	}), nil)
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
