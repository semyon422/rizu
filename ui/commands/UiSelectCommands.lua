local json = require("web.json")
local PatternStrip = require("ui.screens.song_select_v2.PatternStrip")
local pattern_classifier = require("chart.scoring.pattern_classifier")

local PATTERN_KEYS = {[4] = true, [6] = true, [7] = true, [8] = true, [10] = true, [14] = true}

---The selected chart's notes as JSON for calc/pattern_editor.html, or nil and why not.
---@param chart ui.screens.song_select_v2.PatternStrip.Chart?
---@return string?
---@return string?
local function pattern_chart(chart)
	if not chart then
		return nil, "No chart is selected"
	end
	local ok, notes = pcall(PatternStrip.notes, chart)
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
				local text, err = pattern_chart(ui.api.charts:getSelectedChart() --[[@as ui.screens.song_select_v2.PatternStrip.Chart?]])
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
