local class = require("class")
local thread = require("thread")
local PlayfieldPreparation = require("rizu.skin.PlayfieldPreparation")
local InputMode = require("chart.core.InputMode")
local NotesPreview = require("rizu.preview.NotesPreview")
local Settings = require("rizu.config.Settings")

---What a playfield's `drawPreview` reads from a player, made from a chartview's `notes_preview`.
---It is not the song select preview's player: it steps through the chart on its own clock.
---@class rizu.video_export.NotesPlayer
---@operator call: rizu.video_export.NotesPlayer
---@field notes rizu.preview.NotesPreview
---@field input_mode string
---@field column_map integer[]
---@field time number Seconds from the start of the audio file.
---@field rate number Scroll speed.
---@field preparation rizu.skin.PlayfieldPreparation?
---@field error string?
---@field released boolean?
local NotesPlayer = class()

---@param notes rizu.preview.NotesPreview
---@param input_mode string
---@param column_map integer[]
---@param rate number
function NotesPlayer:new(notes, input_mode, column_map, rate)
	self.notes = notes
	self.input_mode = input_mode
	self.column_map = column_map
	self.time = 0
	self.rate = rate
end

---Decodes the chartview's `notes_preview`.
---@param chartview table
---@param columns_order integer[]? From the replay base, the order of the columns the player has set.
---@param rate number
---@return rizu.video_export.NotesPlayer?
---@return string? error
function NotesPlayer.fromChartview(chartview, columns_order, rate)
	-- The preview is VSRG-only, native osu!/taiko/catch charts have no data for it.
	if chartview.chartmeta_mode and chartview.chartmeta_mode ~= "mania" then
		return nil, "Only mania charts have a notes preview."
	end
	local input_mode = chartview.chartdiff_inputmode
	if not input_mode then
		return nil, "The chart has no input mode."
	end
	local columns = InputMode(input_mode):getColumns()
	local ok, notes = pcall(NotesPreview, chartview.notes_preview or "", columns)
	if not ok then
		return nil, "The chart's notes preview is invalid."
	end
	local column_map = {}
	for i = 1, columns do
		column_map[columns_order and #columns_order == columns and columns_order[i] or i] = i
	end
	return NotesPlayer(notes, input_mode, column_map, rate)
end

---The scroll speed the song select preview uses at the given audio rate.
---@param settings rizu.config.Config
---@param audio_rate number
---@return number
function NotesPlayer.getRate(settings, audio_rate)
	local keys = Settings.keys.gameplay
	local rate = settings:getNumber(keys.speed)
	if not settings:getBoolean(keys.scale_speed) then
		rate = rate / audio_rate
	end
	return rate
end

---Loads the note skin of the chart's input mode in the background. The player owns it, so it works whether
---or not the song select preview is on. Call `release` when done.
---@param game table
function NotesPlayer:load(game)
	local registry = game.skinRegistry
	local skin = registry and registry:resolve("mania", self.input_mode)
	if not skin then
		self.error = "No skin for " .. self.input_mode
		return
	end
	-- Skin loading waits for a worker thread, which needs a coroutine.
	thread.coro(function()
		local ok, err = xpcall(function()
			local renderer = assert(registry:createRenderer(skin, game, "mania", self.input_mode, "preview"))
			local preparation = PlayfieldPreparation(renderer)
			self.preparation = preparation
			preparation:load(false)
			if self.released then preparation:release() end
		end, debug.traceback)
		if not ok then
			self.error = tostring(err)
			if self.preparation then self.preparation:release() end
		end
	end)()
end

---@return boolean
function NotesPlayer:isReady()
	return self.preparation ~= nil and self.preparation:getPlayfield() ~= nil
end

---@return string?
function NotesPlayer:getError()
	return self.error or self.preparation and self.preparation.error or nil
end

function NotesPlayer:release()
	self.released = true
	if self.preparation then self.preparation:release() end
end

---Draws the notes at `time`. Nothing until `isReady`.
---@param time number Seconds from the start of the audio file.
---@param dt number Seconds since the previous frame.
---@param width number
---@param height number
function NotesPlayer:draw(time, dt, width, height)
	local playfield = self.preparation and self.preparation:getPlayfield()
	if not playfield then return end
	self.time = time
	playfield:update(dt)
	playfield:drawPreview(self, width, height)
end

return NotesPlayer
