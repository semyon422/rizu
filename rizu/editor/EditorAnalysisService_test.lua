local EditorAnalysisService = require("rizu.editor.EditorAnalysisService")

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
		ncbtContext = {
			detect = function(_, detectedWave)
				table.insert(calls, "detect")
				t:eq(detectedWave, wave)
			end,
			apply = function(_, appliedLayer)
				table.insert(calls, "apply")
				t:eq(appliedLayer, layer)
			end,
		},
		audio_engine = {
			renderWave = function()
				table.insert(calls, "render")
				return wave
			end,
		},
		layer = layer,
		setWave = function(loadedWave)
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
		audio_engine = {
			getStartTime = function()
				return -0.25
			end,
		},
		layer = {
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
		},
	}

	local firstTime, lastTime = service:getFirstLastTime(context)

	t:eq(firstTime, -0.25)
	t:eq(lastTime, 3)
end

---@param t testing.T
function test.get_timeline_range_keeps_chart_start_when_audio_starts_later(t)
	local service = EditorAnalysisService()
	local context = {
		audio_engine = {
			getStartTime = function()
				return 1.5
			end,
		},
		layer = {
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
		},
	}

	local firstTime, lastTime = service:getTimelineRange(context)

	t:eq(firstTime, 0)
	t:eq(lastTime, 4)
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
		chart = chart,
		layer = layer,
		audio_engine = {
			getStartTime = function()
				return 0
			end,
		},
		graphsGenerator = {
			genDensityGraph = function(_, loadedChart, firstTime, lastTime)
				table.insert(calls, ("density:%s:%s"):format(firstTime, lastTime))
				t:eq(loadedChart, chart)
			end,
			genVerticesGraph = function(_, loadedLayer, firstTime, lastTime)
				table.insert(calls, ("vertices:%s:%s"):format(firstTime, lastTime))
				t:eq(loadedLayer, layer)
			end,
		},
	}

	service:genGraphs(context)

	t:tdeq(calls, {"density:-1:4", "vertices:-1:4"})
end

return test
