local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")

local lg = love.graphics
local BAR_COUNT = 64

---@class ui.screens.music_player.Spectrum : gui.View
---@operator call: ui.screens.music_player.Spectrum
---@field preview_model rizu.preview.PreviewModel
---@field levels number[]
local Spectrum = View + {}

Spectrum.fft_size = 2048

---@param preview_model rizu.preview.PreviewModel
function Spectrum:new(preview_model)
	View.new(self)
	self.preview_model = preview_model
	---@type number[]
	self.levels = {}
	for i = 1, BAR_COUNT do
		self.levels[i] = 0
	end
end

---@param dt number
function Spectrum:update(dt)
	local fft = self.preview_model:getFFT()
	local decay = 1 - math.exp(-7 * dt)

	for i = 1, BAR_COUNT do
		local value = 0
		if fft then
			-- Quadratic buckets preserve extra low-frequency detail without
			-- assigning the same FFT bin to several neighboring bars.
			local bin_count = self.fft_size / 2 - 1
			local bucket_space = bin_count - BAR_COUNT
			local start_progress = (i - 1) / BAR_COUNT
			local end_progress = i / BAR_COUNT
			local first = i + math.floor(bucket_space * start_progress ^ 2)
			local last = i + math.floor(bucket_space * end_progress ^ 2)
			for bin = first, last do
				value = math.max(value, fft[bin])
			end
			value = math.sqrt(value) * 1.25
		end

		if value > self.levels[i] then
			self.levels[i] = value
		else
			self.levels[i] = self.levels[i] + (value - self.levels[i]) * decay
		end
	end
end

function Spectrum:draw()
	local gap = 5
	local bar_width = math.max((self.width - gap * (BAR_COUNT - 1)) / BAR_COUNT, 1)
	Painter.setColorTable(Colors.accent2)
	for i = 1, BAR_COUNT do
		local height = self.levels[i] * self.height
		local x = (i - 1) * (bar_width + gap)
		lg.rectangle("fill", x, self.height - height, bar_width, height, 3, 3)
	end
end

return Spectrum
