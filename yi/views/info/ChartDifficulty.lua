local View = require("gui.View")
local Colors = require("yi.Colors")
local Color = require("yi.Color")
local Settings = require("rizu.config.schemas.Settings")
local Msd = require("yi.Msd")
local Painter = require("yi.Painter")

---@class yi.views.info.ChartDifficulty : gui.View
---@operator call: yi.views.info.ChartDifficulty
local ChartDifficulty = View + {}

---@param yi yi.UserInterface
function ChartDifficulty:new(yi)
	View.new(self)
	self.config = yi.game.settings_config
	self.calculator = "MSD"
	self.difficulty = "0.0"
	self.difficulty_color = {1, 1, 1, 1}
	self.patterns = "None"
	self.pattern_count = 1

	local h = Painter.getFontHeight(72) + Painter.getFontHeight(24)
	self:setSize(350, h)
end

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

local diff_column_format = {
	enps_diff = "ENPS",
	osu_diff = "osu!SR",
	msd_diff = "MSD",
	user_diff = "USER"
}

---@param chartview rizu.library.Chartview
---@param rate number
function ChartDifficulty:bind(chartview, rate)
	local p1, p2 = getTopPatterns(chartview.msd_diff_data)

	local difficulty = 0
	local diff_column = self.config:getString(Settings.select.display.diff_column)
	local postfix = ""

	if diff_column == "msd_diff" then
		local msd = Msd(chartview.msd_diff_data, chartview.msd_diff_rates)
		difficulty = msd:getOverall(rate)
		Color.msdToColor(difficulty, self.difficulty_color)
	elseif diff_column == "osu_diff" then
		difficulty = chartview.osu_diff
		Color.osuToColor(difficulty, self.difficulty_color)
		postfix = "★"
	elseif diff_column == "enps_diff" then
		difficulty = chartview.enps_diff
		Color.enpsToColor(difficulty, self.difficulty_color)
	elseif diff_column == "user_diff" then
		difficulty = chartview.user_diff
	end

	self.difficulty = ("%0.1f%s"):format(difficulty, postfix)
	self.calculator = diff_column_format[diff_column] or "UNKNOWN"

	if p2 then
		self.patterns = ("%s\n%s"):format(p1:upper(), p2:upper())
		self.pattern_count = 2
	else
		self.patterns = p1:upper()
		self.pattern_count = 1
	end
end

local lg = love.graphics

function ChartDifficulty:draw()
	local s24 = Painter.getFontHeight(24)
	local s72 = Painter.getFontHeight(72)

	Painter.setFontOutline(0.12)
	Painter.setFontThickness(0.45)
	Painter.setFontOutlineColor(Colors.text_shadow)
	Painter.beginTextDrawing()

	lg.setColor(Colors.text_muted)
	Painter.setFontSize(24)
	Painter.print(self.calculator)

	lg.setColor(self.difficulty_color)
	lg.translate(0, s24)
	Painter.setFontSize(72)
	Painter.print(self.difficulty)

	lg.setColor(Colors.text)
	lg.translate(0, s72 - s24 * self.pattern_count)
	Painter.setFontSize(24)
	Painter.printf(self.patterns, 0, 0, self.width, "right")

	Painter.endTextDrawing()
end

return ChartDifficulty
