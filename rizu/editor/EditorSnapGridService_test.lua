local EditorSnapGridService = require("rizu.editor.EditorSnapGridService")

local test = {}

local function createContext(fields)
	return {
		getLayer = function()
			return {
				iter = function(_, firstTime, lastTime)
					assert(firstTime == 1)
					assert(lastTime == 3)
					local index = 0
					return function()
						index = index + 1
						return fields.points[index]
					end
				end,
			}
		end,
		getIterRange = function()
			return 1, 3
		end,
		getVisualPointFor = function(_, point)
			return fields.visualPoints[point] or {}
		end,
	}
end

---@param t testing.T
function test.get_labels_returns_timing_and_comment_labels(t)
	local timingPoint = {
		_vertex = {
			getTempo = function()
				return 120
			end,
		},
	}
	local commentPoint = {}
	local bothPoint = {
		vertex = {
			getTempo = function()
				return 123.45
			end,
		},
	}
	local service = EditorSnapGridService()

	local labels = service:getLabels(createContext({
		points = {
			timingPoint,
			commentPoint,
			bothPoint,
		},
		visualPoints = {
			[commentPoint] = {
				comment = "comment",
			},
			[bothPoint] = {
				comment = "both",
			},
		},
	}), true)

	t:tdeq(labels, {
		{
			point = timingPoint,
			text = "tempo 120 bpm",
			lane = 0,
			kind = "timing",
		},
		{
			point = commentPoint,
			text = "comment",
			lane = 1,
			kind = "comment",
		},
		{
			point = bothPoint,
			text = "tempo 123.45 bpm",
			lane = 0,
			kind = "timing",
		},
		{
			point = bothPoint,
			text = "both",
			lane = 1,
			kind = "comment",
		},
	})
end

---@param t testing.T
function test.get_timing_text_returns_nil_without_vertex(t)
	t:eq(EditorSnapGridService():getTimingText({}), nil)
end

---@param t testing.T
function test.get_labels_hides_timing_labels_when_timings_are_disabled(t)
	local timingPoint = {
		_vertex = {
			getTempo = function()
				return 120
			end,
		},
	}
	local commentPoint = {}
	local labels = EditorSnapGridService():getLabels(createContext({
		points = {
			timingPoint,
			commentPoint,
		},
		visualPoints = {
			[commentPoint] = {
				comment = "comment",
			},
		},
	}), false)

	t:tdeq(labels, {
		{
			point = commentPoint,
			text = "comment",
			lane = 1,
			kind = "comment",
		},
	})
end

---@param t testing.T
function test.get_labels_collapses_consecutive_identical_timing_labels(t)
	local firstPoint = {
		_vertex = {
			getTempo = function()
				return 175
			end,
		},
	}
	local duplicatePoint = {
		_vertex = {
			getTempo = function()
				return 175
			end,
		},
	}
	local changedPoint = {
		_vertex = {
			getTempo = function()
				return 180
			end,
		},
	}
	local labels = EditorSnapGridService():getLabels(createContext({
		points = {
			firstPoint,
			duplicatePoint,
			changedPoint,
		},
		visualPoints = {},
	}), true)

	t:tdeq(labels, {
		{
			point = firstPoint,
			text = "tempo 175 bpm",
			lane = 0,
			kind = "timing",
		},
		{
			point = changedPoint,
			text = "tempo 180 bpm",
			lane = 0,
			kind = "timing",
		},
	})
end

return test
