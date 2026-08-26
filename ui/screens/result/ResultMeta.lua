local FlowContainer = require("gui.layout.FlowContainer")
local Resources = require("ui.Resources")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local BMFontLabel = require("ui.views.BMFontLabel")
local Colors = require("ui.Colors")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local ChartdiffFormatter = require("ui.formatters.ChartdiffFormatter")

---@class ui.screens.result.ResultMeta : gui.layout.FlowContainer
---@operator call: ui.screens.result.ResultMeta
local ResultMeta = FlowContainer + {}

function ResultMeta:new()
	FlowContainer.new(self, {
		direction = "column",
		align = 0.5,
		gap = 20,
	})

	self.duration = Label({
		font_name = "regular",
		font_size = 36,
		text = "0:00",
		color = Colors.text
	})
	self.ln_percent = Label({
		font_name = "regular",
		font_size = 36,
		text = "0%",
		color = Colors.text
	})
	self.tempo = Label({
		font_name = "regular",
		font_size = 36,
		text = "0",
		color = Colors.text
	})

	self.chart_meta = self:add(FlowContainer({direction = "row", gap = 30, align = 0.5}))
	local duration_cell = self.chart_meta:add(FlowContainer({direction = "column", align = 0.5, gap = 4}))
	duration_cell:add(Image(Resources.sprites.icon_clock, nil, Colors.muted))
	duration_cell:add(self.duration)
	duration_cell:fitContent()

	local ln_cell = self.chart_meta:add(FlowContainer({direction = "column", align = 0.5, gap = 4}))
	ln_cell:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "LN",
		color = Colors.muted
	}))
	ln_cell:add(self.ln_percent)
	ln_cell:setOffset(0, -2) -- Text is a bit larger than icons
	ln_cell:fitContent()

	local tempo_cell = self.chart_meta:add(FlowContainer({direction = "column", align = 0.5, gap = 4}))
	tempo_cell:add(Image(Resources.sprites.icon_metronome, nil, Colors.muted))
	tempo_cell:add(self.tempo)
	tempo_cell:fitContent()
	self.chart_meta:fitContent()

	self.play_meta = self:add(FlowContainer({direction = "row", gap = 10, align = 0.5}))
	self.time_rate = self.play_meta:add(BMFontLabel({
		font_name = "outline_regular",
		font_size = 36,
		text = "1.00x",
	}))
	self.difficulty = self.play_meta:add(BMFontLabel({
		font_name = "outline_regular",
		font_size = 64,
		text = "0.0",
	}))
	self.play_meta:fitContent()

	self.patterns = Label({
		font_name = "regular",
		font_size = 24,
		text = "ENPS",
	})
	self.score_system = Label({
		font_name = "regular",
		font_size = 24,
		text = "Rizu",
		color = Colors.muted
	})
	self.score_meta = self:add(FlowContainer({
		direction = "column",
		align = 0.5,
		gap = 0,
		self.patterns,
		self.score_system,
	}))
	self.score_meta:fitContent()
	self:fitContent()
end

---@param cvf ui.formatters.ChartviewFormatter
---@param cdf ui.formatters.ChartdiffFormatter
---@param ssf ui.formatters.ScoreSystemFormatter
function ResultMeta:bind(cvf, cdf, ssf)
	self.duration:setText(cvf:getDuration())
	self.tempo:setText(cvf:getTempo().avg)
	self.score_system:setText(ssf:getName())

	local ln = cvf:getLongNoteRatio() -- TODO: check if chartdiff has long_note_ratio. We should use it instead.
	self.ln_percent.color = ln.color
	self.ln_percent:setText(ln.value)

	local diff = cdf:getDifficulty()
	self.difficulty.color = diff.color
	self.difficulty:setText(diff.value)

	local rate = cvf:getTimeRate()
	self.time_rate.color = rate.color
	self.time_rate:setText(rate.value)

	local patterns = cvf:getPatterns()
	local top = patterns.top_simple
	local second = patterns.second_simple

	if top and second then
		self.patterns:setText(("%s %s"):format(top, second))
	elseif top then
		self.patterns:setText(top)
	else
		self.patterns:setText("None")
	end

	for _, cell in ipairs(self.chart_meta.children) do
		---@cast cell gui.layout.FlowContainer
		cell:fitContent()
	end

	self.chart_meta:fitContent()
	self.play_meta:fitContent()
	self.score_meta:fitContent()
	self:fitContent()
end

return ResultMeta
