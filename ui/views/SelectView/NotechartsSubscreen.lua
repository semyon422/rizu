local just = require("just")
local int_rates = require("chart.scoring.int_rates")
local spherefonts = require("sphere.assets.fonts")
local icons = require("sphere.assets.icons")
local gfx_util = require("gfx_util")
local time_util = require("time_util")
local imgui = require("imgui")
local format = require("sea.shared.format")
local RatingCalc = require("sea.leaderboards.RatingCalc")

local BackgroundView = require("sphere.views.BackgroundView")
local ScoreListView = require("ui.views.SelectView.ScoreListView")

local NoteChartSetListView = require("ui.views.SelectView.NoteChartSetListView")
local NoteChartListView = require("ui.views.SelectView.NoteChartListView")
local ModifierIconGridView = require("ui.views.SelectView.ModifierIconGridView")
local BarCellImView = require("ui.imviews.BarCellImView")
local TextCellImView = require("ui.imviews.TextCellImView")
local Format = require("sphere.views.Format")
local RoundedRectangle = require("ui.views.RoundedRectangle")

local Layout = require("ui.views.SelectView.Layout")
local SelectFrame = require("ui.views.SelectView.SelectFrame")

---@param w number
---@param h number
---@param _r number?
local function drawFrameRect(w, h, _r)
	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, 0, w, h, _r or 36)
	love.graphics.setColor(r, g, b, a)
end

---@param w number
---@param h number
---@param _r number?
local function drawFrameRect2(w, h, _r)
	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(0.4, 0.4, 0.4, 0.7)
	RoundedRectangle("fill", 0, 0, w, h, _r or 36)
	love.graphics.setColor(r, g, b, a)
end

---@param self table
local function ScoreList(self)
	local w, h = Layout:move("column1row1")
	drawFrameRect(w, h)

	local w, h = Layout:move("column1row1row1")
	drawFrameRect2(w, h)

	local w, h = Layout:move("column1row1row2")

	ScoreListView.game = self.game
	ScoreListView:draw(w, h)

	love.graphics.translate(w - 16, 0)

	local list = ScoreListView
	local count = list:getItemCount() - 1
	local pos = (list.visualItemIndex - 1) / count
	local newScroll = imgui.ScrollBar("score_sb", pos, 16, h, count / list.rows)
	if newScroll then
		list:scroll(math.floor(count * newScroll + 1) - list.itemIndex)
	end
end

---@param self table
local function NoteChartSetList(self)
	local w, h = Layout:move("column3")
	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, 0, w, h, 36)

	SelectFrame()
	NoteChartSetListView.game = self.game
	NoteChartSetListView:draw(w, h)
	SelectFrame()

	love.graphics.translate(w - 16, 0)

	local list = NoteChartSetListView
	local count = list:getItemCount() - 1
	local pos = (list.visualItemIndex - 1) / count
	local newScroll = imgui.ScrollBar("ncs_sb", pos, 16, h, count / list.rows)
	if newScroll then
		list:scroll(math.floor(count * newScroll + 1) - list.itemIndex)
	end
end

---@param self table
local function NoteChartList(self)
	drawFrameRect(Layout:move("column2row2"))
	drawFrameRect2(Layout:move("column2row2row1"))

	local w, h = Layout:move("column2row2row2")

	love.graphics.setColor(1, 1, 1, 0.8)
	love.graphics.polygon("fill",
		0, 72 * 2.2,
		36 * 0.6, 72 * 2.5,
		0, 72 * 2.8
	)

	NoteChartListView.game = self.game
	NoteChartListView:draw(w, h)

	w, h = Layout:move("column2row2row2")

	h = 60
	local _w = 2.2 * h
	love.graphics.translate(w - (72 - h) / 2 - _w, (72 - h) / 2)

	local config = self.game.configModel.configs.settings.select

	local modes = {"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs", "chartplays"}
	local mode_names = {
		chartfile_sets = "sets",
		chartfiles = "files",
		chartmetas = "charts",
		chartdiffs = "diffs",
		chartplays = "plays",
	}

	local function cycle_mode(current)
		for i, mode in ipairs(modes) do
			if mode == current then
				return modes[i % #modes + 1]
			end
		end
		return modes[1]
	end

	if imgui.TextOnlyButton("primary mode", "P: " .. mode_names[config.primary_mode or "chartfile_sets"], _w / 2, h) then
		config.primary_mode = cycle_mode(config.primary_mode or "chartfile_sets")
		self.game.chartSelector:noDebounceRefresh()
	end
	love.graphics.translate(_w / 2, 0)
	if imgui.TextOnlyButton("secondary mode", "S: " .. mode_names[config.secondary_mode or "chartmetas"], _w / 2, h) then
		config.secondary_mode = cycle_mode(config.secondary_mode or "chartmetas")
		self.game.chartSelector:noDebounceRefresh()
	end
end

---@param self table
local function ChartCells(self)
	local w, h = Layout:move("column2row1")

	local chartview = self.game.chartSelector.chartview

	if not chartview or not chartview.chartdiff_id then
		return
	end

	local baseTimeRate = self.game.replayBase.rate

	local bpm = 0
	local length = 0
	local notes_count = 0
	local level = 0
	local longNoteRatio = 0
	local localOffset = ""
	local format = ""
	if chartview then
		notes_count = chartview.notes_count or 0
		bpm = (chartview.tempo or 0) * baseTimeRate
		length = (chartview.duration or 0) / baseTimeRate
		level = chartview.level or 0
		local long_notes_count = (chartview.judges_count or 0) - notes_count
		longNoteRatio = long_notes_count / notes_count
		localOffset = chartview.chartmeta_local_offset or ""
		format = chartview.format or ""
	end

	love.graphics.translate(0, h - 118)
	w = (w - 44) / 4
	h = 50

	love.graphics.setColor(1, 1, 1, 1)

	just.row(true)
	just.indent(22)
	TextCellImView(w, h, "right", "bpm", math.floor(bpm + 0.5))
	TextCellImView(w, h, "right", "duration", time_util.format(length))
	TextCellImView(w, h, "right", "notes", notes_count)
	TextCellImView(w, h, "right", "level", level)

	just.row(true)
	just.indent(22)
	BarCellImView(2 * w, h, "right", "long notes", longNoteRatio)
	TextCellImView(w, h, "right", "offset", localOffset)
	TextCellImView(w, h, "right", "format", format)
	just.row()

	if self.game.multiplayerModel.client:isInRoom() then
		return
	end

	w, h = Layout:move("column2row1")
	love.graphics.translate(0, h / 2 - 55)
	if imgui.TextOnlyButton("play auto", "AP", 55, 55) then
		self.game.gameplayInteractor.autoplay = true
		self:play()
	end
end

---@param self table
local function ScoreCells(self)
	local w, h = Layout:move("column1row2")
	drawFrameRect(w, h)

	local chartplay = self.game.scoreSelector.chartplay
	if not chartplay then
		return
	end

	local score = 0
	local difficulty = 0
	local accuracy = 0
	local missCount = 0
	local rate = 1
	local const = false
	if chartplay then
		score = chartplay.score or 0
		difficulty = chartplay.difficulty or 0
		accuracy = chartplay.accuracy or 0
		missCount = chartplay.miss_count or 0
		rate = chartplay.rate or 1
		const = chartplay.const or false
		if score ~= score then
			score = 0
		end
	end

	love.graphics.translate(w / 2, 6)
	w = (w - 44) / 4
	h = 50

	just.row(true)
	TextCellImView(w, h, "right", "score", math.floor(score))
	TextCellImView(w, h, "right", "accuracy", Format.accuracy(accuracy))

	just.row(true)
	TextCellImView(w, h, "right", "difficulty", Format.difficulty(difficulty))
	TextCellImView(w, h, "right", "miss count", missCount)

	just.row(true)
	local const_str = ""
	if const then
		const_str = "const"
	end
	TextCellImView(w, h, "right", "", const_str)
	TextCellImView(w, h, "right", "rate", Format.timeRate(rate))
	just.row()
end

local bannerGradient

---@param self table
local function BackgroundBanner(self)
	bannerGradient = bannerGradient or gfx_util.newGradient(
		"vertical",
		{0, 0, 0, 0},
		{0, 0, 0, 1}
	)

	local w, h = Layout:move("column2row1")
	drawFrameRect(w, h)

	just.clip(love.graphics.rectangle, "fill", 0, 0, w, h, 36)
	BackgroundView.game = self.game
	BackgroundView:draw(w, h, 0, 0)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(bannerGradient, 0, 0, 0, w, h)
	just.clip()
end

---@param self table
local function SearchField(self)
	if not just.focused_id then
		just.focus("SearchField")
	end
	local padding = 15
	love.graphics.setFont(spherefonts.get("Noto Sans", 20))

	local w, h = Layout:move("column3", "header")
	love.graphics.translate(0, padding)

	local delAll = love.keyboard.isDown("lctrl") and love.keyboard.isDown("backspace")

	local config = self.game.configModel.configs.select
	local chartSelector = self.game.chartSelector

	local changed, text = imgui.TextInput("SearchField", {config.filterString, "Filter..."}, nil, w / 2, h - padding * 2)
	if changed == "text" then
		if delAll then text = "" end
		config.filterString = text
		chartSelector:debounceRefresh()
	end

	w, h = Layout:move("column3", "header")
	love.graphics.translate(w / 2, padding)

	local changed, text = imgui.TextInput("SearchFieldLamp", {config.lampString, "Lamp..."}, nil, w / 2, h - padding * 2)
	if changed == "text" then
		if delAll then text = "" end
		config.lampString = text
		chartSelector:debounceRefresh()
	end

	w, h = Layout:move("column3", "header")
	love.graphics.translate(w + h / 2, 0)
end

---@param self table
local function SortDropdown(self)
	local w, h = Layout:move("column2", "header")
	love.graphics.translate(w * 2 / 3, 15)

	local sortFunction = self.game.configModel.configs.select.sortFunction
	local sortModel = self.game.chartSelector.sortModel
	local i = imgui.SpoilerList("SortDropdown", w / 3, h - 30, sortModel.names, sortFunction)
	local name = sortModel.names[i]
	if name then
		self.game.chartSelector:setSortFunction(name)
	end
end

---@param f table
---@return string
local function filter_to_string(f)
	return f.name
end

---@param self table
local function NotechartFilterDropdown(self)
	local w, h = Layout:move("column3")

	local size = 1 / 4
	h = 60
	love.graphics.translate(w * (1 - size) - 26, (72 - h) / 2)

	if imgui.TextButton("open filters", "filters", w * size, h) then
		self.gameView:setModal(require("ui.views.SelectView.FiltersView"))
	end
end

---@param self table
local function ScoreFilterDropdown(self)
	local w, h = Layout:move("column1")

	local size = 1 / 4
	h = 60
	love.graphics.translate(w * (1 - size) - 26, (72 - h) / 2)

	local filters = self.game.configModel.configs.filters.score
	local config = self.game.configModel.configs.select
	local i = imgui.SpoilerList("ScoreFilterDropdown", w * size, h, filters, config.scoreFilterName, filter_to_string)
	if i then
		config.scoreFilterName = filters[i].name
		self.game.scoreSelector:pullScore()
	end
end

---@param self table
local function ScoreSourceDropdown(self)
	local w, h = Layout:move("column1")

	local size = 1 / 4
	h = 60
	love.graphics.translate(w * (3 / 4 - size) - 26, (72 - h) / 2)

	local sources = self.game.scoreSelector.store.scoreSources
	local config = self.game.configModel.configs.select
	local i = imgui.SpoilerList("ScoreSourceDropdown", w * size, h, sources, config.scoreSourceName)
	if i then
		config.scoreSourceName = sources[i]
		self.game.scoreSelector:pullScore()
	end
end

---@param self table
local function GroupCheckbox(self)
	local w, h = Layout:move("column2", "header")
	w = w / 3

	love.graphics.translate(w - h / 6, 0)

	local count = self.game.chartSelector.stores[1]:count()

	love.graphics.setFont(spherefonts.get("Noto Sans", 20))

	local text = "charts: " .. count
	gfx_util.printFrame(text, 0, 0, w, h, "right", "center")
	just.next(w, h)
end

---@param self table
local function ModifierIconGrid(self)
	local w, h = Layout:move("column1row3")
	drawFrameRect(w, h)

	local right_w = h * 0.9

	love.graphics.translate(w - 21 - right_w, 4)

	imgui.setSize(right_w, h - 8, right_w / 2, (h - 8) / 2)

	local replayBase = self.game.replayBase

	local timeRateModel = self.game.timeRateModel
	local range = timeRateModel.range[replayBase.rate_type]
	local format = timeRateModel.format[replayBase.rate_type]
	local newRate = int_rates.round(imgui.knob(
		"rate knob",
		timeRateModel:get(),
		range[1], range[2], range[3], 1000,
		format:format(timeRateModel:get())
	))

	if newRate ~= timeRateModel:get() then
		self.game.modifierSelectModel:change()
	end
	timeRateModel:set(newRate)

	local w, h = Layout:move("column1row3")
	love.graphics.translate(w - 21 - right_w, 4)
	love.graphics.translate(8, h - 42)
	local inputMode = self.game.modifierCoordinator.state.inputMode
	local inputmode = Format.inputMode(tostring(inputMode)) or ""
	just.text(inputmode)

	local w, h = Layout:move("column1row3")
	love.graphics.translate(21, 4)

	ModifierIconGridView.game = self.game
	ModifierIconGridView:draw(self.game.replayBase.modifiers, w - 42 - right_w, h, (h - 8) / 2)

	w, h = Layout:move("column1row2")
	love.graphics.translate(21, 4)

	local chartplay = self.game.scoreSelector.chartplay
	if not chartplay then
		return
	end
	local configModifier = chartplay.modifiers or (chartplay.modifierset and chartplay.modifierset.encoded)

	ModifierIconGridView.game = self.game
	ModifierIconGridView:draw(configModifier, w / 2 - 42, h, (h - 8) / 3, true)
end

---@param self table
local function NotechartsSubscreen(self)
	---@type sphere.GameController
	local game = self.game

	local _, h = Layout:move("column1", "footer")
	local w = h * 1.5

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))

	local gameView = game.ui.gameView
	just.row(true)
	if imgui.IconOnlyButton("settings", icons("settings"), h, 0.5) then
		gameView:setModal(require("ui.views.SettingsView"))
	end
	if imgui.IconOnlyButton("mounts", icons("folder_open"), h, 0.5) then
		gameView:setModal(require("ui.views.MountsView"))
	end
	if imgui.IconOnlyButton("packages", icons("apps"), h, 0.5) then
		gameView:setModal(require("ui.views.PackagesView"))
	end
	if imgui.IconOnlyButton("playconfig", icons("more_vert"), h, 0.5) then
		gameView:setModal(require("ui.views.SelectView.PlayConfigView"))
	end
	if imgui.TextOnlyButton("modifiers", "mods", w, h) then
		gameView:setModal(require("ui.views.ModifierView.ModifierView"))
	end
	if imgui.TextOnlyButton("noteskins", "skins", w, h) then
		gameView:setModal(require("ui.views.NoteSkinView"))
	end
	if imgui.TextOnlyButton("input", "input", w, h) then
		gameView:setModal(require("ui.views.InputView"))
	end
	if imgui.TextOnlyButton("multi", "multi", w, h) then
		gameView:setModal(require("ui.views.LobbyView"))
	end
	just.row()

	w, h = Layout:move("column3", "footer")

	just.row(true)
	just.indent(-h)
	if imgui.TextOnlyButton("pause music", "pause", h, h) then
		game.previewModel:stop()
	end
	if imgui.TextOnlyButton("collections", "collections", w, h) then
		self:switchToCollections()
	end
	just.row()

	w, h = Layout:move("column2row2row1")

	local fullWidth = w - 72
	local num_buttons = 5

	local y_offset = 0
	if h * num_buttons > fullWidth then
		y_offset = (h - fullWidth / num_buttons) / 2
		h = fullWidth / num_buttons
	end

	just.emptyline(y_offset)
	just.row(true)
	just.indent(36)
	if imgui.IconOnlyButton("open directory", icons("folder_open"), h, 0.5) then
		game.selectionActions:openDirectory()
	end
	if imgui.IconOnlyButton("update cache", icons("refresh"), h, 0.5) then
		game.selectionActions:updateCache(true)
	end
	just.offset(w - h * 3 - 36)
	if imgui.IconOnlyButton("editor button", icons("create"), h, 0.5) then
		self:edit()
	end
	if imgui.IconOnlyButton("result", icons("info_outline"), h, 0.5) then
		self:result()
	end
	if imgui.IconOnlyButton("play", icons("keyboard_arrow_right"), h, 0.5) then
		self:play()
	end
	just.row()

	w, h = Layout:move("column1row1row1")

	local online_client = game.online_client
	local lb_user = online_client:getLeaderboardUser(1)
	local lb = online_client:getLeaderboard(1)

	if lb_user and lb then
		just.indent(36)
		love.graphics.setFont(spherefonts.get("Noto Sans Mono", 26))

		local label = RatingCalc:postfix(lb.rating_calc)
		local value = format.float4(lb_user.total_rating)

		imgui.Label("rating label", ("#%s %s %s"):format(lb_user.rank, value, label), h)
	end
end

---@param self {game: sphere.GameController}
local function DifftablesSync(self)
	local syncing = self.game.difftables_sync.syncing
	if not syncing then
		return
	end

	local w, h = Layout:move("column1", "column1")
	love.graphics.translate(24, h - 40)

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	imgui.text("Syncing difftables...")
end

return function(self)
	BackgroundBanner(self)
	NoteChartSetList(self)
	NoteChartList(self)
	ScoreList(self)
	ChartCells(self)
	ScoreCells(self)
	SearchField(self)
	SortDropdown(self)
	NotechartFilterDropdown(self)
	ScoreFilterDropdown(self)
	ScoreSourceDropdown(self)
	GroupCheckbox(self)
	ModifierIconGrid(self)
	NotechartsSubscreen(self)
	DifftablesSync(self)
end
