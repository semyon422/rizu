local Events = require("rizu.api.Events")

---`rizu.api.Media` without files: a flat coloured background per chart and a silent preview clock.
---@class rizu.api.fake.FakeMedia : rizu.api.Events
---@operator call: rizu.api.fake.FakeMedia
local FakeMedia = Events + {}

function FakeMedia:new()
	Events.new(self)
	self.images = {}
	self.time = 0
	self.duration = 0
	self.paused = false
end

---The fake game calls this when another chart is selected.
---@param chart rizu.api.Chart?
function FakeMedia:setChart(chart)
	self.time = 0
	self.duration = chart and chart.duration or 0
	-- Tests run without a window.
	if not chart or not (love and love.image and love.graphics.isActive()) then return end
	local id = chart.chartfile_set_id
	local data = love.image.newImageData(2, 2)
	data:mapPixel(function(x, y)
		local shade = 0.25 + 0.2 * (x + y)
		return shade * (0.4 + id % 3 * 0.3), shade * (0.4 + id % 5 * 0.15), shade * (0.4 + id % 7 * 0.1), 1
	end)
	local image = love.graphics.newImage(data)
	image:setFilter("linear", "linear")
	self.images = {image}
	self:emit("background_changed", image)
end

---@param dt number
function FakeMedia:update(dt)
	if self.duration > 0 and not self.paused then
		self.time = (self.time + dt) % self.duration
	end
end

function FakeMedia:getBackgroundImages() return self.images, 0 end
function FakeMedia:getPreviewTime() return self.time, 0, self.duration end
function FakeMedia:seekPreview(progress) self.time = progress * self.duration end
function FakeMedia:setPreviewTime(time) self.time = math.max(0, time) end
function FakeMedia:getBeat() return self.time * 2 end
function FakeMedia:setSpectrumSize(size) end
function FakeMedia:getSpectrum() return nil end
function FakeMedia:togglePreview() self.paused = not self.paused end
function FakeMedia:drawNotesPreview(width, height) end
function FakeMedia:createNotesPreview(chartview)
	return {isReady = function() return true end, getError = function() end, release = function() end, draw = function() end}
end
function FakeMedia:getBackgroundAnimation() return nil, self.time end

return FakeMedia
