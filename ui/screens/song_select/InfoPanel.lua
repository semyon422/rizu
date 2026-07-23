local View = require("gui.View")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Color = require("ui.Color")
local Painter = require("ui.Painter")

---@class ui.screens.song_select.InfoPanel : gui.View
---@operator call: ui.screens.song_select.InfoPanel
---@field text_batch24 love.Text
local InfoPanel = View + {}

function InfoPanel:new()
	View.new(self)
	self.text_batch24 = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.font64 = Resources.getFont("regular", 64)
	self.ln_color = {1, 1, 1, 1}
	self.difficulty = "0.00"
	self.difficulty_color = {1, 1, 1, 1}
	self.height = 122
end

function InfoPanel:load() end

---@param data {[string]: number}
---@return string
---@return string?
local function getTopPatterns(data)
	local max_v = -math.huge
	local max_k ---@type string

	for k, v in pairs(data) do
		if k ~= "overall" then
			if v > max_v then
				max_v = v
				max_k = k
			end
		end
	end

	local second_v = -math.huge
	local second_k ---@type string?

	for k, v in pairs(data) do
		if k ~= "overall" and k ~= max_k then
			if v > max_v * 0.93 and v > second_v then
				second_v = v
				second_k = k
			end
		end
	end

	return max_k, second_k
end

local cs = {{1, 1, 1, 1}, ""}

local pattern_alias_4k = {
	stream = "STREAM",
	jumpstream = "JS",
	handstream = "HS",
	stamina = "STAMINA",
	jackspeed = "JACK",
	chordjack = "CJ",
	technical = "TECH"
}

---@param chartview rizu.library.LocatedChartview
function InfoPanel:bind(chartview)
	self.text_batch24:clear()

	local tb24 = self.text_batch24
	local dur = chartview.duration or 0
	local minutes = dur / 60
	local seconds = dur % 60

	cs[1] = Colors.text
	cs[2] = ("%i:%02i"):format(minutes, seconds)
	tb24:add(cs, 355, 13)

	local tempo = chartview.tempo or 0
	local tempo_max = chartview.tempo_max
	local tempo_min = chartview.tempo_min

	if tempo_min and tempo_max then
		cs[2] = ("%i (%i - %i)"):format(tempo, tempo_min, tempo_max)
		tb24:add(cs, 355, 48)
	else
		cs[2] = ("%i"):format(tempo)
		tb24:add(cs, 355, 48)
	end

	cs[1] = Colors.text_muted
	cs[2] = "LN"
	tb24:add(cs, 304, 84)

	local ln_percent = chartview.long_notes_ratio or 0
	cs[1] = Color.lnPercentToColor(ln_percent, self.ln_color)
	cs[2] = ("%i%%"):format(ln_percent * 100)
	tb24:add(cs, 355, 84)

	local p1, p2 = getTopPatterns(chartview.msd_diff_data)

	cs[1] = Colors.text

	if p2 then
		cs[2] = ("%s %s"):format(pattern_alias_4k[p1] or "None", pattern_alias_4k[p2] or "None")
	else
		cs[2] = pattern_alias_4k[p1]
	end

	tb24:add(cs, 12, 84)

	local diff = chartview.enps_diff or 0
	self.difficulty = ("%0.2f"):format(diff)
	self.difficulty_color = Color.enpsToColor(diff, self.difficulty_color)
end

function InfoPanel:draw()
	love.graphics.setColor(Colors.panel)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, 0, 0, self.width, self.height)
	Painter.snapToPixel()
	love.graphics.setColor(Colors.text_muted)
	love.graphics.draw(Resources.atlas, Resources.quads.icon_clock, 308, 15)
	love.graphics.draw(Resources.atlas, Resources.quads.icon_metronome, 308, 50)
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(self.text_batch24)
	love.graphics.setFont(self.font64)
	love.graphics.setColor(self.difficulty_color)
	love.graphics.print(self.difficulty, 12, 8)
end

return InfoPanel
