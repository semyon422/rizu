local NoteSkinVsrg = require("sphere.models.NoteSkinModel.NoteSkinVsrg")
local BasePlayfield = require("sphere.models.NoteSkinModel.BasePlayfield")
local JustConfig = require("sphere.JustConfig")
local InputMode = require("chart.core.InputMode")

local octave = {
	{0, 1},
	{1, -1},
	{0, 2},
	{1, 1},
	{0, 3},
	{0, 1},
	{1, -1},
	{0, 4},
	{1, 0},
	{0, 5},
	{1, 1},
	{0, 3}
}

local hitposition = 880

local root = (...):match("(.+)/.-")
local config = JustConfig:fromFile(root .. "/piano.config.lua")

local noteskin = NoteSkinVsrg({
	name = "piano",
	range = {-1, 1},
	unit = 1080,
	hitposition = hitposition,
	config = config
})

local keys_starts = {
	[76] = 5,
	[88] = 10,
}

function noteskin.inputMode(inputMode)
	return true
end

function noteskin:load(inputMode)
	local im = InputMode(inputMode)
	local keys = im:getColumns()

	noteskin:setInput(im:getInputs())

	local start = keys_starts[keys] or 1

	local images = {}
	for i = 0, keys - 1 do
		local key = octave[(start - 1 + i) % 12 + 1]
		table.insert(images, {unpack(key)})
	end

	if images[2][1] == 1 then
		images[1][2] = 6
	else
		images[1][2] = 0
	end

	if images[keys - 1][1] == 1  then
		if images[keys - 3][1] == 1  then
			images[keys][2] = 3
		else
			images[keys][2] = 7
		end
	else
		images[keys][2] = 0
	end

	local w = {}
	local total_width = 0
	for i = 1, #images do
		w[i] = images[i][1] == 0 and 6 or 4
		total_width = total_width + 6 * (images[i][1] == 0 and 6 or 0)
	end

	local x = {}
	local cb = 0
	local cw = 0
	for i = 1, #images do
		local x_i = cw * 6
		if images[i][1] == 0 then
			cw = cw + 1
		elseif images[i][1] == 1 then
			cb = cb + 1
			x_i = x_i - 2 + images[i][2]
		end
		x[i] = x_i
	end

	local scale = config:get("scale")
	for i = 1, #w do
		x[i] = x[i] * 1872 / 312 * scale
		w[i] = w[i] * 1872 / 312 * scale
	end

	noteskin:setColumns({
		offset = 0,
		align = "center",
		width = w,
		position = x,
	})

	local function getKeyName(i)
		if images[i][1] == 1 then
			return "keyBlack.png"
		end
		return string.format("keyWhite%d.png", images[i][2])
	end

	local keysPressed = {}
	local keysReleased = {}
	for i = 1, #w do
		keysPressed[i] = "pressed/" .. getKeyName(i)
		keysReleased[i] = "released/" .. getKeyName(i)
	end

	noteskin:setTextures({
		{measure = ""},
		{body15 = "body15.png"},
		{tail15 = "note15.png"},
		{note15 = "note15.png"},
		{body = "body.png"},
		{tail = "note.png"},
		{note = "note.png"},
	})

	noteskin:setImagesAuto({
		clear = {"note15"},
		dark = {"note", color = {0, 0.5, 1, 1}},
		clear_body = {"body15", color = {0.5, 0.5, 0.5, 1}},
		dark_body = {"body", color = {0, 0.25, 0.5, 1}},
		clear_tail = {"tail15", color = {0.5, 0.5, 0.5, 1}},
		dark_tail = {"tail", color = {0, 0.25, 0.5, 1}},
	})

	local short = {}
	for i, image in ipairs(images) do
		short[i] = image[1] == 0 and "clear" or "dark"
	end
	noteskin:setShortNote({
		image = short,
		h = 24 * scale,
	})

	local head = {}
	local body = {}
	local tail = {}
	for i, image in ipairs(images) do
		head[i] = image[1] == 0 and "clear" or "dark"
		body[i] = image[1] == 0 and "clear_body" or "dark_body"
		tail[i] = image[1] == 0 and "clear_tail" or "dark_tail"
	end
	noteskin:setLongNote({
		head = head,
		body = body,
		tail = tail,
		h = 24 * scale,
	})

	if config:get("measureLine") then
		noteskin:addMeasureLine({
			h = 2,
			color = {0.5, 0.5, 0.5, 1},
			image = "measure"
		})
	end

	local playfield = BasePlayfield(noteskin)

	local tf = playfield:newFullTransform(1920, 1080)
	tf[1] = {1 / 2, 0}

	playfield:enableCamera()

	local colors = {}
	for i = 1, keys do
		local o = (i + start - 1) % 12
		if o == 1 or o == 3 or o == 5 then
			colors[i] = {0.1, 0.1, 0.1, 1}
		elseif o == 6 or o == 8 or o == 10 or o == 0 then
			colors[i] = {0, 0, 0, 1}
		else
			colors[i] = {0, 0, 0, 0}
		end
	end
	playfield:addColumnsBackground({
		color = colors
	})

	playfield:addNotes({
		transform = tf
	})
	playfield:addKeyImages({
		h = 200,
		padding = 0,
		transform = tf,
		released = keysReleased,
		pressed = keysPressed,
	})

	local guidelines = {
		y = {},
		w = {},
		h = {},
		image = {},
	}
	for i = 1, keys + 1 do
		if (i + start - 2) % 12 == 0 then
			guidelines.y[i] = 0
			guidelines.w[i] = 1
			guidelines.h[i] = noteskin.unit
			guidelines.image[i] = "pixel.png"
		end
	end
	playfield:addGuidelines(guidelines)

	playfield:disableCamera()
	if config:get("baseElements") then
		playfield:addBaseElements()
	end
end

return noteskin
