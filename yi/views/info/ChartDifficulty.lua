local View = require("gui.View")
local Colors = require("yi.Colors")
local Color = require("yi.Color")
local Settings = require("rizu.config.schemas.Settings")

---@class yi.views.info.ChartDifficulty : gui.View
---@operator call: yi.views.info.ChartDifficulty
local ChartDifficulty = View + {}

---@param yi yi.UserInterface
function ChartDifficulty:new(yi)
	View.new(self)
	local resources = yi.resources
	self.config = yi.game.settings_config
	self.calc_font = resources:getFont("bold", 24)
	self.diff_font = resources:getFont("bold", 72)
	self.patterns_font = resources:getFont("bold", 24)

	self.calculator = "MSD"
	self.difficulty = "0.0"
	self.difficulty_color = {1, 1, 1, 1}
	self.patterns = "None"
	self.pattern_count = 1

	local h = self.calc_font:getHeight() + self.diff_font:getHeight()
	self:setSize(350, h)

	self.diff_y = self.calc_font:getHeight()
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
function ChartDifficulty:bind(chartview)
	local p1, p2 = getTopPatterns(chartview.msd_diff_data)

	local hue = 0
	local difficulty = 0
	local diff_column = self.config:getString(Settings.select.display.diff_column)
	local postfix = ""

	if diff_column == "msd_diff" then
		difficulty = chartview.msd_diff
		hue = Color.convertDiffToHue((math.min(difficulty, 40) / 40) / 1.3)
	elseif diff_column == "osu_diff" then
		difficulty = chartview.osu_diff
		hue = Color.convertDiffToHue((math.min(difficulty, 10) / 10))
		postfix = "★"
	elseif diff_column == "enps_diff" then
		difficulty = chartview.enps_diff
		hue = Color.convertDiffToHue((math.min(difficulty, 30) / 30))
	elseif diff_column == "user_diff" then
		difficulty = chartview.user_diff
		hue = 0
	end

	self.difficulty = ("%0.1f%s"):format(difficulty, postfix)
	Color.HSV(hue, 1, 1, self.difficulty_color)
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
	lg.setFont(self.calc_font)
	lg.setColor(Colors.text_muted)
	lg.print(self.calculator)

	lg.setColor(self.difficulty_color)
	lg.setFont(self.diff_font)
	lg.print(self.difficulty, 0, self.diff_y)

	lg.setFont(self.patterns_font)
	lg.setColor(Colors.text)
	local h = self.patterns_font:getHeight() * self.pattern_count
	local y = (self.diff_font:getHeight() - h) / 2
	lg.printf(self.patterns, 0, y + self.diff_y, self.width, "right")
end

return ChartDifficulty
