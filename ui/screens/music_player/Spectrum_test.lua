local Spectrum = require("ui.screens.music_player.Spectrum")

local test = {}

---A spectrum with one loud bin at `hz`, the bins around it quiet.
---@param hz number
---@return ui.screens.music_player.Spectrum
local function spectrumAt(hz)
	---@type number[]
	local bins = {}
	for i = 0, Spectrum.fft_size / 2 do
		bins[i] = 0.0001
	end
	bins[math.floor(hz / (44100 / Spectrum.fft_size) + 0.5)] = 0.5
	local media = {getSpectrum = function() return bins end} ---@type any
	local spectrum = Spectrum(media, 48)
	for _ = 1, 10 do
		spectrum:update(0.016)
	end
	return spectrum
end

---@param spectrum ui.screens.music_player.Spectrum
---@return integer
local function loudestBar(spectrum)
	local best = 1
	for i, level in ipairs(spectrum.levels) do
		if level > spectrum.levels[best] then best = i end
	end
	return best
end

---@param t testing.T
function test.bars_are_log_spaced(t)
	local low, mid, high = loudestBar(spectrumAt(60)), loudestBar(spectrumAt(1000)), loudestBar(spectrumAt(9000))
	t:assert(low < mid and mid < high)
	-- 1 kHz is about 60% up a 40 Hz to 12 kHz log axis.
	t:assert(mid > 24 and mid < 33)
end

---@param t testing.T
function test.quiet_highs_still_fill_the_bar(t)
	local spectrum = spectrumAt(9000)
	t:assert(spectrum.levels[loudestBar(spectrum)] > 0.9)
end

---@param t testing.T
function test.silence_shows_nothing(t)
	local spectrum = Spectrum({getSpectrum = function() return nil end}, 48)
	spectrum:update(0.016)
	t:eq(spectrum.levels[1], 0)
end

return test
