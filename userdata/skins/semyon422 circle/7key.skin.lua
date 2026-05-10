local NoteSkinVsrg = require("sphere.models.NoteSkinModel.NoteSkinVsrg")
local JustConfig = require("sphere.JustConfig")
local ColorSnap = require("sphere.ColorSnap")

local root = (...):match("(.+)/.-")
local config = JustConfig:fromFile(root .. "/7key.config.lua")
local create_playfield = dofile(root .. "/create_playfield.lua")
local chords = dofile(root .. "/chords.lua")

local noteskin = NoteSkinVsrg({
	name = "semyon422 circle",
	inputMode = "7key",
	range = {-1, 1},
	unit = 480,
	hitposition = config:get("hitposition"),
	config = config,
})

noteskin:setInput({
	"key1",
	"key2",
	"key3",
	"key4",
	"key5",
	"key6",
	"key7",
})

local cs = config:get("columnSize")
noteskin:setColumns({
	offset = 0,
	align = "center",
	width = {cs, cs, cs, cs, cs, cs, cs},
	space = {cs, 0, 0, 0, 0, 0, 0, cs},
	upscroll = config:get("upscroll"),
})

noteskin:setTextures({
	{line = "measureline/line9.png"},

	{body_00 = "note/body-00.png"},
	{body_03 = "note/body-03.png"},
	{body_30 = "note/body-30.png"},
	{body_33 = "note/body-33.png"},

	{tail_00 = "note/tail-00.png"},
	{tail_03 = "note/tail-03.png"},
	{tail_30 = "note/tail-30.png"},
	{tail_33 = "note/tail-33.png"},

	{head_00 = "note/head-00.png"},
	{head_01 = "note/head-01.png"},
	{head_02 = "note/head-02.png"},

	{head_10 = "note/head-10.png"},
	{head_11 = "note/head-11.png"},
	{head_12 = "note/head-12.png"},

	{head_20 = "note/head-20.png"},
	{head_21 = "note/head-21.png"},
	{head_22 = "note/head-22.png"},

	{note_00 = "note/note-00.png"},
	{note_01 = "note/note-01.png"},
	{note_02 = "note/note-02.png"},

	{note_10 = "note/note-10.png"},
	{note_11 = "note/note-11.png"},
	{note_12 = "note/note-12.png"},

	{note_20 = "note/note-20.png"},
	{note_21 = "note/note-21.png"},
	{note_22 = "note/note-22.png"},
})

local green = {0.25, 1, 0.5, 1}
noteskin:setImagesAuto({
	head_green_00 = {"head_00", color = green},
	head_green_01 = {"head_01", color = green},
	head_green_02 = {"head_02", color = green},
	head_green_10 = {"head_10", color = green},
	head_green_11 = {"head_11", color = green},
	head_green_12 = {"head_12", color = green},
	head_green_20 = {"head_20", color = green},
	head_green_21 = {"head_21", color = green},
	head_green_22 = {"head_22", color = green},
	note_green_00 = {"note_00", color = green},
	note_green_01 = {"note_01", color = green},
	note_green_02 = {"note_02", color = green},
	note_green_10 = {"note_10", color = green},
	note_green_11 = {"note_11", color = green},
	note_green_12 = {"note_12", color = green},
	note_green_20 = {"note_20", color = green},
	note_green_21 = {"note_21", color = green},
	note_green_22 = {"note_22", color = green},
})

local columnsCount = noteskin.columnsCount

local bufferChord = {}
local function mirrorChord(c)
	for i = 1, columnsCount do
		bufferChord[i] = c[columnsCount - i + 1]
	end
	return bufferChord
end
local function mirrorColumn(column)
	return columnsCount - column + 1
end

local colorMap = {
	[0] = "_green",
	[1] = "",
}
local columnColor = {1, 0, 1, 0, 1, 0, 1}

local is_colorsnap = config:get("colorsnap")

local function getColor(c, column)
	if is_colorsnap then
		return ""
	end
	local l, _, r = c[column - 1], c[column], c[column + 1]
	if not l and not r then
		return colorMap[columnColor[column]]
	end

	if columnsCount % 2 == 1 and column == math.ceil(columnsCount / 2) then
		if r then
			return getColor(c, column + 1)
		end
		return getColor(c, column - 1)
	end

	if column > columnsCount / 2 then
		c = mirrorChord(c)
		column = mirrorColumn(column)
		l, _, r = c[column - 1], c[column], c[column + 1]
	end

	if not c[1] and c[2] and c[3] and c[4] and not c[5] then
		return "_green"
	end
	if not c[1] and c[2] and c[3] and c[4] and c[5] and c[6] and not c[7] then
		return "_green"
	end

	return ""
end

local colorSnap = ColorSnap()
local function color(timeState, noteView, column)
	local orig_color = noteskin.color(timeState, noteView, column)
	if not is_colorsnap then
		return orig_color
	end
	local my_color = colorSnap:getColor(noteView.graphicalNote.linked_note.startNote:getBeatModulo())
	return noteskin:multiplyColors(my_color, orig_color)
end

if config:get("mines") then
	noteskin:setShortNote({
		image = function(_, noteView, column)
			return "note" .. getColor(chords.get_start_chord(noteView), column) .. chords.get_suffix(chords.get_start_chord(noteView), column)
		end,
		h = cs,
		color = {1, 0.25, 0.25, 1},
	}, "SoundNote")
end

noteskin:setShortNote({
	image = function(_, noteView, column)
		return "note" .. getColor(chords.get_start_chord(noteView), column) .. chords.get_suffix(chords.get_start_chord(noteView), column)
	end,
	h = cs,
	color = color,
})

noteskin:setLongNote({
	head = function(_, noteView, column)
		return "head" .. getColor(chords.get_start_chord(noteView), column) .. chords.get_suffix(chords.get_start_chord(noteView), column)
	end,
	body = function(_, noteView, column)
		return "body" .. chords.get_suffix(chords.get_middle_chord(noteView), column)
	end,
	tail = function(_, noteView, column)
		return "tail" .. chords.get_suffix(chords.get_middle_chord(noteView), column)
	end,
	h = cs,
	color = color,
})

if config:get("measureLine") then
	noteskin:addMeasureLine({
		h = cs,
		color = {1, 1, 1, 0.12},
		image = "line",
	})
end

noteskin:addBga({
	x = 0,
	y = 0,
	w = 1,
	h = 1,
	color = {0.25, 0.25, 0.25, 1},
})

local playfield = create_playfield(noteskin, {lanes = true})

return noteskin
