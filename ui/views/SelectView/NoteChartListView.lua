local ListView = require("sphere.views.ListView")
local just = require("just")
local TextCellImView = require("ui.imviews.TextCellImView")
local Format = require("sphere.views.Format")
local math_util = require("math_util")

local NoteChartListView = ListView()

NoteChartListView.rows = 5

function NoteChartListView:reloadItems()
	local chartStore = self.game.chartSelector.stores[2]
	if not self.isSubscribed then
		chartStore:onChanged(self)
		self.isSubscribed = true
		self.items = chartStore
		self.refreshNeeded = true
	end

	if self.refreshNeeded then
		self.stateCounter = (self.stateCounter or 0) + 1
		self.refreshNeeded = false
	end
end

function NoteChartListView:receive()
	self.refreshNeeded = true
end

---@return number
function NoteChartListView:getItemIndex()
	return self.game.chartSelector.state.levels[2].index
end

---@param count number
function NoteChartListView:scroll(count)
	self.game.chartSelector:scrollLevel(2, count)
end

---@param ... any?
function NoteChartListView:draw(...)
	ListView.draw(self, ...)

	if just.keypressed("up") then self:scroll(-1)
	elseif just.keypressed("down") then self:scroll(1)
	end
end

local pattern_short_name = {
	stream = "ST",
	jumpstream = "JS",
	handstream = "HS",
	jackspeed = "JK",
	chordjack = "CJ",
	technical = "TH"
}

local msd_min_rate = 7
local msd_max_rate = 20

---@param rate_multipliers number[]
---@param time_rate number
---@return number
local function approximateRateMultiplier(rate_multipliers, time_rate)
	local floor = math_util.clamp(math.floor(time_rate * 10), msd_min_rate, msd_max_rate) - msd_min_rate + 1
	local ceil = math_util.clamp(math.ceil(time_rate * 10), msd_min_rate, msd_max_rate) - msd_min_rate + 1

	if floor == ceil then
		return rate_multipliers[floor]
	end

	local lower = rate_multipliers[floor]
	local upper = rate_multipliers[ceil]

	return (lower + upper) / 2
end

---@param item table
---@param diff_column string
---@param time_rate number
---@return string
local function formatDifficulty(item, diff_column, time_rate)
	if not item.difficulty then
		return ""
	end

	if diff_column ~= "msd_diff" then
		return Format.difficulty(item.difficulty * time_rate) or ""
	end

	if not item.msd_diff_data or not item.msd_diff_rates then
		return ""
	end

	local max_diff = -math.huge
	local pattern = ""

	for p, diff in pairs(item.msd_diff_data) do
		if diff > max_diff and p ~= "stamina" and p ~= "overall" then
			pattern = p
			max_diff = diff
		end
	end

	local rate_multiplier = approximateRateMultiplier(item.msd_diff_rates, time_rate)
	local f = Format.difficulty(item.difficulty * rate_multiplier) or ""
	return ("%s %s"):format(f, pattern_short_name[pattern])
end

---@param i number
---@param w number
---@param h number
function NoteChartListView:drawItem(i, w, h)
	local item = self:get(i)

	if item.difftable_chartmetas and #item.difftable_chartmetas > 0 then
		love.graphics.circle("line", w - 22 * 2, 36, 5, 16)
	end

	just.indent(18)

	local baseTimeRate = self.game.replayBase.rate

	local select = self.game.configModel.configs.settings.select

	local secondary_mode = select.secondary_mode or "chartmetas"
	if secondary_mode == "chartdiffs" or secondary_mode == "chartplays" then
		baseTimeRate = 1
	end

	local difficulty = formatDifficulty(item, select.diff_column, baseTimeRate)
	local left_cell_width = select.diff_column == "msd_diff" and 110 or 72

	local inputmode = item.chartdiff_inputmode and Format.inputMode(item.chartdiff_inputmode) or ""
	local creator = item.creator or ""
	local name = item.name or item.chartfile_name

	local prevItem = self:get(i - 1)
	if prevItem and prevItem.chartdiff_inputmode == item.chartdiff_inputmode then
		inputmode = ""
	end
	if prevItem and prevItem.creator == item.creator then
		creator = ""
	end

	love.graphics.setColor(1, 1, 1, 1)

	TextCellImView(left_cell_width, h, "right", inputmode, difficulty, true)
	just.sameline()

	if item.lamp then
		love.graphics.circle("fill", 22, 36, 7)
		love.graphics.circle("line", 22, 36, 7)
	end
	just.indent(44)

	if not item.chartmeta_id then
		love.graphics.setColor(1, 1, 1, 0.5)
	end
	TextCellImView(math.huge, h, "left", creator, name)
end

return NoteChartListView
