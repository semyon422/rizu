local json = require("web.json")
local InputMode = require("chart.core.InputMode")
local NotesPreview = require("rizu.preview.NotesPreview")
local pattern_classifier = require("chart.scoring.pattern_classifier")

local PATTERN_KEYS = {[4] = true, [6] = true, [7] = true, [8] = true, [10] = true, [14] = true}

---@class ui.commands.UiSelectCommands.PatternChart
---@field hash string?
---@field index integer?
---@field chartdiff_inputmode string?
---@field notes_preview string?
---@field chartmeta_mode string?
---@field artist string?
---@field title string?
---@field name string?

---The chartview's mania notes from its notes preview, sorted by time then column; nil for other
---gamemodes or no preview. Errors on a broken preview.
---@param chart ui.commands.UiSelectCommands.PatternChart
---@return {time: number, column: integer, end_time: number?}[]?
local function chart_notes(chart)
	local inputmode = chart.chartdiff_inputmode
	if not inputmode or not chart.notes_preview or (chart.chartmeta_mode and chart.chartmeta_mode ~= "mania") then
		return
	end
	-- the notes preview's decoder, ~6x faster than chart.format.sph.ChartDecoder and the same notes
	return NotesPreview.getNotes(chart.notes_preview, InputMode(inputmode):getColumns())
end

---The selected chart's notes as JSON for calc/pattern_editor.html, or nil and why not.
---@param chart ui.commands.UiSelectCommands.PatternChart?
---@return string?
---@return string?
local function pattern_chart(chart)
	if not chart then
		return nil, "No chart is selected"
	end
	local ok, notes = pcall(chart_notes, chart)
	if not ok or not notes or #notes == 0 then
		return nil, ok and "The chart has no notes preview" or tostring(notes)
	end
	local keys
	notes, keys = pattern_classifier.without_scratch(notes, chart.chartdiff_inputmode)
	if not PATTERN_KEYS[keys] then
		return nil, ("Pattern labeling reads 4K, 6K-8K, 10K and 14K, not %s"):format(chart.chartdiff_inputmode)
	end
	local list = {} ---@type table[]
	for i, n in ipairs(notes) do
		list[i] = {math.floor(n.time * 1000 + 0.5) / 1000, n.column, n.end_time and math.floor(n.end_time * 1000 + 0.5) / 1000 or json.null}
	end
	local name = ("%s - %s [%s]"):format(chart.artist or "?", chart.title or "?", chart.name or "?")
	return json.encode({rizu_pattern_chart = 1, name = name, hash = chart.hash, index = chart.index, keys = keys, notes = list})
end

---@param game sphere.GameController
---@param ui ui.UserInterface
---@return rizu.command.Command[]
return function(game, ui)
	return {
		{
			id = "ui.select.play",
			title = "Select: Play",
			description = "Starts the selected chart",
			callback = function()
				if ui.api.charts:canPlaySelectedChart() then
					ui:loadSelectedChart(false, false, true)
				end
			end,
		},
		{
			id = "ui.select.autoplay",
			title = "Select: Autoplay",
			description = "Starts the selected chart with autoplay enabled",
			callback = function()
				if ui.api.charts:canPlaySelectedChart() then
					ui:loadSelectedChart(true, false, true)
				end
			end,
		},
		{
			id = "ui.select.local_replay",
			title = "Select: Watch Local Replay",
			description = "Plays the latest local attempt of the selected chart, for gamemodes that do not save scores",
			callback = function()
				if ui.api.play:hasLocalReplays() then
					ui:loadSelectedChart(false, false, true, true)
				end
			end,
		},
		{
			id = "ui.select.open_result",
			title = "Select: Open Result",
			description = "Opens the selected score result",
			callback = function()
				if ui.api.charts:canPlaySelectedChart() and ui.api.scores:getSelected() then
					ui.api.scores:loadSelectedResult(function(ok)
						ui:setScreen(ok and ui.result or ui.song_select)
					end)
				end
			end,
		},
		{
			id = "ui.select.open_input",
			title = "Modal: Open Input",
			description = "Opens input bindings",
			callback = function()
				ui.modal_manager:attachInput()
			end,
		},
		{
			id = "ui.select.copy_pattern_chart",
			title = "Select: Copy Chart For Pattern Labeling",
			description = "Copies the selected chart's notes, to paste into calc/pattern_editor.html",
			callback = function()
				local text, err = pattern_chart(ui.api.charts:getSelectedChart() --[[@as ui.commands.UiSelectCommands.PatternChart?]])
				if not text then
					ui.api.notifications:post("error", "pattern_chart_failed", "Can't copy the chart", err)
					return
				end
				love.system.setClipboardText(text)
				ui.api.notifications:post("success", "pattern_chart_copied", "Chart copied", "Paste it into the pattern editor's Charts tab")
			end,
		},
		--[[{
			id = "ui.select.open_modifiers",
			title = "Modal: Open Modifiers",
			description = "Opens gameplay modifiers",
			callback = function() ui.modals:open("modifiers") end,
		},
		{
			id = "ui.select.open_filters",
			title = "Modal: Open Filters",
			description = "Opens select filters",
			callback = function() ui.modals:open("filters") end,
		},
		{
			id = "ui.select.open_input",
			title = "Modal: Open Input",
			description = "Opens input bindings",
			callback = function() ui.modals:open("input") end,
		},
		{
			id = "ui.select.open_noteskins",
			title = "Modal: Open Note Skins",
			description = "Opens note skin selection",
			callback = function() ui.modals:open("noteskins") end,
		},]]
	}
end
