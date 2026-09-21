local class = require("class")
local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local InputMode = require("chart.core.InputMode")

local lg = love.graphics

local note_colors = {
	white = {1, 1, 1},
	pink = {0.2, 0.75, 0.9},
	yellow = {1, 0.87, 0.24},
	green = {0.3, 0.85, 0.35},
}

local predefined_colors = {
	{"yellow"},
	{"white", "pink"},
	{"white", "pink", "white"},
	{"white", "pink", "pink", "white"},
	{"white", "pink", "yellow", "pink", "white"},
	{},
	{"white", "pink", "white", "yellow", "white", "pink", "white"},
}

---@param columns integer
---@return string[]
local function get_note_color_names(columns)
	local symmetric = columns % 2 == 0
	local structure
	if columns < 5 then
		structure = (columns - 1) % 4 + 1
	elseif columns % 5 == 0 then
		structure = 5
	elseif columns % 6 == 0 then
		structure = 3
	elseif columns % 7 == 0 then
		structure = 7
	else
		structure = symmetric and 4 or 3
	end

	local colors = {}
	for _ = 1, columns / structure do
		for _, color in ipairs(predefined_colors[structure]) do
			table.insert(colors, color)
		end
	end
	if not symmetric then
		colors[math.ceil(columns / 2)] = "yellow"
	end
	if #colors ~= columns then
		for column = 1, columns do
			colors[column] = column % 2 == 0 and "white" or "pink"
		end
	end
	return colors
end

---@class rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer : rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer
local ManiaPlayfieldRenderer = PlayfieldRenderer + {}

---@param game sphere.GameController
---@param input_mode string
function ManiaPlayfieldRenderer:new(game, input_mode)
	PlayfieldRenderer.new(self, game)
	self.inputs = InputMode(input_mode):getInputs()
end

---@param player rizu.preview.NotesPreviewPlayer
---@param width number
---@param height number
function ManiaPlayfieldRenderer:drawPreview(player, width, height)
	local preview = player.notes
	if not preview then
		return
	end

	local columns = #preview.columns
	local key_columns = 0
	for column = 1, columns do
		local input = self.inputs and self.inputs[column] or ""
		if input:find("key") then
			key_columns = key_columns + 1
		end
	end
	local color_names = get_note_color_names(key_columns)
	local lane_width = height * 48 / 480
	local field_width = columns * lane_width
	local left = (width - field_width) / 2
	local note_width = lane_width
	local note_height = note_width * 1.5 / 2
	local pixels_per_second = height * math.max(player.rate, 0.01)
	local time = player.time
	local until_time = time + height / pixels_per_second

	lg.setColor(0, 0, 0, 0.3)
	lg.rectangle("fill", left, 0, field_width, height)

	local key_column = 0
	for column, notes in ipairs(preview.columns) do
		local display_column = player.column_map[column]
		local x = left + (display_column - 0.5) * lane_width
		local input = self.inputs and self.inputs[column] or ""
		local color_name
		if input:find("scratch") then
			color_name = "green"
		elseif input:find("key") then
			key_column = key_column + 1
			color_name = color_names[key_column]
		else
			color_name = "white"
		end
		local first, last = preview:getVisibleRange(column, time, until_time)
		for i = first, last do
			local note = notes[i]
			if note.time >= time and note.time <= until_time then
				local y = height - (note.time - time) * pixels_per_second
				lg.setColor(note_colors[color_name])
				lg.rectangle("fill", x - note_width / 2, y - note_height / 2, note_width, note_height)
			end
		end
	end
	lg.setColor(1, 1, 1, 1)
end

---@class rizu.skin.base.rizu_mania.Skin
---@field metadata rizu.skin.SkinMetadata
---@field load fun(game: sphere.GameController, input_mode: string): rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer
return {
	metadata = {
		name = "Rizu Mania 4K",
		author = "Rizu",
		version = "0.1.0",
		gamemode = "mania",
		input_modes = {"any"},
	},
	load = function(game, input_mode)
		return ManiaPlayfieldRenderer(game, input_mode)
	end,
}
