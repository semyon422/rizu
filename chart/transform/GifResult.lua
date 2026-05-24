local class = require("class")
local Format = require("sphere.views.Format")
local gd = require("gd")

-- https://wunkolo.github.io/post/2020/02/buttery-smooth-10fps/
-- https://www.ittner.com.br/lua-gd/manual.html
-- https://github.com/ittner/lua-gd

---@class chart.GifResult
---@operator call: chart.GifResult
local GifResult = class()

local scale = 2
local note_size = 8 * scale
local duration = 5
local speed = 2

local w, h = 192 * scale, 108 * scale

function GifResult:new()
	self.note_index = 1
end

---@param bg_data string
function GifResult:setBackgroundData(bg_data)
	self.bg_data = bg_data
end

function GifResult:drawNotes(im, start_time, offset)
	local notes = self.notes
	local columns = self.columns
	local rate = self.chartplay.rate

	local white = im:colorClosestHWB(255, 255, 255)
	local w, h = im:sizeXY()

	local time = start_time + offset * rate
	while true do
		local note = notes[self.note_index]
		if not note then
			return
		end
		if note.time < time then
			self.note_index = self.note_index + 1
		else
			break
		end
	end

	for i = 1, 100 do
		local note = notes[self.note_index + i - 1]
		if not note or note.time > time + 1 / speed * rate then
			return
		end

		local x = (note.column - 1 - columns / 2) * note_size + w / 2

		local y = h - (note.time - time) * h * speed / rate
		im:filledRectangle(x, y, x + note_size, y - note_size, white)
	end
end

function GifResult:drawScore(im)
	local chartview = self.chartview
	local chartplay = self.chartplay

	local white = im:colorClosestHWB(255, 255, 255)

	local lines = {
		"rating: " .. Format.difficulty(chartplay.rating),
		"",
		"acc:  " .. Format.accuracy(chartplay.accuracy),
		"miss: " .. chartplay.miss_count,
		"",
		"input: " .. Format.inputMode(chartview.chartdiff_inputmode),
		"rate:  " .. ("%0.3fx"):format(chartview.rate),
		"",
		"enps: " .. Format.difficulty(chartview.enps_diff) .. " *",
		"osu:  " .. Format.difficulty(chartview.osu_diff) .. " *",
	}

	for i, line in ipairs(lines) do
		im:string(gd.FONT_LARGE, 0, (i - 1) * 16, line, white)
	end
end

function GifResult:getBackgroundImage()
	local bg = gd.create(w, h)

	local bg_data = self.bg_data
	if not bg_data then
		return bg
	end

	local bg_im = gd.createFromJpegStr(bg_data) or gd.createFromPngStr(bg_data)
	if not bg_im then
		return bg
	end

	local bw, bh = bg_im:sizeXY()

	bg_im:alphaBlending(true)
	bg_im:filledRectangle(0, 0, bw / 2, bh, bg_im:colorResolveAlpha(0, 0, 0, 47))

	local bg_im_256 = bg_im:createPaletteFromTrueColor(true, 240)

	gd.copyResized(bg, bg_im_256, 0, 0, 0, 0, w, h, bw, bh)

	return bg
end

---@param chartview table
---@param chartplay sea.Chartplay
---@return string
function GifResult:create(chartview, chartplay, notes, columns)
	self.chartview = chartview
	self.chartplay = chartplay
	self.notes = notes
	self.columns = columns

	local columns = self.columns

	self.note_index = 1

	local bg_im = self:getBackgroundImage()

	local im = gd.create(w, h)
	im:paletteCopy(bg_im)

	local black = im:colorAllocate(0, 0, 0)
	local white = im:colorAllocate(255, 255, 255)

	---@type string[]
	local out = {}

	table.insert(out, im:gifAnimBeginStr(true, 0))

	local tim_bg = gd.createPalette(w, h)
	tim_bg:paletteCopy(im)
	gd.copy(tim_bg, bg_im, 0, 0, 0, 0, w, h)
	tim_bg:filledRectangle(
		(-columns * note_size + w) / 2,
		0,
		(columns * note_size + w) / 2,
		h,
		black
	)
	self:drawScore(tim_bg)
	table.insert(out, tim_bg:gifAnimAddStr(true, 0, 0, 2, gd.DISPOSAL_NONE, im))

	local start_time = chartview.preview_time or 0

	local prev_im = tim_bg
	for dt = 0, duration * 100, 2 do
		local tim = gd.createPalette(w, h)
		tim:paletteCopy(im)
		gd.copy(tim, tim_bg, 0, 0, 0, 0, w, h)
		self:drawNotes(tim, start_time, dt / 100)
		table.insert(out, tim:gifAnimAddStr(true, 0, 0, 2, gd.DISPOSAL_NONE, prev_im))
		prev_im = tim
	end

	table.insert(out, gd.gifAnimEndStr())

	return table.concat(out)
end

return GifResult
