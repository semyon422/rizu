local Events = require("rizu.api.Events")

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
local Media = Events + {}

---@param background sphere.BackgroundModel
---@param preview rizu.preview.PreviewModel
function Media:new(background, preview)
	Events.new(self)
	self.background = background
	self.preview = preview
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
	return self.background.images or {}, self.background.alpha or 0
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

---The chart's background animation, for a renderer such as `ui.views.BgaRenderer`.
---@return rizu.preview.BgaPreviewPlayer? player nil when the chart has none
---@return number time
function Media:getBackgroundAnimation()
	return self.preview.bgaPreviewPlayer, self.preview:getTime()
end

return Media
