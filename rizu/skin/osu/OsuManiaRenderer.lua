local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local Hud = require("rizu.skin.Hud")
local OsuManiaScoreView = require("rizu.skin.osu.mania.OsuManiaScoreView")
local OsuManiaAccuracyView = require("rizu.skin.osu.mania.OsuManiaAccuracyView")
local OsuManiaComboView = require("rizu.skin.osu.mania.OsuManiaComboView")
local OsuManiaJudgeView = require("rizu.skin.osu.mania.OsuManiaJudgeView")
local OsuManiaHitMeterView = require("rizu.skin.osu.mania.OsuManiaHitMeterView")
local OsuManiaProgressView = require("rizu.skin.osu.mania.OsuManiaProgressView")
local OsuManiaSkinGraphics = require("rizu.skin.osu.mania.OsuManiaSkinGraphics")
local OsuManiaFieldRenderer = require("rizu.skin.osu.mania.OsuManiaFieldRenderer")
local OsuManiaKeyRenderer = require("rizu.skin.osu.mania.OsuManiaKeyRenderer")
local OsuManiaNoteRenderer = require("rizu.skin.osu.mania.OsuManiaNoteRenderer")
local OsuManiaStageRenderer = require("rizu.skin.osu.mania.OsuManiaStageRenderer")
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
---@field stage_under_keys boolean Draw stage decorations below keys when true.
---@field judgement_line boolean
---@field note_flip boolean
---@field key_flip boolean
---@field scratch_on_left boolean
---@field engine_input_map {[chart.Column]: integer}
---@field field_renderer rizu.skin.osu.mania.OsuManiaFieldRenderer
---@field key_renderer rizu.skin.osu.mania.OsuManiaKeyRenderer
---@field note_renderer rizu.skin.osu.mania.OsuManiaNoteRenderer
---@field stage_renderer rizu.skin.osu.mania.OsuManiaStageRenderer
---@field hud rizu.skin.Hud
---@field conveyor_hud rizu.skin.Hud
---@field _conveyor_hud_transform love.Transform
---@field score_view rizu.skin.osu.mania.OsuManiaScoreView
---@field accuracy_view rizu.skin.osu.mania.OsuManiaAccuracyView
---@field combo_view rizu.skin.osu.mania.OsuManiaComboView
---@field judge_view rizu.skin.osu.mania.OsuManiaJudgeView
---@field hit_meter_view rizu.skin.osu.mania.OsuManiaHitMeterView
---@field progress_view rizu.skin.osu.mania.OsuManiaProgressView
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
	self.score_view = OsuManiaScoreView(self.skin_graphics)
	self.accuracy_view = OsuManiaAccuracyView(self.skin_graphics)
	self.combo_view = OsuManiaComboView(self.skin_graphics)
	self.judge_view = OsuManiaJudgeView(self.skin_graphics)
	self.hit_meter_view = OsuManiaHitMeterView()
	self.progress_view = OsuManiaProgressView()
	self.hud = Hud({width = FIELD_WIDTH, height = FIELD_HEIGHT})
	self.conveyor_hud = Hud({width = FIELD_WIDTH, height = FIELD_HEIGHT})
	self._conveyor_hud_transform = love.math.newTransform()
	self.hud:add(self.score_view)
	self.hud:add(self.accuracy_view)
	self.hud:add(self.progress_view)
	self.conveyor_hud:add(self.combo_view)
	self.conveyor_hud:add(self.judge_view)
	self.conveyor_hud:add(self.hit_meter_view)
	self.hud:load(game)
	self.conveyor_hud:load(game)
	self.field_renderer = OsuManiaFieldRenderer()
	self.key_renderer = OsuManiaKeyRenderer()
	self.note_renderer = OsuManiaNoteRenderer()
	self.stage_renderer = OsuManiaStageRenderer()
	local graphics = self.game.packageManager
	local osu_ui_directory = graphics and graphics:getPackageDir("osu_ui")
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
	self.stage_under_keys = true
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
	self.score_view:setSkin(skin)
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
	self.combo_view:setSkin(skin, section)
	self.judge_view:setSkin(skin, section)
	self.accuracy_view:setSkin(skin, self.score_view.height + 3)
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
	self.stage_under_keys = get_boolean(section, "StageUnderKeys", true)
	self.judgement_line = get_boolean(section, "JudgementLine", false)
	self.note_flip = get_boolean(section, "NoteFlipWhenUpsideDown", true)
	self.key_flip = get_boolean(section, "KeyFlipWhenUpsideDown", true)
	self.scratch_on_left = get_boolean(section, "ScratchOnLeft", false)
	self.split_stages = get_boolean(section, "SplitStages", self.columns >= 10)
	self.stage_separation = math.max(5, get_number(section, "StageSeparation", 40))
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

function OsuManiaRenderer:updateHud(dt)
	self.hud:update(dt, self.game)
	self.conveyor_hud:update(dt, self.game)
end

function OsuManiaRenderer:update(dt)
	self.field_renderer:update(dt)
	self.key_renderer:update(dt)
	self.note_renderer:update(dt)
	self.stage_renderer:update(dt)
end

function OsuManiaRenderer:load()
	local skin = self:getSkin()
	if self.skin ~= skin then self:loadSkinSettings(skin) end
	self.hud:load(self.game)
	self.conveyor_hud:load(self.game)
	if self.skin_graphics.skin ~= skin then self.skin_graphics:setSkin(skin) end
	if not self.skin_graphics.loaded then
		self.skin_graphics:load(self:getSkinAssets())
	end
	self.score_view:refreshSize()
	self.accuracy_view:setSkin(skin, self.score_view.height)
end

function OsuManiaRenderer:unload()
	self.hud:unload(self.game)
	self.conveyor_hud:unload(self.game)
	self.skin_graphics:unload()
end

---@param width number
---@param height number
---@return number scale
---@return number offset_x
---@return number offset_y
function OsuManiaRenderer:getFieldTransform(width, height)
	local scale = math.max(0, math.min(width / FIELD_WIDTH, height / FIELD_HEIGHT))
	-- osu!'s legacy mania transform scales from the viewport's left edge; the
	-- 640px reference canvas is not centered in the remaining horizontal space.
	return scale, 0, (height - FIELD_HEIGHT * scale) / 2
end

---@return number left
---@return number[] widths
---@return number scale
---@return number full_width
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
	return left, widths, scale, full_width
end

---@return {name: string?, fallback: string?, animation: boolean?}[]
function OsuManiaRenderer:getSkinAssets()
	local assets, seen = {}, {}
	local function add(name, fallback, animation)
		if (not name or name == "") and (not fallback or fallback == "") then return end
		local key = tostring(name or ""):lower() .. "\0" .. tostring(fallback or ""):lower()
		local existing = seen[key]
		if existing then
			existing.animation = existing.animation or animation
			return
		end
		local asset = {name = name, fallback = fallback, animation = animation}
		seen[key] = asset
		assets[#assets + 1] = asset
	end

	for column = 1, self.columns do
		local zero_based_column = column - 1
		local suffix = self:getColumnSuffix(zero_based_column)
		for _, postfix in ipairs({"", "H", "L", "T"}) do
			local animated = postfix == "L"
			add(get_section_value(self.section, "NoteImage" .. zero_based_column .. postfix), nil, animated)
			if postfix == "H" or postfix == "T" then
				add(get_section_value(self.section, "NoteImage" .. zero_based_column .. "H"))
				add(get_section_value(self.section, "NoteImage" .. zero_based_column))
			end
			local fallback = "mania-note" .. suffix .. postfix
			add(fallback, nil, animated)
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

	local score_images = self.score_view:getImageAssets()
	for _, name in ipairs(score_images) do add(name) end
	for _, name in ipairs(self.accuracy_view:getImageAssets()) do add(name) end
	for _, name in ipairs(self.combo_view:getImageAssets()) do add(name) end
	for _, asset in ipairs(self.judge_view:getImageAssets()) do
		local name = asset.name or asset.fallback
		local fallback = asset.name and asset.fallback or nil
		add(name, fallback, true)
	end
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

---@param key string
---@return string?
function OsuManiaRenderer:getSkinValue(key)
	return get_section_value(self.section, key)
end

---@param key string
---@param default boolean
---@return boolean
function OsuManiaRenderer:getBoolean(key, default)
	return get_boolean(self.section, key, default)
end

---@param key string
---@param fallback number[]
---@return number[]
function OsuManiaRenderer:getSkinColor(key, fallback)
	return get_color(self.section, key, fallback)
end

---@param name string?
---@return love.Image?
function OsuManiaRenderer:getFirstFrame(name)
	return self.skin_graphics:getFrames(name, nil)[1]
end

---@param column integer
---@param suffix string
---@param postfix string
---@return love.Image[]
function OsuManiaRenderer:getColumnFrames(column, suffix, postfix)
	local graphics = self.skin_graphics
	local animated = postfix == "L"
	local function find(name)
		if not name then return {} end
		if animated and graphics.getAnimationFrames then
			return graphics:getAnimationFrames(name, nil)
		end
		return graphics:getFrames(name, nil)
	end

	local frames = find(get_section_value(self.section, "NoteImage" .. column .. postfix))
	if #frames > 0 then return frames end
	if postfix == "H" or postfix == "T" then
		frames = find(get_section_value(self.section, "NoteImage" .. column .. "H"))
		if #frames > 0 then return frames end
		frames = find(get_section_value(self.section, "NoteImage" .. column))
		if #frames > 0 then return frames end
	end

	frames = find("mania-note" .. suffix .. postfix)
	if #frames > 0 then return frames end
	if postfix == "H" or postfix == "T" then
		return graphics:getFrames("mania-note" .. suffix, nil)
	end
	return {}
end

---@param column integer
---@param suffix string
---@param postfix string
---@return love.Image?
function OsuManiaRenderer:getColumnImage(column, suffix, postfix)
	return self:getColumnFrames(column, suffix, postfix)[1]
end

---@param note table
---@param frame_count integer
---@return integer
function OsuManiaRenderer:getNoteBodyFrame(note, frame_count)
	local state = note:getState()
	if frame_count <= 1 or (state ~= "startPassedPressed" and state ~= "startMissedPressed") then return 1 end
	local pressed_time = note.getPressedTime and note:getPressedTime()
	local visual_info = note.visual_info
	local current_time = visual_info and visual_info.getTime and visual_info:getTime()
	if not pressed_time or not current_time then return 1 end
	local elapsed = math.max(0, current_time - pressed_time)
	return math.floor(elapsed / 0.03) % frame_count + 1
end


---@param engine rizu.RhythmEngine
---@param lane_widths number[]
---@param lane_xs number[]
---@param hit_y number
function OsuManiaRenderer:drawKeys(engine, lane_widths, lane_xs, hit_y)
	self.key_renderer:draw(self, engine, lane_widths, lane_xs, hit_y)
end

---@param field_left number
---@param field_width number
---@param lane_widths number[]
---@param lane_xs number[]
---@param hit_y number
function OsuManiaRenderer:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y)
	self.stage_renderer:draw(self, field_left, field_width, lane_widths, lane_xs, hit_y)
end

---@param notes {column: integer, long_note: boolean, head_y: number, tail_y: number, body_visible: boolean, body_frame: integer?, head_visible: boolean}[]
---@param lane_widths number[]
---@param lane_xs number[]
function OsuManiaRenderer:drawNoteList(notes, lane_widths, lane_xs)
	self.note_renderer:draw(self, notes, lane_widths, lane_xs)
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
	local lower = time - 1.5 / rate
	local upper = time + (self.upside_down and 1 or 1.5) / rate
	local notes_to_draw = {}

	lg.push("all")
	lg.translate(offset_x, offset_y)
	lg.scale(scale)
	self.field_renderer:drawBackground(self, field_left, field_width)
	for column = 1, math.min(self.columns, #preview.columns) do
		local source_column = column
		if player.column_map and player.column_map[column] then source_column = player.column_map[column] end
		local notes = preview.columns[source_column] or {}
		local display_column = column
		if player.input_mode == self.input_mode then
			display_column = self.input_map[self.base_inputs[column]] or column
		end
		if display_column <= self.columns then
			local lane_x = lane_xs[display_column]
			local lane_width = lane_widths[display_column]
			self.field_renderer:drawLane(self, display_column, lane_width, lane_x)
			local first, last = preview:getVisibleRange(source_column, lower, upper)
			for index = first, last do
				local note = notes[index]
				if note and note.end_time >= lower then
					local direction = self.upside_down and -1 or 1
					local head_y = hit_y + (time - note.time) * NOTE_SCROLL_SPEED * rate * direction
					local tail_y = hit_y + (time - note.end_time) * NOTE_SCROLL_SPEED * rate * direction
					notes_to_draw[#notes_to_draw + 1] = {
						column = display_column,
						long_note = note.end_time > note.time,
						head_y = head_y,
						tail_y = tail_y,
						body_visible = note.end_time > note.time,
						head_visible = note.time >= lower and note.time <= upper,
					}
				end
			end
		end
	end
	if self.stage_under_keys then
		self:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y)
	end
	self:drawNoteList(notes_to_draw, lane_widths, lane_xs)
	if not self.stage_under_keys then
		self:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y)
	end
	lg.pop()
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function OsuManiaRenderer:drawHud(width, height, transform)
	local scale, offset_x, offset_y = self:getFieldTransform(width, height)
	local field_left, _, column_scale, field_width = self:getPlayfieldLayout()
	self:drawHudInViewport(transform, width, height, scale)
	if scale <= 0 then return end

	local conveyor_width = field_width * column_scale
	self._conveyor_hud_transform:reset()
	self._conveyor_hud_transform:apply(transform)
	self._conveyor_hud_transform:translate(offset_x, offset_y)
	self._conveyor_hud_transform:scale(scale)
	-- Match the first lane's transform and give the HUD the complete lane span,
	-- including all inter-column gaps.
	self._conveyor_hud_transform:translate(field_left, 0)
	self.conveyor_hud:draw(conveyor_width, FIELD_HEIGHT, self._conveyor_hud_transform)
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

	self.field_renderer:drawBackground(self, field_left, field_width)
	self.field_renderer:drawLanes(self, lane_widths, lane_xs)
	self.field_renderer:drawGuides(self, field_left, field_width, lane_widths, lane_xs, hit_y, width_scale)

	if self.stage_under_keys then self:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y) end
	if self.keys_under_notes then self:drawKeys(engine, lane_widths, lane_xs, hit_y) end

	local notes_to_draw = {}
	for _, note in ipairs(visual_engine.visible_notes) do
		local state = note:getState()
		local long_note = note.type == "long"
		local column = self.input_map[note:getColumn()]
		if column and column >= 1 and column <= self.columns then
			local direction = self.upside_down and -1 or 1
			local head_y = hit_y + note.start_dt * hit_speed * direction
			local tail_y = hit_y + (long_note and note.end_dt or note.start_dt) * hit_speed * direction
			if state == "startPassedPressed" then
				if self.upside_down then
					head_y = math.max(hit_y, head_y)
					tail_y = math.max(hit_y, tail_y)
				else
					head_y = math.min(hit_y, head_y)
					tail_y = math.min(hit_y, tail_y)
				end
			end
			local head_visible = long_note and not state:find("^end")
				or not long_note and state == "clear"
			notes_to_draw[#notes_to_draw + 1] = {
				column = column,
				long_note = long_note,
				head_y = head_y,
				tail_y = tail_y,
				body_visible = long_note and state ~= "endPassed",
				body_frame = long_note and self:getNoteBodyFrame(note, #self:getColumnFrames(column - 1,
					self:getColumnSuffix(column - 1), "L")) or 1,
				head_visible = head_visible,
			}
		end
	end
	self:drawNoteList(notes_to_draw, lane_widths, lane_xs)

	if not self.keys_under_notes then self:drawKeys(engine, lane_widths, lane_xs, hit_y) end
	if not self.stage_under_keys then self:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y) end
	lg.pop()
end

return OsuManiaRenderer

