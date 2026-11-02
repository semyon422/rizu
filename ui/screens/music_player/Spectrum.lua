local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")

local lg = love.graphics
local BAR_COUNT = 64
local GAP = 5
-- shortcut: assumes the 44.1 kHz BASS plays at, read the stream rate if previews ever differ.
local SAMPLE_RATE = 44100
-- Log-spaced bars. The top stops at 12 kHz because lossy files are empty above 16 kHz.
local BAND_MIN, BAND_MAX = 40, 12000
local TILT = 3 -- dB per octave
local RANGE = 40 -- dB shown below the ceiling
local RELEASE = 4 -- dB per second the ceiling falls
local MIN_CEILING = -50 -- dB, keeps silence from being amplified

---@class ui.screens.music_player.Spectrum : gui.View
---@operator call: ui.screens.music_player.Spectrum
---@field media rizu.api.Media
---@field levels number[]
---@field bar_count integer
---@field gap number
---@field alpha number
---@field edges number[] bar edges as fractional FFT indexes
---@field db number[]
---@field ceiling number
---@field radius number corner rounding of the bars
---@field color gui.Color
---@field blend_mode love.BlendMode
local Spectrum = View + {}

-- 4096 gives 10.8 Hz bins, enough to tell the bass bars apart.
Spectrum.fft_size = 4096
Spectrum.radius = 3
Spectrum.color = Colors.accent
Spectrum.blend_mode = "alpha"

---@param media rizu.api.Media
---@param bar_count integer?
---@param gap number?
---@param alpha number?
function Spectrum:new(media, bar_count, gap, alpha)
	View.new(self)
	self.media = media
	self.bar_count = bar_count or BAR_COUNT
	self.gap = gap or GAP
	self.alpha = alpha or 1
	self.db = {}
	self.ceiling = MIN_CEILING
	-- fft[n] is the bin at n * bin_hz, so an edge at f Hz sits at index f / bin_hz.
	local bin_hz = SAMPLE_RATE / self.fft_size
	self.edges = {}
	for i = 0, self.bar_count do
		self.edges[i + 1] = BAND_MIN * (BAND_MAX / BAND_MIN) ^ (i / self.bar_count) / bin_hz
	end
	---@type number[]
	self.levels = {}
	for i = 1, self.bar_count do
		self.levels[i] = 0
	end
end

---@param dt number
function Spectrum:update(dt)
	---@type number[]?
	local fft = self.media:getSpectrum()
	local decay = 1 - math.exp(-7 * dt)
	local levels, edges, count = self.levels, self.edges, self.bar_count

	local db, loudest = self.db, -math.huge
	for i = 1, count do
		local first, last = edges[i], edges[i + 1]
		local value = 0
		if fft then
			if last - first < 1 then
				-- A bar narrower than a bin interpolates, so the bass bars do not repeat one bin.
				local at = (first + last) / 2
				local bin = math.floor(at)
				local t = at - bin
				value = fft[bin] * (1 - t) + fft[bin + 1] * t
			else
				for bin = math.floor(first), math.ceil(last) do
					value = math.max(value, fft[bin])
				end
			end
		end
		-- Decibels with a tilt: music loses energy toward the top, so highs would be flat otherwise.
		local center = BAND_MIN * (BAND_MAX / BAND_MIN) ^ ((i - 0.5) / count)
		db[i] = 20 * math.log10(value + 1e-6) + TILT * math.log(center / 1000, 2)
		loudest = math.max(loudest, db[i])
	end

	-- The ceiling follows the loudest bar, so quiet files and lossy ones with a dead top still fill the display.
	if loudest > self.ceiling then
		self.ceiling = loudest
	else
		self.ceiling = math.max(self.ceiling - RELEASE * dt, loudest, MIN_CEILING)
	end
	for i = 1, count do
		-- Squared, so the many mid-level bars stay low and only the real peaks stand out.
		local value = math.min(math.max((db[i] - (self.ceiling - RANGE)) / RANGE, 0), 1) ^ 2
		if value > levels[i] then
			levels[i] = value
		else
			levels[i] = levels[i] + (value - levels[i]) * decay
		end
	end
end

function Spectrum:draw()
	local gap = self.gap
	local bar_width = math.max((self.width - gap * (self.bar_count - 1)) / self.bar_count, 1)
	local color = self.color
	Painter.setColorRgb(color[1], color[2], color[3], self.alpha)
	lg.setBlendMode(self.blend_mode)
	for i = 1, self.bar_count do
		local height = self.levels[i] * self.height
		local x = (i - 1) * (bar_width + gap)
		lg.rectangle("fill", x, self.height - height, bar_width, height, self.radius, self.radius)
	end
	lg.setBlendMode("alpha")
end

return Spectrum
