local NoteSkinVsrg = require("sphere.models.NoteSkinModel.NoteSkinVsrg")
local BasePlayfield = require("sphere.models.NoteSkinModel.BasePlayfield")

local noteskin = NoteSkinVsrg({
	path = ...,
	name = "grid",
	inputMode = "4key",
	range = {-0.2, 2},
	align = "center",
})

noteskin:setInput({"key1", "key2", "key3", "key4"})

noteskin:setTextures({
	{note = "note.png"},
})

noteskin:setImages({
	note = {"note"},
})

local exponential = function(timeState)
	return 0.250 ^ (-timeState.scaledVisualDeltaTime + 1) * 1080
end

local count = 2
local size = 270
local half = size * (count - 1) / 2

local nx = {}
local ny = {}
local i = 1
for y = -half, half, size do
	for x = -half, half, size do
		nx[i] = x
		ny[i] = y
		i = i + 1
	end
end

local Head = {
	x = nx,
	y = ny,
	w = exponential,
	h = exponential,
	ox = 0.5,
	oy = 0.5,
	r = 0,
	color = noteskin.color,
	image = "note",
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

noteskin:addBga({
	x = 0,
	y = 0,
	w = 1,
	h = 1,
	color = {0.25, 0.25, 0.25, 1},
})

local playfield = BasePlayfield(noteskin)

local tf = {{1 / 2, 0}, {0, 1 / 2}, 0, {0, 1 / 1080}, {0, 1 / 1080}, 0, 0, 0, 0}

playfield:addBga({
	transform = {{1 / 2, -16 / 9 / 2}, {0, -7 / 9 / 2}, 0, {0, 16 / 9}, {0, 16 / 9}, 0, 0, 0, 0},
})
playfield:enableCamera()
for y = -half, half, size do
	for x = -half, half, size do
		playfield:addImageView({
			x = x - 135,
			y = y - 135,
			w = 270,
			h = 270,
			transform = tf,
			image = "key.png",
		})
	end
end
playfield:addNotes({
	transform = tf,
})
playfield:disableCamera()

playfield:addBaseElements()

return noteskin
