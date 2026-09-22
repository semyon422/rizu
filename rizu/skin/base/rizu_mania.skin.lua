local class = require("class")
local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local InputMode = require("chart.core.InputMode")

local lg = love.graphics

local FIELD_WIDTH = 640
local FIELD_HEIGHT = 480
local LANE_WIDTH = 48
local NOTE_HEIGHT = 30
local RECEPTOR_Y = 360

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
---@param screen rizu.skin.Screen
function ManiaPlayfieldRenderer:new(game, input_mode, screen)
	PlayfieldRenderer.new(self, game)
	self.screen = screen
	local mode = InputMode(input_mode)
	self.inputs = mode:getInputs()
	self.input_map = mode:getInputMap()
end

---@param renderer rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer
---@param columns integer
---@return string[]
local function get_column_colors(renderer, columns)
	local key_columns = 0
	for column = 1, columns do
		local input = renderer.inputs[column] or ""
		if input:find("key") then
			key_columns = key_columns + 1
		end
	end
	local color_names = get_note_color_names(key_columns)
	local colors = {}
	local key_column = 0
	for column = 1, columns do
		local input = renderer.inputs[column] or ""
		if input:find("scratch") then
			colors[column] = "green"
		elseif input:find("key") then
			key_column = key_column + 1
			colors[column] = color_names[key_column]
		else
			colors[column] = "white"
		end
	end
	return colors
end

---@param columns integer
---@param lane_width number
---@param width number
---@return number
---@return number
local function get_field_left(columns, lane_width, width)
	local field_width = columns * lane_width
	return (width - field_width) / 2, field_width
end

---@param renderer rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer
---@param note rizu.VisualNote
---@return integer?
local function get_note_column(renderer, note)
	return renderer.input_map[note:getColumn()]
end

---@param note rizu.VisualNote
---@return boolean
local function is_note_visible(note)
	if note.type == "long" then
		return note:getState() ~= "endPassed"
	end
	return note:getState() == "clear"
end

---@param note rizu.VisualNote
---@return boolean
local function is_note_head_visible(note)
	if note.type == "long" then
		return not note:getState():find("^end")
	end
	return note:getState() == "clear"
end

---@param note rizu.VisualNote
---@return boolean
local function is_note_head_held(note)
	-- A missed head can still be physically pressed, but it is not an active
	-- hold. Only a successfully-held head is anchored at the receptor.
	return note.type == "long" and note:getState() == "startPassedPressed"
end

---@param note rizu.VisualNote
---@param y number
---@return number
local function clamp_held_note_y(note, y)
	if is_note_head_held(note) then
		return math.min(RECEPTOR_Y, y)
	end
	return y
end

---@param note rizu.VisualNote
---@param y number
---@return number
local function clamp_held_tail_y(note, y)
	if is_note_head_held(note) then
		return math.min(RECEPTOR_Y + NOTE_HEIGHT / 2, y)
	end
	return y
end

---@param left number
---@param columns integer
---@param lane_width number
---@param height number
local function draw_field(left, columns, lane_width, height)
	lg.setColor(0, 0, 0, 0.3)
	lg.rectangle("fill", left, 0, columns * lane_width, height)
	for column = 0, columns do
		lg.setColor(1, 1, 1, 0.12)
		lg.rectangle("fill", left + column * lane_width, 0, 1, height)
	end
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param color_name string
---@param alpha number?
local function draw_note(x, y, width, height, color_name, alpha)
	local color = note_colors[color_name]
	lg.setColor(color[1], color[2], color[3], alpha or 1)
	lg.rectangle("fill", x - width / 2, y - height / 2, width, height)
end

---@param x number
---@param first_y number
---@param second_y number
---@param width number
---@param color_name string
---@param alpha number?
local function draw_hold_body(x, first_y, second_y, width, color_name, alpha)
	local color = note_colors[color_name]
	lg.setColor(color[1], color[2], color[3], alpha or 0.65)
	lg.rectangle("fill", x - width / 2, math.min(first_y, second_y), width, math.abs(second_y - first_y))
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
	local colors = get_column_colors(self, columns)
	local lane_width = height * LANE_WIDTH / FIELD_HEIGHT
	local left = get_field_left(columns, lane_width, width)
	local note_width = lane_width
	local note_height = lane_width * NOTE_HEIGHT / LANE_WIDTH
	local hold_width = lane_width * 0.64
	local pixels_per_second = height * math.max(player.rate, 0.01)
	local receptor_y = height * RECEPTOR_Y / FIELD_HEIGHT
	local time = player.time
	local until_time = time + receptor_y / pixels_per_second

	draw_field(left, columns, lane_width, height)

	for column, notes in ipairs(preview.columns) do
		local display_column = player.column_map[column]
		local x = left + (display_column - 0.5) * lane_width
		local color_name = colors[column]
		local first, last = preview:getVisibleRange(column, time, until_time)
		for i = first, last do
			local note = notes[i]
			if note.end_time >= time then
				local head_y = receptor_y - (note.time - time) * pixels_per_second
				local tail_y = receptor_y - (note.end_time - time) * pixels_per_second
				if note.end_time > note.time then
					draw_hold_body(x, head_y, tail_y, hold_width, color_name)
				end
				if note.time >= time and note.time <= until_time then
					draw_note(x, head_y, note_width, note_height, color_name)
				end
			end
		end
	end
	lg.setColor(1, 1, 1, 1)
end

---@param width number
---@param height number
---@param transform love.Transform
function ManiaPlayfieldRenderer:draw(width, height, transform)
	local engine = self.game.rhythm_engine
	local visual_engine = engine and engine.visual_engine
	if not visual_engine then return end

	local columns = #self.inputs
	if columns == 0 then return end
	local colors = get_column_colors(self, columns)
	local scale = math.min(width / FIELD_WIDTH, height / FIELD_HEIGHT)
	local field_left = get_field_left(columns, LANE_WIDTH, FIELD_WIDTH)

	lg.push("all")
	lg.applyTransform(transform)
	lg.translate((width - FIELD_WIDTH * scale) / 2, (height - FIELD_HEIGHT * scale) / 2)
	lg.scale(scale)

	draw_field(field_left, columns, LANE_WIDTH, FIELD_HEIGHT)

	-- Bodies are behind heads and receptors.
	for _, note in ipairs(visual_engine.visible_notes) do
		if note.type == "long" and is_note_visible(note) then
			local column = get_note_column(self, note)
			if column and column >= 1 and column <= columns then
				local x = field_left + (column - 0.5) * LANE_WIDTH
				local head_y = clamp_held_note_y(note, RECEPTOR_Y + note.start_dt * FIELD_HEIGHT)
				local tail_y = clamp_held_tail_y(note, RECEPTOR_Y + note.end_dt * FIELD_HEIGHT)
				draw_hold_body(x, head_y, tail_y, LANE_WIDTH * 0.64, colors[column])
			end
		end
	end

	for _, note in ipairs(visual_engine.visible_notes) do
		local column = get_note_column(self, note)
		if is_note_head_visible(note) then
		if column and column >= 1 and column <= columns then
			local x = field_left + (column - 0.5) * LANE_WIDTH
			local y = clamp_held_note_y(note, RECEPTOR_Y + note.start_dt * FIELD_HEIGHT)
			draw_note(x, y, LANE_WIDTH, NOTE_HEIGHT, colors[column])
		end
		end
	end

	for column = 1, columns do
		local x = field_left + (column - 0.5) * LANE_WIDTH
		local color = note_colors[colors[column]]
		local pressed = engine:isColumnPressed(column)
		lg.setColor(color[1], color[2], color[3], pressed and 1 or 0.55)
		lg.rectangle("fill", x - LANE_WIDTH / 2, RECEPTOR_Y - 6, LANE_WIDTH, 12)
	end
	lg.pop()
end

---@class rizu.skin.base.rizu_mania.Skin
---@field metadata rizu.skin.SkinMetadata
---@field load fun(game: sphere.GameController, input_mode: string, screen: rizu.skin.Screen): rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer
return {
	metadata = {
		name = "Rizu Default",
		author = "Rizu",
		version = "0.1.0",
		gamemode = "mania",
		input_modes = {"any"},
	},
	load = function(game, input_mode, screen)
		return ManiaPlayfieldRenderer(game, input_mode, screen)
	end,
}
