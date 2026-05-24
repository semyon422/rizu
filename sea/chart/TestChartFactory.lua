local class = require("class")
local Chart = require("chart.model.Chart")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Visual = require("chart.model.visual.Visual")
local InputMode = require("chart.core.InputMode")
local Note = require("chart.format.notechart.Note")
local Tempo = require("chart.model.to.Tempo")
local Velocity = require("chart.model.visual.Velocity")
local Chartmeta = require("sea.chart.Chartmeta")
local Chartdiff = require("sea.chart.Chartdiff")
local Chartplay = require("sea.chart.Chartplay")

---@class sea.chart.TestChartFactory
---@operator call: sea.chart.TestChartFactory
local TestChartFactory = class()

---@param data table?
---@return sea.Chartmeta
function TestChartFactory:createChartmeta(data)
	local chartmeta = Chartmeta()
	chartmeta.id = data and (data.id or data.chartmeta_id)
	chartmeta.hash = data and data.hash or ""
	chartmeta.index = data and data.index or 1
	chartmeta.inputmode = data and data.inputmode or "4key"
	chartmeta.format = data and data.format or "sphere"
	chartmeta.title = data and data.title or "Test Title"
	chartmeta.artist = data and data.artist or "Test Artist"
	chartmeta.level = data and data.level or 1
	chartmeta.tempo = data and data.tempo or 120
	chartmeta.tempo_avg = data and data.tempo_avg or 120
	chartmeta.tempo_min = data and data.tempo_min or 120
	chartmeta.tempo_max = data and data.tempo_max or 120
	chartmeta.timings = data and data.timings or {}
	chartmeta.healths = data and data.healths or {}
	chartmeta.created_at = data and data.created_at or 0
	chartmeta.computed_at = data and data.computed_at or 0
	return chartmeta
end

---@param data table?
---@return sea.Chartdiff
function TestChartFactory:createChartdiff(data)
	local chartdiff = Chartdiff()
	chartdiff.id = data and (data.id or data.chartdiff_id)
	chartdiff.hash = data and data.hash or ""
	chartdiff.index = data and data.index or 1
	chartdiff.inputmode = data and data.inputmode or "4key"
	chartdiff.notes_count = data and data.notes_count or 0
	chartdiff.judges_count = data and data.judges_count or 0
	chartdiff.start_time = data and data.start_time or 0
	chartdiff.duration = data and data.duration or 0
	chartdiff.note_types_count = data and data.note_types_count or {tap = 0}
	chartdiff.enps_diff = data and data.enps_diff or 1
	chartdiff.osu_diff = data and data.osu_diff or 1
	chartdiff.msd_diff = data and data.msd_diff or 1
	chartdiff.msd_diff_data = data and data.msd_diff_data or {
		overall = 1, stream = 0, jumpstream = 0, handstream = 0,
		stamina = 0, jackspeed = 0, chordjack = 0, technical = 0
	}
	chartdiff.msd_diff_rates = data and data.msd_diff_rates or {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	chartdiff.mode = data and data.mode or "mania"
	chartdiff.modifiers = data and data.modifiers or {}
	chartdiff.rate = data and data.rate or 1000
	chartdiff.created_at = data and data.created_at or 0
	chartdiff.computed_at = data and data.computed_at or 0
	chartdiff.density_data = data and data.density_data or {}
	chartdiff.sv_data = data and data.sv_data or {}
	chartdiff.user_diff = data and data.user_diff or 0
	chartdiff.user_diff_data = data and data.user_diff_data or ""
	chartdiff.notes_preview = data and data.notes_preview or ""
	return chartdiff
end

---@param data table?
---@return sea.Chartplay
function TestChartFactory:createChartplay(data)
	local chartplay = Chartplay()
	chartplay.id = data and (data.id or data.chartplay_id)
	chartplay.user_id = data and data.user_id or 1
	chartplay.compute_state = data and data.compute_state or 0
	chartplay.computed_at = data and data.computed_at or 0
	chartplay.submitted_at = data and data.submitted_at or 0
	chartplay.replay_hash = data and data.replay_hash or ("r" .. (chartplay.id or math.random(1000000)))
	chartplay.pause_count = data and data.pause_count or 0
	chartplay.created_at = data and data.created_at or 0
	chartplay.hash = data and data.hash or ""
	chartplay.index = data and data.index or 1
	chartplay.modifiers = data and data.modifiers or {}
	chartplay.rate = data and data.rate or 1000
	chartplay.mode = data and data.mode or "mania"
	chartplay.nearest = data and data.nearest or false
	chartplay.tap_only = data and data.tap_only or false
	chartplay.custom = data and data.custom or false
	chartplay.const = data and data.const or false
	chartplay.rate_type = data and data.rate_type or "linear"
	chartplay.judges = data and data.judges or {0}
	chartplay.accuracy = data and data.accuracy or 1.0
	chartplay.max_combo = data and data.max_combo or 0
	chartplay.miss_count = data and data.miss_count or 0
	chartplay.not_perfect_count = data and data.not_perfect_count or 0
	chartplay.pass = data and data.pass ~= nil and data.pass or true
	chartplay.rating = data and data.rating or 0
	chartplay.rating_pp = data and data.rating_pp or 0
	chartplay.rating_msd = data and data.rating_msd or 0
	return chartplay
end

---@param inputmode_str string e.g. "4key"
---@param notes_table table[] e.g. {{time = 0, column = 1, velocity = {1, 1, 1}}, {time = 1, column = 2, end_time = 2}}
---@return {chart: ncdk2.Chart, chartmeta: sea.Chartmeta, chartdiff: sea.Chartdiff}
function TestChartFactory:create(inputmode_str, notes_table)
	local chart = Chart()
	chart.inputMode = InputMode(inputmode_str)
	local inputMap = chart.inputMode:getInputs()

	local layer = AbsoluteLayer()
	chart.layers.main = layer

	local visual = Visual()
	visual.primaryTempo = 120
	layer.visuals[""] = visual

	-- Set initial tempo at time 0
	local start_point = layer:getPoint(0)
	start_point._tempo = Tempo(120)

	local notes_count = 0
	local judges_count = 0
	local min_time = math.huge
	local max_time = -math.huge
	local note_types_count = {tap = 0, hold = 0}

	for _, n in ipairs(notes_table) do
		local point = layer:getPoint(n.time)
		local vp = visual:getPoint(point)

		if n.velocity then
			vp._velocity = Velocity(unpack(n.velocity))
		end

		if n.column then
			local column = inputMap[n.column] or n.column
			local note_type = n.type or (n.end_time and "hold" or "tap")

			if n.end_time then
				-- Long Note
				local start_note = Note(vp, column, note_type, 1)
				
				local end_point = layer:getPoint(n.end_time)
				local end_vp = visual:getPoint(end_point)
				local end_note = Note(end_vp, column, note_type, -1)
				
				chart.notes:insert(start_note)
				chart.notes:insert(end_note)
				
				note_types_count[note_type] = (note_types_count[note_type] or 0) + 1
				notes_count = notes_count + 1
				judges_count = judges_count + 2
				min_time = math.min(min_time, n.time)
				max_time = math.max(max_time, n.end_time)
			else
				-- Tap Note
				local note = Note(vp, column, note_type, 0)
				chart.notes:insert(note)
				
				note_types_count[note_type] = (note_types_count[note_type] or 0) + 1
				notes_count = notes_count + 1
				judges_count = judges_count + 1
				min_time = math.min(min_time, n.time)
				max_time = math.max(max_time, n.time)
			end
		end
	end

	chart:compute()

	if min_time == math.huge then
		min_time = 0
		max_time = 0
	end

	local chartmeta = self:createChartmeta({
		inputmode = inputmode_str,
		notes_count = notes_count,
	})

	local chartdiff = self:createChartdiff({
		inputmode = inputmode_str,
		notes_count = notes_count,
		judges_count = judges_count,
		start_time = min_time,
		duration = max_time - min_time,
		note_types_count = note_types_count,
	})

	return {
		chart = chart,
		chartmeta = chartmeta,
		chartdiff = chartdiff,
	}
end

return TestChartFactory
