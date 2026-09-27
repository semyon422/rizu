local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local Hud = require("rizu.skin.Hud")
local AccuracyView = require("rizu.skin.views.AccuracyView")
local ComboView = require("rizu.skin.views.ComboView")
local ScoreView = require("rizu.skin.views.ScoreView")
local CurrentJudgeView = require("rizu.skin.views.CurrentJudgeView")
local InputMode = require("chart.core.InputMode")
local SkinConfig = require("rizu.skin.SkinConfig")

local lg = love.graphics

local FIELD_WIDTH = 640
local FIELD_HEIGHT = 480
local LANE_WIDTH = 48
local NOTE_HEIGHT = 30
local DEFAULT_RECEPTOR_Y = 360
local MIN_RECEPTOR_Y = 0
local MAX_RECEPTOR_Y = FIELD_HEIGHT
local MIN_PLAYFIELD_X_OFFSET = -FIELD_WIDTH
local MAX_PLAYFIELD_X_OFFSET = FIELD_WIDTH

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

---@class rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer.Property
---@field key string
---@field label_key string
---@field min number
---@field max number
---@field step number
---@field get fun(): number
---@field set fun(value: number)

---@class rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer : rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer
---@field config rizu.skin.SkinConfig
---@field config_path string
---@field input_mode string
---@field hud rizu.skin.Hud?
---@field hud_fonts {regular: love.Font, emphasis: love.Font}?
local ManiaPlayfieldRenderer = PlayfieldRenderer + {}

---@param game sphere.GameController
---@param input_mode string
---@param screen rizu.skin.Screen
---@param config rizu.skin.SkinConfig?
---@param config_path string?
function ManiaPlayfieldRenderer:new(game, input_mode, screen, config, config_path)
	PlayfieldRenderer.new(self, game)
	self.screen = screen
	self.input_mode = input_mode
	self.config = config or SkinConfig()
	self.config_path = config_path or "userdata/dlc/skins_rizu/base/skin-config.json"
	local mode = InputMode(input_mode)
	self.inputs = mode:getInputs()
	self.input_map = mode:getInputMap()
end

function ManiaPlayfieldRenderer:unload()
	if self.hud then
		self.hud:unload(self.game)
		self.hud = nil
	end
	if self.hud_fonts then
		self.hud_fonts.regular:release()
		self.hud_fonts.emphasis:release()
		self.hud_fonts = nil
	end
end

function ManiaPlayfieldRenderer:getReceptorY()
	local value = self.config:get("mania", self.input_mode, "receptor.y", DEFAULT_RECEPTOR_Y)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		value = DEFAULT_RECEPTOR_Y
	end
	return math.max(MIN_RECEPTOR_Y, math.min(MAX_RECEPTOR_Y, value))
end

function ManiaPlayfieldRenderer:setReceptorY(value)
	assert(type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge,
		"receptor y must be a finite number")
	assert(value >= MIN_RECEPTOR_Y and value <= MAX_RECEPTOR_Y, "receptor y is out of range")
	self.config:set("mania", self.input_mode, "receptor.y", value)
end

function ManiaPlayfieldRenderer:getPlayfieldXOffset()
	local value = self.config:get("mania", self.input_mode, "playfield.x_offset", 0)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		value = 0
	end
	return math.max(MIN_PLAYFIELD_X_OFFSET, math.min(MAX_PLAYFIELD_X_OFFSET, value))
end

function ManiaPlayfieldRenderer:setPlayfieldXOffset(value)
	assert(type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge,
		"playfield x offset must be a finite number")
	assert(value >= MIN_PLAYFIELD_X_OFFSET and value <= MAX_PLAYFIELD_X_OFFSET,
		"playfield x offset is out of range")
	self.config:set("mania", self.input_mode, "playfield.x_offset", value)
end

---@return rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer.Property[]
function ManiaPlayfieldRenderer:getProperties()
	return {
		{key = "receptor.y", label_key = "gameplay.skin_editor.receptor_y",
			min = MIN_RECEPTOR_Y, max = MAX_RECEPTOR_Y, step = 1,
			get = function() return self:getReceptorY() end,
			set = function(value) self:setReceptorY(value) end},
		{key = "playfield.x_offset", label_key = "gameplay.skin_editor.playfield_x_offset",
			min = MIN_PLAYFIELD_X_OFFSET,
			max = MAX_PLAYFIELD_X_OFFSET, step = 1,
			get = function() return self:getPlayfieldXOffset() end,
			set = function(value) self:setPlayfieldXOffset(value) end},
	}
end

---@return boolean success
---@return string? error_message
function ManiaPlayfieldRenderer:saveConfig()
	return self.config:save(self.game.fs, self.config_path)
end

---@param player rizu.preview.NotesPreviewPlayer
---@param column integer
---@param columns integer
---@return integer
function ManiaPlayfieldRenderer:getPreviewDisplayColumn(player, column, columns)
	if player.input_mode ~= self.input_mode then return math.min(column, columns) end
	local display_column = player.column_map and player.column_map[column]
	if type(display_column) == "number" and display_column % 1 == 0
		and display_column >= 1 and display_column <= columns then
		return display_column
	end
	return math.min(column, columns)
end

---@param renderer rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer
---@param columns integer
---@return string[]
local function get_column_colors(renderer, columns)
	local key_columns = 0
	for _, input in ipairs(renderer.inputs) do
		if input:find("key") then key_columns = key_columns + 1 end
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
---@return number left
---@return number field_width
local function get_field_left(columns, lane_width, width)
	local field_width = columns * lane_width
	return (width - field_width) / 2, field_width
end

---@param width number
---@param height number
---@return number scale
---@return number offset_x
---@return number offset_y
local function get_field_transform(width, height)
	local scale = math.min(width / FIELD_WIDTH, height / FIELD_HEIGHT)
	return scale, (width - FIELD_WIDTH * scale) / 2, (height - FIELD_HEIGHT * scale) / 2
end

---@param columns integer
---@param offset_x number
---@return number left
local function get_field_offset(columns, offset_x)
	return get_field_left(columns, LANE_WIDTH, FIELD_WIDTH) + offset_x
end

---@param renderer rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer
---@param note rizu.VisualNote
---@return integer?
local function get_note_column(renderer, note)
	return renderer.input_map[note:getColumn()]
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
---@param receptor_y number
---@return number
local function clamp_held_note_y(note, y, receptor_y)
	if is_note_head_held(note) then return math.min(receptor_y, y) end
	return y
end

---@param note rizu.VisualNote
---@param y number
---@param receptor_y number
---@return number
local function clamp_held_tail_y(note, y, receptor_y)
	if is_note_head_held(note) then return math.min(receptor_y + NOTE_HEIGHT / 2, y) end
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
	if not preview then return end

	local columns = #self.inputs
	local colors = get_column_colors(self, columns)
	local scale, offset_x, offset_y = get_field_transform(width, height)
	local left = get_field_offset(columns, self:getPlayfieldXOffset())
	local hold_width = LANE_WIDTH * 0.64
	local pixels_per_second = FIELD_HEIGHT * math.max(player.rate, 0.01)
	local receptor_y = self:getReceptorY()
	local time = player.time
	local from_time = time - (FIELD_HEIGHT - receptor_y) / pixels_per_second
	local until_time = time + receptor_y / pixels_per_second

	lg.push("all")
	lg.translate(offset_x, offset_y)
	lg.scale(scale)
	draw_field(left, columns, LANE_WIDTH, FIELD_HEIGHT)

	local preview_columns = math.min(columns, #preview.columns)
	for column = 1, preview_columns do
		local notes = preview.columns[column]
		local display_column = self:getPreviewDisplayColumn(player, column, columns)
		local x = left + (display_column - 0.5) * LANE_WIDTH
		local color_name = colors[column]
		local first, last = preview:getVisibleRange(column, from_time, until_time)
		for i = first, last do
			local note = notes[i]
			if note.end_time >= from_time then
				local head_y = receptor_y - (note.time - time) * pixels_per_second
				local tail_y = receptor_y - (note.end_time - time) * pixels_per_second
				if note.end_time > note.time then draw_hold_body(x, head_y, tail_y, hold_width, color_name) end
				if note.time >= from_time and note.time <= until_time then
					draw_note(x, head_y, LANE_WIDTH, NOTE_HEIGHT, color_name)
				end
			end
		end
	end

	for column = 1, columns do
		local display_column = self:getPreviewDisplayColumn(player, column, columns)
		local x = left + (display_column - 0.5) * LANE_WIDTH
		local color = note_colors[colors[column]]
		lg.setColor(color[1], color[2], color[3], 0.55)
		lg.rectangle("fill", x - LANE_WIDTH / 2, receptor_y - 6, LANE_WIDTH, 12)
	end
	lg.pop()
end

---@param width number
---@param height number
---@param transform love.Transform
function ManiaPlayfieldRenderer:drawHud(width, height, transform)
	local scale = get_field_transform(width, height)
	self:drawHudInViewport(transform, width, height, scale)
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
	local scale, offset_x, offset_y = get_field_transform(width, height)
	local field_left = get_field_offset(columns, self:getPlayfieldXOffset())
	local receptor_y = self:getReceptorY()

	lg.push("all")
	lg.applyTransform(transform)
	lg.translate(offset_x, offset_y)
	lg.scale(scale)

	draw_field(field_left, columns, LANE_WIDTH, FIELD_HEIGHT)

	-- Bodies are behind heads and receptors.
	for _, note in ipairs(visual_engine.visible_notes) do
		local state = note:getState()
		if note.type == "long" and state ~= "endPassed" then
			local column = get_note_column(self, note)
			if column and column >= 1 and column <= columns then
				local x = field_left + (column - 0.5) * LANE_WIDTH
				local head_y = clamp_held_note_y(note, receptor_y + note.start_dt * FIELD_HEIGHT, receptor_y)
				local tail_y = clamp_held_tail_y(note, receptor_y + note.end_dt * FIELD_HEIGHT, receptor_y)
				draw_hold_body(x, head_y, tail_y, LANE_WIDTH * 0.64, colors[column])
			end
		end
	end

	for _, note in ipairs(visual_engine.visible_notes) do
		local state = note:getState()
		if state ~= "passed" and state ~= "endPassed" then
			local column = get_note_column(self, note)
			if column and column >= 1 and column <= columns then
				local x = field_left + (column - 0.5) * LANE_WIDTH
				local y = clamp_held_note_y(note, receptor_y + note.start_dt * FIELD_HEIGHT, receptor_y)
				draw_note(x, y, LANE_WIDTH, NOTE_HEIGHT, colors[column])
			end
		end
	end

	for column = 1, columns do
		local x = field_left + (column - 0.5) * LANE_WIDTH
		local color = note_colors[colors[column]]
		local pressed = engine:isColumnPressed(column)
		lg.setColor(color[1], color[2], color[3], pressed and 1 or 0.55)
		lg.rectangle("fill", x - LANE_WIDTH / 2, receptor_y - 6, LANE_WIDTH, 12)
	end
	lg.pop()
end

---@param game sphere.GameController
---@param fonts {regular: love.Font, emphasis: love.Font}
local function create_hud(game, fonts)
	local hud = Hud({width = FIELD_WIDTH, height = FIELD_HEIGHT})
	hud:add(AccuracyView(fonts.regular, {x = -8, y = 38}))
	hud:add(ScoreView(fonts.regular, {x = -8, y = 8}))
	hud:add(ComboView(fonts.emphasis, {y = -36}))
	hud:add(CurrentJudgeView(fonts.emphasis, {y = -72}))
	hud:load(game)
	return hud
end

function ManiaPlayfieldRenderer:load()
	if self.screen ~= "gameplay" or self.hud then return end
	self.hud_fonts = {
		regular = love.graphics.newFont("resources/fonts/NotoSansMono-Regular.ttf", 24, "normal", 4),
		emphasis = love.graphics.newFont("resources/fonts/NotoSansMono-Regular.ttf", 32, "normal", 4),
	}
	self.hud = create_hud(self.game, self.hud_fonts)
end

---@param game sphere.GameController
---@param input_mode string
---@param screen rizu.skin.Screen
---@param config rizu.skin.SkinConfig?
---@param config_path string?
---@return rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer
local function load_skin(game, input_mode, screen, config, config_path)
	local renderer = ManiaPlayfieldRenderer(game, input_mode, screen, config, config_path)
	return renderer
end

---@class rizu.skin.base.rizu_mania.Skin
---@field metadata rizu.skin.SkinMetadata
---@field load fun(game: sphere.GameController, input_mode: string, screen: rizu.skin.Screen, config: rizu.skin.SkinConfig?, config_path: string?): rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer
return {
	metadata = {
		name = "Rizu Default",
		author = "Rizu",
		version = "0.1.0",
		gamemode = "mania",
		input_modes = {"any"},
	},
	load = load_skin,
}
