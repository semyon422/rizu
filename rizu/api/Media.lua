local NotesPlayer = require("rizu.video_export.NotesPlayer")
local Events = require("rizu.api.Events")

local NO_IMAGES = {}

--[[
What the selected chart looks and sounds like before it is played: its background image, the audio
preview that plays on song select, and the moving preview of its notes.

	local media = ui.api.media
	local images, alpha = media:getBackgroundImages()
	local time, start, finish = media:getPreviewTime()

The game picks all of it from the selected chart; a user interface only shows it.
]]

---@alias rizu.api.Media.Event
---| "background_changed" # A new background image arrived. Arguments: image.

---@class rizu.api.Media : rizu.api.Events
---@operator call: rizu.api.Media
---@field on fun(self: rizu.api.Media, event: rizu.api.Media.Event, f: function): fun()
---@field private background sphere.BackgroundModel
---@field private preview rizu.preview.PreviewModel
---@field private selection rizu.select.SelectionCoordinator
local Media = Events + {}

---@param background sphere.BackgroundModel
---@param preview rizu.preview.PreviewModel
---@param selection rizu.select.SelectionCoordinator
function Media:new(background, preview, selection)
	Events.new(self)
	self.background = background
	self.preview = preview
	self.selection = selection
	background:onChanged(function(event)
		self:emit("background_changed", event.image)
	end)
end

-- Background

---The current background, and while a new one fades in, the new one after it.
---Draw the first image opaque and the second with `alpha`.
---@return love.Image[] images Empty until the first image is ready.
---@return number alpha 0..1
function Media:getBackgroundImages()
	return self.background.images or NO_IMAGES, self.background.alpha or 0
end

-- Audio preview

---@return number time Seconds from the start of the audio file.
---@return number start Where the audio begins.
---@return number finish Where it ends. Equal to start while nothing is loaded.
function Media:getPreviewTime()
	local start, finish = self.preview:getRange()
	return self.preview:getTime(), start, finish
end

---@param progress number 0 is the start of the audio, 1 its end.
function Media:seekPreview(progress) self.preview:setRelativePosition(progress) end

---@param time number Seconds from the start of the audio file.
function Media:setPreviewTime(time) self.preview:setPosition(time) end

---Starts the audio, video and notes previews of the selected chart, which then follow the selection.
---Nothing starts them but this: call it on the screens that want them, again after a play, which stops them.
---Does nothing while they play.
function Media:startPreview() self.selection:startPreview() end

---Stops the previews until startPreview().
function Media:stopPreview() self.preview:stop() end

---@return boolean
function Media:isPreviewActive() return self.preview.active end

---How the audio preview plays from the next chart on. Song select uses "chart", "loop", the default;
---a music player "start", "random_chart".
---@param start_mode rizu.preview.StartMode
---@param end_action rizu.preview.EndAction
function Media:setPreviewModes(start_mode, end_action) self.preview:setModes(start_mode, end_action) end

---Pauses the audio preview, or resumes it.
function Media:togglePreview() self.preview:togglePause() end

---@return boolean
function Media:isPaused() return self.preview.paused end

---Which beat of the chart the audio preview is at, for something that pulses with the music.
---@return number? beat nil when the chart has no tempo data or nothing is loaded
function Media:getBeat()
	local notes = self.preview.chartPreview.notes
	if notes and notes.timing_vertices then
		return notes:getBeatAtTime(self.preview:getTime())
	end
end

---Ask for the size first, once. The spectrum of what the audio preview plays right now.
---@param size integer A power of two. 2048 gives 1023 values.
function Media:setSpectrumSize(size) self.preview:setFFTSize(size) end

---@return ffi.cdata*? magnitudes Indexed from 1, low frequencies first, 0..1 and above. nil while nothing plays.
function Media:getSpectrum() return self.preview:getFFT() end

-- Moving previews. Both follow the audio preview.

---Draws the chart's notes scrolling on the current note skin, into a width x height area at the origin.
---Draws nothing while the skin or the chart is loading.
---@param width number
---@param height number
function Media:drawNotesPreview(width, height)
	local playfield = self.preview:getPlayfield()
	if playfield then
		playfield:drawPreview(self.preview.chartPreview, width, height)
	end
end

---A notes preview of a chart with its own clock and its own note skin, for a video export that steps through
---the chart. It works with the chart preview in song select turned off. The skin loads in the background:
---wait for `isReady`, draw with `draw(time, dt, width, height)` and `release` it when done.
---@param chartview table The chart's chartview, e.g. from `Charts:getSelectedChart`.
---@return rizu.video_export.NotesPlayer? preview
---@return string? error Why the chart has no notes preview.
function Media:createNotesPreview(chartview)
	local preview = self.preview
	local player, err = NotesPlayer.fromChartview(
		chartview,
		preview.configurator.columns_order,
		NotesPlayer.getRate(preview.settings, preview.rate)
	)
	if player then
		player:load(preview.game)
	end
	return player, err
end

---The chart's background animation, for a renderer such as `ui.views.BgaRenderer`.
---@return rizu.preview.BgaPreviewPlayer? player nil when the chart has none
---@return number time
function Media:getBackgroundAnimation()
	return self.preview.bgaPreviewPlayer, self.preview:getTime()
end

return Media
