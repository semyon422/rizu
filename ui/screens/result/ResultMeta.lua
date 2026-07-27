local FlowContainer = require("gui.layout.FlowContainer")
local Resources = require("ui.Resources")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local BMFontLabel = require("ui.views.BMFontLabel")
local Colors = require("ui.Colors")
local Color = require("ui.Color")
local ScoringUtils = require("ui.ScoringUtils")
local Msd = require("ui.Msd")

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
	duration_cell:add(Image(Resources.sprites.icon_clock, nil, Colors.text_muted))
	duration_cell:add(self.duration)
	duration_cell:fitContent()

	local ln_cell = self.chart_meta:add(FlowContainer({direction = "column", align = 0.5, gap = 4}))
	ln_cell:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "LN",
		color = Colors.text_muted
	}))
	ln_cell:add(self.ln_percent)
	ln_cell:setOffset(0, -2) -- Text is a bit larger than icons
	ln_cell:fitContent()

	local tempo_cell = self.chart_meta:add(FlowContainer({direction = "column", align = 0.5, gap = 4}))
	tempo_cell:add(Image(Resources.sprites.icon_metronome, nil, Colors.text_muted))
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
		color = Colors.text_muted
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

local diff_calc = {
	enps_diff = "ENPS",
	osu_diff = "osu!SR",
	msd_diff = "MSD",
	user_diff = "User"
}

---@param chartview rizu.library.LocatedChartview
---@param chartdiff {[string]: any}
---@param rate number
---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@param settings sphere.SettingsConfig
function ResultMeta:bind(chartview, chartdiff, rate, timings, subtimings, settings)
	local duration = (chartview.duration or 0) / rate
	self.duration:setText(("%i:%02i"):format(duration / 60, duration % 60))
	self.ln_percent:setText(("%i%%"):format(chartview.long_notes_ratio or 0))
	self.tempo:setText(("%i"):format(chartview.tempo or 0))
	self.score_system:setText(ScoringUtils.formatScoreSystemName(timings, subtimings))

	local diff = settings.select.diff_column
	local diff_num = chartdiff[diff] or 0
	local diff_color = {1, 1, 1, 1}
	self.difficulty.color = Color.diffToColor(diff, diff_num, diff_color)
	self.difficulty:setText(("%0.01f"):format(diff_num))

	local rate_color = {1, 1, 1, 1}
	self.time_rate.color = Color.linearRateToColor(rate, rate_color)
	self.time_rate:setText(("%0.02fx"):format(rate))

	local msd_diff_data = chartview.msd_diff_data
	local msd_diff_rates = chartview.msd_diff_rates

	if msd_diff_data and msd_diff_rates then
		local msd = Msd(msd_diff_data, msd_diff_rates)
		local first, second = msd:getTopPatterns(rate)
		if second then
			self.patterns:setText(("[%s] %s %s"):format(diff_calc[diff], msd.simplifyName(first), msd.simplifyName(second)))
		else
			self.patterns:setText(("[%s] %s"):format(diff_calc[diff], msd.simplifyName(first)))
		end
	else
		self.patterns:setText(diff_calc[diff])
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
