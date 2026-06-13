local EditorChartSliderService = require("rizu.editor.EditorChartSliderService")

local test = {}

local function createContext(fields)
	return {
		getPoint = function()
			return fields.point
		end,
		getTimelineRange = function()
			return fields.firstTime, fields.lastTime
		end,
		getDensityGraph = function()
			return fields.densityGraph
		end,
		getVertexDataGraph = function()
			return fields.vertexDataGraph
		end,
		getPreviewTime = function()
			return fields.previewTime
		end,
		scrollSeconds = function(_, time)
			return fields.scrollSeconds(time)
		end,
		isPlaying = function()
			return fields.playing == true
		end,
		play = function()
			fields.playing = true
			table.insert(fields.calls, "play")
		end,
		pause = function()
			fields.playing = false
			table.insert(fields.calls, "pause")
		end,
		isDragging = function()
			return fields.dragging == true
		end,
		setDragging = function(_, dragging)
			fields.dragging = dragging
			table.insert(fields.calls, "dragging:" .. tostring(dragging))
		end,
	}
end

---@param t testing.T
function test.get_state_reads_timeline_graphs_and_preview(t)
	local densityGraph = {}
	local vertexDataGraph = {}
	local context = createContext({
		point = {
			absoluteTime = 3,
		},
		firstTime = 1,
		lastTime = 5,
		densityGraph = densityGraph,
		vertexDataGraph = vertexDataGraph,
		previewTime = 2.5,
	})

	local state = EditorChartSliderService():getState(context)

	t:eq(state.firstTime, 1)
	t:eq(state.lastTime, 5)
	t:eq(state.fullLength, 4)
	t:eq(state.value, 0.5)
	t:eq(state.densityPoints, densityGraph)
	t:eq(state.vertexPoints, vertexDataGraph)
	t:eq(state.previewTime, 2.5)
end

---@param t testing.T
function test.active_drag_scrolls_and_pauses_playback(t)
	local calls = {}
	local context = createContext({
		calls = calls,
		playing = true,
		scrollSeconds = function(time)
			table.insert(calls, "scroll:" .. time)
		end,
	})
	local state = {
		firstTime = 10,
		fullLength = 20,
	}

	EditorChartSliderService():updateDrag(context, state, {
		active = true,
		newValue = 0.25,
	})

	t:tdeq(calls, {"scroll:15", "pause", "dragging:true"})
end

---@param t testing.T
function test.releasing_drag_resumes_playback(t)
	local calls = {}
	local context = createContext({
		calls = calls,
		dragging = true,
		scrollSeconds = function() end,
	})

	EditorChartSliderService():updateDrag(context, {}, {
		active = false,
	})

	t:tdeq(calls, {"play", "dragging:false"})
end

return test
