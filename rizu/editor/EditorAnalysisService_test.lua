local EditorAnalysisService = require("rizu.editor.EditorAnalysisService")
local Fraction = require("chart.core.Fraction")

local test = {}

---@param t testing.T
function test.detect_apply_and_render_wave(t)
	local calls = {}
	local wave = {
		id = "wave",
	}
	local layer = {
		id = "layer",
	}
	local service = EditorAnalysisService()
	local context = {
		getNcbtContext = function()
			return {
				detect = function(_, detectedWave)
					table.insert(calls, "detect")
					t:eq(detectedWave, wave)
				end,
				apply = function(_, appliedLayer)
					table.insert(calls, "apply")
					t:eq(appliedLayer, layer)
				end,
			}
		end,
		getAudioEngine = function()
			return {
				renderWave = function()
					table.insert(calls, "render")
					return wave
				end,
			}
		end,
		getLayer = function()
			return layer
		end,
		setWave = function(_, loadedWave)
			table.insert(calls, "setWave")
			t:eq(loadedWave, wave)
		end,
	}

	service:detectTempoOffset(context)
	service:applyNcbt(context)
	service:renderWave(context)

	t:tdeq(calls, {"render", "detect", "apply", "render", "setWave"})
end

---@param t testing.T
function test.get_first_last_time_includes_audio_start_before_first_point(t)
	local service = EditorAnalysisService()
	local context = {
		getAudioEngine = function()
			return {
				getStartTime = function()
					return -0.25
				end,
			}
		end,
		getLayer = function()
			return {
				points = {
					getFirstPoint = function()
						return {
							tonumber = function()
								return 1
							end,
						}
					end,
					getLastPoint = function()
						return {
							tonumber = function()
								return 3
							end,
						}
					end,
				},
			}
		end,
	}

	local firstTime, lastTime = service:getFirstLastTime(context)

	t:eq(firstTime, -0.25)
	t:eq(lastTime, 3)
end

---@param t testing.T
function test.get_timeline_range_keeps_chart_start_when_audio_starts_later(t)
	local service = EditorAnalysisService()
	local context = {
		getAudioEngine = function()
			return {
				getStartTime = function()
					return 1.5
				end,
			}
		end,
		getLayer = function()
			return {
				points = {
					getFirstPoint = function()
						return {
							tonumber = function()
								return 0
							end,
						}
					end,
					getLastPoint = function()
						return {
							tonumber = function()
								return 4
							end,
						}
					end,
				},
			}
		end,
	}

	local firstTime, lastTime = service:getTimelineRange(context)

	t:eq(firstTime, 0)
	t:eq(lastTime, 4)
end

---@param t testing.T
function test.get_total_beats_returns_average_beat_duration(t)
	local service = EditorAnalysisService()
	local context = {
		getLayer = function()
			return {
				getPointList = function()
					return {
						{
							time = Fraction(0),
							absoluteTime = 1,
						},
						{
							time = Fraction(12),
							absoluteTime = 7,
						},
					}
				end,
			}
		end,
	}

	local totalBeats, avgBeatDuration = service:getTotalBeats(context)

	t:eq(totalBeats, 12)
	t:eq(avgBeatDuration, 0.5)
end

---@param t testing.T
function test.gen_graphs_uses_timeline_range(t)
	local calls = {}
	local chart = {
		id = "chart",
	}
	local layer = {
		id = "layer",
		points = {
			getFirstPoint = function()
				return {
					tonumber = function()
						return -1
					end,
				}
			end,
			getLastPoint = function()
				return {
					tonumber = function()
						return 4
					end,
				}
			end,
		},
	}
	local service = EditorAnalysisService()
	local context = {
		getChart = function()
			return chart
		end,
		getLayer = function()
			return layer
		end,
		getAudioEngine = function()
			return {
				getStartTime = function()
					return 0
				end,
			}
		end,
		getGraphsGenerator = function()
			return {
				genDensityGraph = function(_, loadedChart, firstTime, lastTime)
					table.insert(calls, ("density:%s:%s"):format(firstTime, lastTime))
					t:eq(loadedChart, chart)
				end,
				genVerticesGraph = function(_, loadedLayer, firstTime, lastTime)
					table.insert(calls, ("vertices:%s:%s"):format(firstTime, lastTime))
					t:eq(loadedLayer, layer)
				end,
			}
		end,
	}

	service:genGraphs(context)

	t:tdeq(calls, {"density:-1:4", "vertices:-1:4"})
end

return test
