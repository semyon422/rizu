local ChartInfo = require("ui.screens.song_select_v2.ChartInfo")
local Resources = require("ui.Resources")

local test = {}
local lg = love.graphics

---@param value string
---@param color gui.Color
---@param dan string?
local function newFormatter(value, color, dan)
	return {
		settings = {subscribeChoice = function() end},
		getDifficulty = function() return {value = value, postfix = "RIZU", color = color, dan = dan} end,
		getMode = function() return "4K" end,
		getDuration = function() return "1:00" end,
		getNoteCount = function() return "100" end,
		getTempo = function() return {avg = "120"} end,
		getLongNoteRatio = function() return {value = "0%"} end,
	}
end

---@param t testing.T
function test.facts_flow_too(t)
	if not lg.isActive() then assert(love.window.setMode(1000, 720)) end
	Resources.load()
	local info = ChartInfo()
	info:setSize(800, ChartInfo.HEIGHT)
	local function cells(notes, duration)
		local formatter = newFormatter("10.0", {1, 1, 1, 1})
		formatter.getNoteCount = function() return notes end
		formatter.getDuration = function() return duration end
		return formatter --[[@as any]]
	end
	info:bind(cells("100", "1:00"))
	info:bind(cells("200", "2:00"))
	local notes, duration = info.cells[3], info.cells[2]
	t:eq(info:getCellText(notes), "00100", "it does not jump")
	info:update(1 / 60)
	local text = info:getCellText(notes)
	t:assert(tonumber(text) > 100 and tonumber(text) < 200 and #text == 5, text)
	t:assert(info:getCellText(duration):match("^01:%d%d$"), info:getCellText(duration))
	t:eq(info:getCellText(info.cells[1]), "4K")
	lg.clear()
	info:draw()
	lg.present()
	for _ = 1, 600 do info:update(1 / 60) end
	t:eq(info:getCellText(notes), "00200")
	t:eq(info:getCellText(duration), "02:00")
	t:eq(info:printTabular("00200"), info:printTabular("11111"), "digits take the same width")
end

---@param t testing.T
function test.number_flows_and_the_badge_stays_put(t)
	if not lg.isActive() then assert(love.window.setMode(1000, 720)) end
	Resources.load()
	local info = ChartInfo()
	info:setSize(800, ChartInfo.HEIGHT)

	info:bind(newFormatter("10.0", {1, 0, 0, 1}, "Beta") --[[@as any]])
	t:eq(info.shown_value, 10, "the first number is shown at once")
	local badge_x = info.dan_badge:getAuthoredWidth() and info.dan_badge.offset_min[1]

	info:bind(newFormatter("30.0", {0, 0, 1, 1}, "Beta") --[[@as any]])
	t:eq(info.shown_value, 10, "it does not jump")
	info:update(1 / 60)
	t:assert(info.shown_value > 10 and info.shown_value < 30, "on its way")
	t:assert(info.shown_color[1] < 1 and info.shown_color[3] > 0, "the color flows too")
	lg.clear()
	info:draw()
	lg.present()
	for _ = 1, 600 do info:update(1 / 60) end
	t:eq(info.shown_value, 30)
	t:tdeq({info.shown_color[1], info.shown_color[3]}, {0, 1})

	t:eq(info.dan_badge.offset_min[1], badge_x, "the badge does not follow the digits")

	info:bind(newFormatter("—", {1, 1, 1, 1}) --[[@as any]])
	t:eq(info.shown_value, nil, "text is shown at once")
	lg.clear()
	info:draw()
	lg.present()
end

return test
