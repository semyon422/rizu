local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local OsuManiaSkinGraphics = require("rizu.skin.osu.mania.OsuManiaSkinGraphics")
local OsuManiaHud = require("rizu.skin.osu.mania.OsuManiaHud")
local InputMode = require("chart.core.InputMode")
local Settings = require("rizu.config.Settings")

local lg = love.graphics
local FIELD_WIDTH, FIELD_HEIGHT = 640, 480
local DEFAULT_COLUMN_WIDTH = 30
local DEFAULT_COLUMN_START = 136
local DEFAULT_COLUMN_RIGHT = 19
local DEFAULT_HIT_POSITION = 402
local NOTE_SCROLL_SPEED = FIELD_HEIGHT

---@class rizu.skin.osu.OsuManiaRenderer : rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.skin.osu.OsuManiaRenderer
---@field skin_graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
---@field skin rizu.skin.OsuSkinDiscovery?
---@field section rizu.skin.OsuSkinIni.ManiaSection
---@field columns integer
---@field column_widths number[]
---@field column_spacings number[]
---@field column_lines number[]
---@field column_start number
---@field column_right number
---@field hit_position number
---@field special_style integer
---@field note_height_scale number
---@field upside_down boolean
---@field keys_under_notes boolean
---@field judgement_line boolean
---@field note_flip boolean
---@field key_flip boolean
---@field scratch_on_left boolean
---@field engine_input_map {[chart.Column]: integer}
---@field hud rizu.skin.osu.mania.OsuManiaHud
---@field split_stages boolean
---@field stage_separation number
local OsuManiaRenderer = PlayfieldRenderer + {}
OsuManiaRenderer.field_width = FIELD_WIDTH
OsuManiaRenderer.field_height = FIELD_HEIGHT

---@param game sphere.GameController
---@param input_mode string?
---@param skin_path string?
function OsuManiaRenderer:new(game, input_mode, skin_path)
	PlayfieldRenderer.new(self, game)
	self.input_mode = input_mode or "4key"
	self.skin_path = skin_path
	local mode = InputMode(self.input_mode)
	self.inputs = mode:getInputs()
	self.base_inputs = mode:getInputs()
	self.engine_input_map = mode:getInputMap()
	self.input_map = self.engine_input_map
	self.skin_graphics = OsuManiaSkinGraphics(game.fs)
	self.hud = OsuManiaHud(game, self.skin_graphics)
	local package_manager = game.packageManager
	local osu_ui_directory = package_manager and package_manager:getPackageDir("osu_ui")
	if osu_ui_directory then
		self.skin_graphics:setFallbackDirectory(osu_ui_directory .. "/osu_ui/assets")
	end
	self.skin = nil
	self.section = {}
	self.columns = 0
	self.column_widths = {}
	self.column_spacings = {}
	self.column_lines = {}
	self.column_start = DEFAULT_COLUMN_START
	self.column_right = DEFAULT_COLUMN_RIGHT
	self.hit_position = DEFAULT_HIT_POSITION
	self.special_style = 0
	self.note_height_scale = 0
	self.upside_down = false
	self.keys_under_notes = false
	self.judgement_line = true
	self.note_flip = true
	self.key_flip = true
	self.scratch_on_left = false -- Should be replaced by visual column reorder.
	self.split_stages = false
	self.stage_separation = 40
	self:loadSkinSettings(self:getSkin())
end

---@return rizu.skin.OsuSkinDiscovery?
function OsuManiaRenderer:getSkin()
	local registry = self.game and self.game.skinRegistry
	if not registry then return nil end
	local skin_path = self.skin_path
	if not skin_path then
		local settings = self.game.settings
		if settings then
			local skin_paths = settings:getStringMap(Settings.keys.gameplay.skins)
			skin_path = skin_paths["mania/" .. self.input_mode]
				or skin_paths["osu/1osu"] or skin_paths.osu
		end
	end
	if skin_path then
		local normalized_path = skin_path:gsub("\\", "/"):gsub("/+$", "")
		local skin = registry:getOsuSkin(normalized_path)
		if skin then return skin end
	end
	local skins = registry:getOsuSkins()
	return skins and skins[1] or nil
end

---@param section rizu.skin.OsuSkinIni.ManiaSection
---@param key string
---@return string?
local function get_section_value(section, key)
	local value = section[key]
	if value ~= nil then return value end
	local lowered_key = key:lower()
	for name, candidate in pairs(section) do
		if name:lower() == lowered_key then return candidate end
	end
end

---@param section rizu.skin.OsuSkinIni.ManiaSection
---@param key string
---@param default number
---@return number
local function get_number(section, key, default)
	local value = get_section_value(section, key)
	local number = tonumber(value)
	if number == nil or number ~= number or number == math.huge or number == -math.huge then
		return default
	end
	return number
end

---@param section rizu.skin.OsuSkinIni.ManiaSection
---@param key string
---@param default boolean
---@return boolean
local function get_boolean(section, key, default)
	local value = get_section_value(section, key)
	if not value then return default end
	value = value:lower()
	if value == "true" or tonumber(value) == 1 then return true end
	if value == "false" or tonumber(value) == 0 then return false end
	return default
end

---@param section rizu.skin.OsuSkinIni.ManiaSection
---@param key string
---@param count integer
---@param default number
---@param minimum number
---@param maximum number
---@return number[]
local function get_number_list(section, key, count, default, minimum, maximum)
	local result = {}
	local value = get_section_value(section, key)
	local values = {}
	if value then
		for component in (value .. ","):gmatch("(.-),") do
			values[#values + 1] = tonumber(component:match("^%s*(.-)%s*$"))
		end
	end
	for index = 1, count do
		local item = values[index]
		if type(item) ~= "number" or item ~= item or item == math.huge or item == -math.huge then
			item = default
		end
		result[index] = math.max(minimum, math.min(maximum, item))
	end
	return result
end

---@param skin rizu.skin.OsuSkinDiscovery?
function OsuManiaRenderer:loadSkinSettings(skin)
	self.skin = skin
	self.inputs = {}
	for index, input in ipairs(self.base_inputs) do self.inputs[index] = input end
	local columns = #self.inputs
	columns = math.max(1, math.min(18, math.floor(columns)))
	self.columns = columns
	local section = {}
	for _, candidate in ipairs(skin and skin.skin_ini.Mania or {}) do
		if tonumber(get_section_value(candidate, "Keys")) == columns then
			section = candidate
			break
		end
	end
	self.section = section
	self.column_widths = get_number_list(section, "ColumnWidth", columns, DEFAULT_COLUMN_WIDTH, 5, 100)
	self.column_spacings = get_number_list(section, "ColumnSpacing", math.max(columns - 1, 0), 0, -100, 100)
	for index = 1, #self.column_spacings do
		self.column_spacings[index] = math.max(self.column_spacings[index], -self.column_widths[index + 1])
	end
	self.column_lines = get_number_list(section, "ColumnLineWidth", columns + 1, 2, 0, 100)
	for index, line_width in ipairs(self.column_lines) do
		if line_width > 0 and line_width < 2 then self.column_lines[index] = 2 end
	end
	self.column_start = get_number(section, "ColumnStart", DEFAULT_COLUMN_START)
	self.column_right = get_number(section, "ColumnRight", DEFAULT_COLUMN_RIGHT)
	self.hit_position = math.max(240, math.min(480, get_number(section, "HitPosition", DEFAULT_HIT_POSITION)))
	self.special_style = math.max(0, math.min(2, math.floor(get_number(section, "SpecialStyle", 0))))
	self.note_height_scale = math.max(0, get_number(section, "WidthForNoteHeightScale", 0))
	self.upside_down = get_boolean(section, "UpsideDown", false)
	self.keys_under_notes = get_boolean(section, "KeysUnderNotes", false)
	self.judgement_line = get_boolean(section, "JudgementLine", false)
	self.note_flip = get_boolean(section, "NoteFlipWhenUpsideDown", true)
	self.key_flip = get_boolean(section, "KeyFlipWhenUpsideDown", true)
	self.scratch_on_left = get_boolean(section, "ScratchOnLeft", false)
	self.split_stages = get_boolean(section, "SplitStages", self.columns >= 10)
	self.stage_separation = math.max(5, get_number(section, "StageSeparation", 40))
	self.hud:loadSkin(skin, section, self.upside_down)
	if self.split_stages and columns > 1 then
		local split = math.floor(columns / 2)
		self.column_spacings[split] = math.max(self.column_spacings[split] or 0, self.stage_separation)
	end

	local inputs = self.input_map
	local skin_inputs = get_section_value(section, "Inputs" .. self.input_mode)
	if skin_inputs then
		local reordered = {}
		for input in (skin_inputs .. ","):gmatch("(.-),") do
			input = input:match("^%s*(.-)%s*$")
			if input ~= "" then reordered[#reordered + 1] = input end
		end
		if #reordered == columns then self.inputs = reordered end
	end
	if self.scratch_on_left then
		for index, input in ipairs(self.inputs) do
			if input:lower():match("^scratch%d+$") then
				table.remove(self.inputs, index)
				table.insert(self.inputs, 1, input)
				break
			end
		end
	end
	inputs = {}
	for column, input in ipairs(self.inputs) do inputs[input] = column end
	self.input_map = inputs
end

function OsuManiaRenderer:load()
	local skin = self:getSkin()
	if self.skin ~= skin then self:loadSkinSettings(skin) end
	if self.skin_graphics.skin ~= skin then self.skin_graphics:setSkin(skin) end
	if not self.skin_graphics.loaded then
		self.skin_graphics:load(self:getSkinAssets())
	end
end

function OsuManiaRenderer:unload()
	self.skin_graphics:unload()
end

---@param width number
---@param height number
---@return number scale
---@return number offset_x
---@return number offset_y
function OsuManiaRenderer:getFieldTransform(width, height)
	local scale = math.max(0, math.min(width / FIELD_WIDTH, height / FIELD_HEIGHT))
	return scale, (width - FIELD_WIDTH * scale) / 2, (height - FIELD_HEIGHT * scale) / 2
end

---@return number left
---@return number[] widths
---@return number scale
function OsuManiaRenderer:getPlayfieldLayout()
	local widths = {}
	local full_width = 0
	for index, width in ipairs(self.column_widths) do
		widths[index] = width
		full_width = full_width + width
		if index > 1 then full_width = full_width + (self.column_spacings[index - 1] or 0) end
	end
	if self.split_stages and #widths > 1 then
		local split = math.floor(#widths / 2)
		local previous_spacing = self.column_spacings[split] or 0
		local stage_spacing = math.max(previous_spacing, self.stage_separation)
		self.column_spacings[split] = stage_spacing
		full_width = full_width + stage_spacing - previous_spacing
	end
	local left = math.max(0, math.min(self.column_start, FIELD_WIDTH - self.column_right))
	local right = math.max(0, math.min(self.column_right, FIELD_WIDTH - left))
	local available_width = math.max(0, FIELD_WIDTH - left - right)
	local scale = full_width > available_width and available_width / full_width or 1
	return left, widths, scale
end

---@return {name: string?, fallback: string?}[]
function OsuManiaRenderer:getSkinAssets()
	local assets, seen = {}, {}
	local function add(name, fallback)
		if not name or name == "" then return end
		local key = name:lower() .. "\0" .. tostring(fallback or ""):lower()
		if seen[key] then return end
		seen[key] = true
		assets[#assets + 1] = {name = name, fallback = fallback}
	end

	for column = 1, self.columns do
		local zero_based_column = column - 1
		local suffix = self:getColumnSuffix(zero_based_column)
		for _, postfix in ipairs({"", "H", "L", "T"}) do
			add(get_section_value(self.section, "NoteImage" .. zero_based_column .. postfix))
			if postfix == "H" or postfix == "T" then
				add(get_section_value(self.section, "NoteImage" .. zero_based_column .. "H"))
				add(get_section_value(self.section, "NoteImage" .. zero_based_column))
			end
			local fallback = "mania-note" .. suffix .. postfix
			add(fallback)
			if postfix == "H" or postfix == "T" then add("mania-note" .. suffix) end
		end
		add(get_section_value(self.section, "KeyImage" .. zero_based_column))
		add(get_section_value(self.section, "KeyImage" .. zero_based_column .. "D"))
		add("mania-key" .. suffix)
		add("mania-key" .. suffix .. "D")
	end

	for _, key in ipairs({"StageHint", "StageLeft", "StageRight", "StageBottom"}) do
		local name = get_section_value(self.section, key)
		if name and tonumber(name) then name = nil end
		local fallback = "mania-" .. key:gsub("^Stage", "stage-"):lower()
		add(name, fallback)
	end

	for _, name in ipairs(self.hud:getImageAssets()) do add(name) end
	return assets
end

---@param column integer one based physical Mania lane index
---@param image love.Image
---@return number width
---@return number height
function OsuManiaRenderer:getNoteDimensions(column, image)
	local _, _, width_scale = self:getPlayfieldLayout()
	local width = (self.column_widths[column] or DEFAULT_COLUMN_WIDTH) * width_scale
	local base_width = self.note_height_scale > 0 and self.note_height_scale or self.column_widths[1] or DEFAULT_COLUMN_WIDTH
	for lane = 2, self.columns do
		base_width = math.min(base_width,
			self.note_height_scale > 0 and self.note_height_scale or self.column_widths[lane] or DEFAULT_COLUMN_WIDTH)
	end
	local image_width, image_height = image:getDimensions()
	local height = image_width > 0 and image_height * base_width * width_scale / image_width or 0
	return width, height
end

---@param column integer zero based physical Mania lane index
---@return "1"|"2"|"S"
function OsuManiaRenderer:getColumnSuffix(column)
	local key = column + 1
	local key_count = self.columns
	local special_style = self.special_style

	if special_style == 1 then
		if key == 1 then return "S" end
		key = key - 1
		key_count = key_count - 1
	elseif special_style == 2 then
		if key == key_count then return "S" end
		key_count = key_count - 1
	end

	if key_count % 2 == 1 then
		local half = (key_count - 1) / 2
		if (key_count + 1) / 2 == key then
			if special_style == 0 then return "S" end
			return "2"
		end
		return (half - key + 1) % 2 == 1 and "1" or "2"
	end

	local odd = (key_count / 2 - key + 1) % 2 == 1
	local same = key <= key_count / 2
	return odd == same and "2" or "1"
end

---@param image love.Image
---@param x number
---@param y number
---@param width number
---@param alpha number?
local function draw_image_bottom_centered(image, x, bottom_y, width, alpha)
	local image_width, image_height = image:getDimensions()
	if image_width <= 0 or image_height <= 0 then return end
	local scale = width / image_width
	lg.setColor(1, 1, 1, alpha or 1)
	lg.draw(image, x, bottom_y, 0, scale, scale, image_width / 2, image_height)
end

---@param image love.Image
---@param x number
---@param y number
---@param width number
---@param height number
---@param flip boolean
local function draw_image_rect(image, x, y, width, height, flip)
	local image_width, image_height = image:getDimensions()
	if image_width <= 0 or image_height <= 0 then return end
	local scale_x, scale_y = width / image_width, height / image_height
	lg.setColor(1, 1, 1, 1)
	if flip then
		lg.draw(image, x, y + height, 0, scale_x, -scale_y, 0, image_height)
	else
		lg.draw(image, x, y, 0, scale_x, scale_y)
	end
end

---@param image love.Image
---@param x number
---@param bottom_y number
---@param target_width number
---@param target_height number
---@param flip boolean
local function draw_note_head(image, x, y, target_width, target_height, flip, upside_down)
	local image_width, image_height = image:getDimensions()
	if image_width <= 0 or image_height <= 0 then return end
	local scale_x, scale_y = target_width / image_width, target_height / image_height
	lg.setColor(1, 1, 1, 1)
	if upside_down then
		if flip then
			lg.draw(image, x, y, 0, scale_x, -scale_y, image_width / 2, image_height)
		else
			lg.draw(image, x, y, 0, scale_x, scale_y, image_width / 2, 0)
		end
	elseif flip then
		lg.draw(image, x, y, 0, scale_x, -scale_y, image_width / 2, 0)
	else
		lg.draw(image, x, y, 0, scale_x, scale_y, image_width / 2, image_height)
	end
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param name string?
---@return love.Image?
local function get_first_frame(renderer, name)
	return renderer.skin_graphics:getFrames(name, nil)[1]
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param column integer
---@param suffix string
---@param postfix string
---@return love.Image?
local function get_column_image(renderer, column, suffix, postfix)
	local graphics = renderer.skin_graphics
	local function find(name)
		return name and graphics:getFrames(name, nil)[1]
	end

	local image = find(get_section_value(renderer.section, "NoteImage" .. column .. postfix))
	if image then return image end
	if postfix == "H" or postfix == "T" then
		image = find(get_section_value(renderer.section, "NoteImage" .. column .. "H"))
		if image then return image end
		image = find(get_section_value(renderer.section, "NoteImage" .. column))
		if image then return image end
	end

	local fallback = graphics:getFrames("mania-note" .. suffix .. postfix, nil)[1]
	if fallback then return fallback end
	if postfix == "H" or postfix == "T" then
		return graphics:getFrames("mania-note" .. suffix, nil)[1]
	end
end

---@param section rizu.skin.OsuSkinIni.ManiaSection
---@param key string
---@param fallback number[]
---@return number[]
local function get_color(section, key, fallback)
	local value = get_section_value(section, key)
	if not value then return fallback end
	local values = {}
	for component in (value .. ","):gmatch("(.-),") do
		local number = tonumber(component:match("^%s*(.-)%s*$"))
		if not number then return fallback end
		values[#values + 1] = math.max(0, math.min(255, number)) / 255
	end
	if #values < 3 then return fallback end
	values[4] = values[4] or 1
	return values
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param engine rizu.RhythmEngine
---@param lane_widths number[]
---@param lane_xs number[]
---@param hit_y number
local function draw_keys(renderer, engine, lane_widths, lane_xs, hit_y)
	for column = 1, renderer.columns do
		local suffix = renderer:getColumnSuffix(column - 1)
		local key_name = get_section_value(renderer.section, "KeyImage" .. (column - 1))
		local down_name = get_section_value(renderer.section, "KeyImage" .. (column - 1) .. "D")
		local input = renderer.inputs[column]
		local engine_column = renderer.engine_input_map[input] or column
		local pressed = engine.isColumnPressed and engine:isColumnPressed(engine_column) or false
		local key = get_first_frame(renderer, pressed and down_name or key_name)
		if not key and pressed then key = get_first_frame(renderer, key_name) end
		if not key then key = get_first_frame(renderer, "mania-key" .. suffix .. (pressed and "D" or "")) end
		if not key and pressed then key = get_first_frame(renderer, "mania-key" .. suffix) end
		if key then
			local draw_width = lane_widths[column]
			local draw_y = renderer.upside_down and 0 or FIELD_HEIGHT
			local flip_value = get_section_value(renderer.section, "KeyFlipWhenUpsideDown" .. (column - 1)
				.. (pressed and "D" or ""))
			if not flip_value then
				flip_value = get_section_value(renderer.section, "KeyFlipWhenUpsideDown" .. (column - 1))
			end
			local flip = renderer.upside_down and (flip_value and (flip_value:lower() == "true"
				or tonumber(flip_value) == 1) or renderer.key_flip)
			local image_width, image_height = key:getDimensions()
			local scale_x, scale_y = draw_width / image_width, 480 / 768
			lg.setColor(1, 1, 1, 1)
			if renderer.upside_down then
				if flip then
					lg.draw(key, lane_xs[column], 0, 0, scale_x, -scale_y, image_width / 2, image_height)
				else
					lg.draw(key, lane_xs[column], 0, 0, scale_x, scale_y, image_width / 2, 0)
				end
			elseif flip then
				lg.draw(key, lane_xs[column], FIELD_HEIGHT, 0, scale_x, -scale_y, image_width / 2, 0)
			else
				lg.draw(key, lane_xs[column], FIELD_HEIGHT, 0, scale_x, scale_y,
					image_width / 2, image_height)
			end
		else
			lg.setColor(1, 1, 1, pressed and 0.8 or 0.22)
			lg.rectangle("fill", lane_xs[column] - lane_widths[column] / 2, hit_y - 5,
				lane_widths[column], 10)
		end
	end
end

---@param field_left number
---@param field_width number
---@param lane_widths number[]
---@param lane_xs number[]
---@param hit_y number
function OsuManiaRenderer:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y)
	local function image(name, fallback)
		return self.skin_graphics:getFrames(name, fallback)[1]
	end

	local stage_hint_name = get_section_value(self.section, "StageHint")
	if stage_hint_name and tonumber(stage_hint_name) then stage_hint_name = nil end
	local stage_hint = image(stage_hint_name, "mania-stage-hint")
	if stage_hint then
		local _, image_height = stage_hint:getDimensions()
		lg.setColor(1, 1, 1, 1)
		lg.draw(stage_hint, field_left, hit_y - image_height / 2, 0, field_width / stage_hint:getWidth(), 1)
	end

	local first_right_column = self.split_stages and math.floor(self.columns / 2) + 1 or 1
	local last_left_column = self.split_stages and math.floor(self.columns / 2) or self.columns
	local left_edge = lane_xs[1] - lane_widths[1] / 2
	local right_edge = lane_xs[self.columns] + lane_widths[self.columns] / 2
	local stage_left_name = get_section_value(self.section, "StageLeft")
	local stage_right_name = get_section_value(self.section, "StageRight")
	local stage_bottom_name = get_section_value(self.section, "StageBottom")
	if stage_left_name and tonumber(stage_left_name) then stage_left_name = nil end
	if stage_right_name and tonumber(stage_right_name) then stage_right_name = nil end
	if stage_bottom_name and tonumber(stage_bottom_name) then stage_bottom_name = nil end
	local stage_left = image(stage_left_name, "mania-stage-left")
	local stage_right = image(stage_right_name, "mania-stage-right")
	local stage_bottom = image(stage_bottom_name, "mania-stage-bottom")

	local function draw_stage_pair(first, last)
		if first > last then return end
		local left = lane_xs[first] - lane_widths[first] / 2
		local right = lane_xs[last] + lane_widths[last] / 2
		if stage_left then
			local image_width, image_height = stage_left:getDimensions()
			local height = FIELD_HEIGHT
			local width = image_width * height / image_height
			lg.setColor(1, 1, 1, 1)
			lg.draw(stage_left, left, FIELD_HEIGHT, 0, width / image_width, height / image_height,
				image_width, image_height)
		end
		if stage_right then
			local image_width, image_height = stage_right:getDimensions()
			local height = FIELD_HEIGHT
			local width = image_width * height / image_height
			lg.setColor(1, 1, 1, 1)
			lg.draw(stage_right, right, FIELD_HEIGHT, 0, width / image_width, height / image_height,
				0, image_height)
		end
	end

	if self.split_stages then
		draw_stage_pair(1, last_left_column)
		draw_stage_pair(first_right_column, self.columns)
	else
		draw_stage_pair(1, self.columns)
	end

	if stage_bottom then
		lg.setColor(1, 1, 1, 1)
		lg.draw(stage_bottom, (left_edge + right_edge) / 2, FIELD_HEIGHT, 0, 1, 1,
			stage_bottom:getWidth() / 2, stage_bottom:getHeight())
	end
end

---@param player rizu.preview.NotesPreviewPlayer
---@param width number Preview width in drawable pixels
---@param height number Preview height in drawable pixels
function OsuManiaRenderer:drawPreview(player, width, height)
	local preview = player and player.notes
	if not preview or self.columns == 0 then return end
	self:load()
	local scale, offset_x, offset_y = self:getFieldTransform(width, height)
	local field_left, column_widths, width_scale = self:getPlayfieldLayout()
	local lane_widths, lane_xs = {}, {}
	local x = field_left
	for column = 1, self.columns do
		if column > 1 then x = x + (self.column_spacings[column - 1] or 0) * width_scale end
		lane_widths[column] = column_widths[column] * width_scale
		lane_xs[column] = x + lane_widths[column] / 2
		x = x + lane_widths[column]
	end
	local field_width = x - field_left
	local hit_y = self.upside_down and FIELD_HEIGHT - self.hit_position or self.hit_position
	local rate = math.max(player.rate or 1, 0.01)
	local time = player.time or 0

	lg.push("all")
	lg.translate(offset_x, offset_y)
	lg.scale(scale)
	lg.setColor(0.025, 0.03, 0.045, 0.94)
	lg.rectangle("fill", field_left, 0, field_width, FIELD_HEIGHT)
	for column = 1, math.min(self.columns, #preview.columns) do
		local source_column = column
		if player.column_map and player.column_map[column] then source_column = player.column_map[column] end
		local notes = preview.columns[source_column] or {}
		local display_column = column
		if player.input_mode == self.input_mode then
			display_column = self.input_map[self.base_inputs[column]] or column
		end
		if display_column <= self.columns then
			local suffix = self:getColumnSuffix(display_column - 1)
			local color = get_color(self.section, "Colour" .. display_column, {0, 0, 0, 1})
			local lane_x = lane_xs[display_column]
			local lane_width = lane_widths[display_column]
			lg.setColor(color[1], color[2], color[3], color[4])
			lg.rectangle("fill", lane_x - lane_width / 2, 0, lane_width, FIELD_HEIGHT)
			local lower = time - 1.5 / rate
			local upper = time + (self.upside_down and 1 or 1.5) / rate
			local first, last = preview:getVisibleRange(source_column, lower, upper)
			for index = first, last do
				local note = notes[index]
				if note and note.end_time >= lower then
					local start_y = hit_y + (time - note.time) * NOTE_SCROLL_SPEED * rate *
						(self.upside_down and -1 or 1)
					local end_y = hit_y + (time - note.end_time) * NOTE_SCROLL_SPEED * rate *
						(self.upside_down and -1 or 1)
					if note.end_time > note.time then
						local body = get_column_image(self, display_column - 1, suffix, "L")
						local top, bottom = math.min(start_y, end_y), math.max(start_y, end_y)
						if body and bottom > top then
							draw_image_rect(body, lane_x - lane_width / 2, top, lane_width, bottom - top,
								self.upside_down and self.note_flip)
						end
					end
					if note.time >= lower and note.time <= upper then
						local image = get_column_image(self, display_column - 1, suffix, "")
						if image then
							local note_width, note_height = self:getNoteDimensions(display_column, image)
							draw_note_head(image, lane_x, start_y, note_width, note_height,
								self.upside_down and self.note_flip, self.upside_down)
						end
					end
				end
			end
		end
	end
	self:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y)
	lg.pop()
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function OsuManiaRenderer:draw(width, height, transform)
	local engine = self.game.rhythm_engine
	local visual_engine = engine and engine.visual_engine
	if not visual_engine or self.columns == 0 then return end
	self:load()

	local scale, offset_x, offset_y = self:getFieldTransform(width, height)
	local field_left, column_widths, width_scale = self:getPlayfieldLayout()
	local field_width = 0
	for _, value in ipairs(column_widths) do field_width = field_width + value * width_scale end
	for index = 1, self.columns - 1 do
		field_width = field_width + (self.column_spacings[index] or 0) * width_scale
	end
	local lane_widths, lane_xs = {}, {}
	local x = field_left
	for column = 1, self.columns do
		if column > 1 then x = x + (self.column_spacings[column - 1] or 0) * width_scale end
		local lane_width = self.column_widths[column] * width_scale
		lane_xs[column] = x + lane_width / 2
		lane_widths[column] = lane_width
		x = x + lane_width
	end
	local hit_y = self.upside_down and FIELD_HEIGHT - self.hit_position or self.hit_position
	local hit_speed = NOTE_SCROLL_SPEED

	lg.push("all")
	lg.applyTransform(transform)
	lg.translate(offset_x, offset_y)
	lg.scale(scale)

	lg.setColor(0.025, 0.03, 0.045, 0.94)
	lg.rectangle("fill", field_left, 0, field_width, FIELD_HEIGHT)
	for column = 1, self.columns do
		local x_left = lane_xs[column] - lane_widths[column] / 2
		local color = get_color(self.section, "Colour" .. column, {0, 0, 0, 1})
		lg.setColor(color[1], color[2], color[3], color[4])
		lg.rectangle("fill", x_left, 0, lane_widths[column], FIELD_HEIGHT)
	end

	-- Lane dividers and the judgement line use osu!'s canonical 640x480 skin space.
	local line_color = get_color(self.section, "ColourColumnLine", {1, 1, 1, 1})
	for edge = 0, self.columns do
		local edge_x = edge == 0 and field_left or lane_xs[edge] + lane_widths[edge] / 2
		local line_width = (self.column_lines[edge + 1] or 0) * width_scale
		if line_width > 0 then
			lg.setColor(line_color[1], line_color[2], line_color[3], line_color[4] * 0.7)
			lg.rectangle("fill", edge_x - line_width / 2, 0, line_width, FIELD_HEIGHT)
		end
	end
	if self.judgement_line then
		local judgement_color = get_color(self.section, "ColourJudgementLine", {1, 1, 1, 1})
		lg.setColor(judgement_color[1], judgement_color[2], judgement_color[3], judgement_color[4] * 0.9)
		lg.rectangle("fill", field_left, hit_y - 1, field_width, 2)
	end

	if self.keys_under_notes then draw_keys(self, engine, lane_widths, lane_xs, hit_y) end

	-- Hold bodies render behind note heads. Visual-note deltas are in seconds;
	-- the 480px field preserves the renderer's established one-screen-per-second speed.
	for _, note in ipairs(visual_engine.visible_notes) do
		if note.type == "long" and note:getState() ~= "endPassed" then
			local column = self.input_map[note:getColumn()]
			if column and column >= 1 and column <= self.columns then
				local suffix = self:getColumnSuffix(column - 1)
				local body = get_column_image(self, column - 1, suffix, "L")
				local tail_image = get_column_image(self, column - 1, suffix, "T")
				local direction = self.upside_down and -1 or 1
				local head_y = hit_y + note.start_dt * hit_speed * direction
				local tail_y = hit_y + note.end_dt * hit_speed * direction
				if note:getState() == "startPassedPressed" then
					if self.upside_down then
						head_y = math.max(hit_y, head_y)
						tail_y = math.max(hit_y, tail_y)
					else
						head_y = math.min(hit_y, head_y)
						tail_y = math.min(hit_y, tail_y)
					end
				end
				local top, bottom = math.min(head_y, tail_y), math.max(head_y, tail_y)
				if body and bottom > top then
					local image_width, image_height = body:getDimensions()
					local note_width = lane_widths[column]
					local tail_height = 0
					if tail_image then
						local _, image_height_px = tail_image:getDimensions()
						tail_height = image_height_px * note_width / tail_image:getWidth()
					end
					local body_top = top + tail_height
					local body_bottom = math.max(body_top, bottom - tail_height)
					lg.setColor(1, 1, 1, 1)
					if tail_image then
						local flip_key = "NoteFlipWhenUpsideDown" .. (column - 1) .. "T"
						local flip_tail = self.upside_down and get_boolean(self.section, flip_key, self.note_flip)
						local tail_top = tail_y - tail_height
						draw_image_rect(tail_image, lane_xs[column] - note_width / 2, tail_top,
							note_width, tail_height, flip_tail)
					end
					if body_bottom > body_top then
						local flip_key = "NoteFlipWhenUpsideDown" .. (column - 1) .. "L"
						local flip_body = self.upside_down and get_boolean(self.section, flip_key, self.note_flip)
						draw_image_rect(body, lane_xs[column] - note_width / 2, body_top, note_width,
							body_bottom - body_top, flip_body)
					end
				elseif bottom > top then
					local color = get_color(self.section, "ColourHold", {1, 0.78, 0.2, 1})
					lg.setColor(color[1], color[2], color[3], color[4] * 0.8)
					lg.rectangle("fill", lane_xs[column] - lane_widths[column] * 0.32, top,
						lane_widths[column] * 0.64, bottom - top)
				end
			end
		end
	end

	for _, note in ipairs(visual_engine.visible_notes) do
		local state = note:getState()
		local head_visible = note.type == "long" and not state:find("^end") or note.type ~= "long" and state == "clear"
		if head_visible then
			local column = self.input_map[note:getColumn()]
			if column and column >= 1 and column <= self.columns then
				local suffix = self:getColumnSuffix(column - 1)
				local postfix = note.type == "long" and "H" or ""
				local image = get_column_image(self, column - 1, suffix, postfix)
				local direction = self.upside_down and -1 or 1
				local note_y = hit_y + note.start_dt * hit_speed * direction
				if state == "startPassedPressed" then
					if self.upside_down then note_y = math.max(hit_y, note_y)
					else note_y = math.min(hit_y, note_y) end
				end
				if image then
					local note_width, note_height = self:getNoteDimensions(column, image)
					local flip_key = "NoteFlipWhenUpsideDown" .. (column - 1) .. postfix
					local flip_value = get_section_value(self.section, flip_key)
					if not flip_value then
						flip_value = get_section_value(self.section, "NoteFlipWhenUpsideDown" .. (column - 1))
					end
					local flip = self.upside_down and get_boolean(self.section, flip_key, self.note_flip)
					draw_note_head(image, lane_xs[column], note_y, note_width, note_height,
						flip, self.upside_down)
				else
						local color = get_color(self.section, "ColourHold", {0.25, 0.72, 1, 1})
					lg.setColor(color[1], color[2], color[3], color[4])
					lg.rectangle("fill", lane_xs[column] - lane_widths[column] / 2, note_y - 10,
						lane_widths[column], 10)
				end
			end
		end
	end

	if not self.keys_under_notes then draw_keys(self, engine, lane_widths, lane_xs, hit_y) end
	self:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y)
	lg.pop()

	-- Keep score, accuracy, combo, and progress above every playfield element.
	self.hud:draw(self, width, height, transform, field_left, field_width)
end

return OsuManiaRenderer

