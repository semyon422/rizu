local UiSelectCommands = require("ui.commands.UiSelectCommands")
local FakeGameApi = require("rizu.api.fake.FakeGameApi")
local SphPreview = require("chart.format.sph.SphPreview")
local json = require("web.json")

local test = {}

---Runs the copy command with a selected chart, returns the clipboard text and the posted notification kinds.
---@param chart table?
---@return string?
---@return string[]
local function copy(chart)
	local api = FakeGameApi()
	function api.charts:getSelectedChart() return chart end
	local posted = {}
	function api.notifications:post(kind) table.insert(posted, kind) end
	local clipboard ---@type string?
	local set = love.system.setClipboardText
	love.system.setClipboardText = function(text) clipboard = text end ---@diagnostic disable-line: duplicate-set-field
	local ui = {api = api} ---@type table
	for _, command in ipairs(UiSelectCommands({} --[[@as sphere.GameController]], ui --[[@as ui.UserInterface]])) do
		if command.id == "ui.select.copy_pattern_chart" then
			command.callback({})
		end
	end
	love.system.setClipboardText = set
	return clipboard, posted
end

function test.copies_notes(t)
	local preview = SphPreview:encode({{offset = 0, notes = {true, nil, nil, true}}, {offset = 0.5, notes = {nil, true}}}, 1)
	local text, posted = copy({hash = "h", index = 1, title = "T", chartdiff_inputmode = "4key", notes_preview = preview})
	t:tdeq(posted, {"success"})
	local data = json.decode(assert(text))
	t:eq(data.keys, 4)
	t:eq(#data.notes, 3)
	t:tdeq({data.notes[1][1], data.notes[1][2]}, {0, 1})
	t:tdeq({data.notes[3][1], data.notes[3][2]}, {0.5, 2})
end

function test.drops_scratch(t)
	local preview = SphPreview:encode({{offset = 0, notes = {true, nil, nil, nil, nil, nil, nil, true}}, {offset = 0.5, notes = {nil, true}}}, 1)
	local text, posted = copy({hash = "h", index = 1, chartdiff_inputmode = "7key1scratch", notes_preview = preview})
	t:tdeq(posted, {"success"})
	local data = json.decode(assert(text))
	t:eq(data.keys, 7)
	t:eq(#data.notes, 2)
end

function test.copies_wide_keymodes(t)
	local ten = {[1] = true, [10] = true}
	local text, posted = copy({hash = "h", index = 1, chartdiff_inputmode = "10key",
		notes_preview = SphPreview:encode({{offset = 0, notes = ten}, {offset = 1}})})
	t:tdeq(posted, {"success"})
	t:eq(json.decode(assert(text)).keys, 10)

	local fourteen = {[1] = true, [14] = true, [15] = true, [16] = true}
	text, posted = copy({hash = "h", index = 1, chartdiff_inputmode = "14key2scratch",
		notes_preview = SphPreview:encode({{offset = 0, notes = fourteen}, {offset = 1}})})
	t:tdeq(posted, {"success"})
	local data = json.decode(assert(text))
	t:eq(data.keys, 14)
	t:eq(#data.notes, 2)
	t:eq(data.notes[2][2], 14)
end

function test.refuses_what_it_cant_label(t)
	local text, posted = copy(nil)
	t:eq(text, nil)
	t:tdeq(posted, {"error"})
	text, posted = copy({hash = "h", index = 1, chartdiff_inputmode = "4key", notes_preview = "\1\2\3"})
	t:eq(text, nil)
	t:tdeq(posted, {"error"})
end

return test
