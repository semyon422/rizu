local NoteSkinVsrg = require("sphere.models.NoteSkinModel.NoteSkinVsrg")
local BasePlayfield = require("sphere.models.NoteSkinModel.BasePlayfield")

local noteskin = NoteSkinVsrg({
	path = ...,
	name = "arrow",
	inputMode = "6key",
	range = {-1, 1},
	unit = 480,
	hitposition = 450,
})

noteskin:setInput({"key1", "key2", "key3", "key4", "key5", "key6"})

noteskin:setColumns({
	offset = 0,
	align = "center",
	width = {64, 64, 64, 64, 64, 64},
	space = {32, 0, 0, 0, 0, 0, 32},
})

noteskin:setTextures({
	{pixel = "pixel.png"},
	{body = "note/body.png"},
	{tail_up = "note/tail-up.png"},
	{left = "note/left.png"},
	{down = "note/down.png"},
	{up = "note/up.png"},
	{right = "note/right.png"},
})

noteskin:setImages({
	pixel = {"pixel"},
	body = {"body"},
	tail_up = {"tail_up"},
	left = {"left"},
	down = {"down"},
	up = {"up"},
	right = {"right"},
})

noteskin:setShortNote({
	image = {"left", "left", "down", "up", "right", "right"},
	h = 64,
})

noteskin:setLongNote({
	head = {"left", "left", "down", "up", "right", "right"},
	body = "body",
	tail = "tail_up",
	h = 64,
})

noteskin:addMeasureLine({
	h = 4,
	color = {0.5, 0.5, 0.5, 1},
	image = "pixel",
})

noteskin:addBga({
	x = 0,
	y = 0,
	w = 1,
	h = 1,
	color = {0.25, 0.25, 0.25, 1},
})

local playfield = BasePlayfield(noteskin)

playfield:addBga({
	transform = {{1 / 2, -16 / 9 / 2}, {0, -7 / 9 / 2}, 0, {0, 16 / 9}, {0, 16 / 9}, 0, 0, 0, 0},
})
playfield:enableCamera()
playfield:addNotes()
playfield:addKeyImages({
	h = 64,
	padding = 30,
	pressed = {"key/left1.png", "key/left1.png", "key/down1.png", "key/up1.png", "key/right1.png", "key/right1.png"},
	released = {"key/left0.png", "key/left0.png", "key/down0.png", "key/up0.png", "key/right0.png", "key/right0.png"},
})
playfield:disableCamera()

playfield:addBaseElements()

playfield:addDeltaTimeJudgement({
	x = 0,
	y = 540,
	ox = 0.5,
	oy = 0.5,
	rate = 2,
	transform = playfield:newLaneCenterTransform(1080),
	judgements = {
		-0.12,
		"judgements/-3.png",
		-0.080,
		"judgements/-2.png",
		-0.048,
		"judgements/-1.png",
		-0.016,
		"judgements/0.png",
		0.016,
		"judgements/1.png",
		0.048,
		"judgements/2.png",
		0.080,
		"judgements/3.png",
		0.12,
	},
})

return noteskin
