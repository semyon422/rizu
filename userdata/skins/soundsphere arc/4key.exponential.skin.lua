local NoteSkinVsrg = require("sphere.models.NoteSkinModel.NoteSkinVsrg")
local BasePlayfield = require("sphere.models.NoteSkinModel.BasePlayfield")

local noteskin = NoteSkinVsrg({
	path = ...,
	name = "arc exponential",
	inputMode = "4key",
	range = {-1, 1},
	align = "center",
})

noteskin:setInput({"key1", "key2", "key3", "key4", "measure1"})

noteskin:setTextures({
	{line = "line.png"},
	{left = "left.png"},
	{down = "down.png"},
	{up = "up.png"},
	{right = "right.png"},
})

noteskin:setImages({
	line = {"line"},
	left = {"left"},
	down = {"down"},
	up = {"up"},
	right = {"right"},
})

local exponential = function(timeState)
	return 0.375 ^ (2 * timeState.scaledVisualDeltaTime + 1) * 1080
end

local colors = noteskin.colors
local color = noteskin.color
local Head = {
	x = 0,
	y = 0,
	w = exponential,
	h = exponential,
	ox = 0.5,
	oy = 0.5,
	r = 0,
	color = {color, color, color, color, colors.clear},
	image = {"left", "down", "up", "right", "line"},
}

local ShortNote = {
	Head = Head,
}

local LongNote = {
	Head = Head,
}

noteskin.notes = {
	ShortNote = ShortNote,
	SoundNote = ShortNote,
	LongNote = LongNote,
}

local playfield = BasePlayfield(noteskin)

local tf = {{1 / 2, 0}, {0, 1 / 2}, 0, {0, 1 / 1080}, {0, 1 / 1080}, 0, 0, 0, 0}

playfield:addBga({
	transform = {{1 / 2, -16 / 9 / 2}, {0, -7 / 9 / 2}, 0, {0, 16 / 9}, {0, 16 / 9}, 0, 0, 0, 0},
})
playfield:enableCamera()
playfield:addImageView({
	x = -405 / 2,
	y = -405 / 2,
	w = 405,
	h = 405,
	transform = tf,
	image = "key.png",
})
playfield:addNotes({
	transform = tf,
})
playfield:disableCamera()

playfield:addBaseElements()

return noteskin
