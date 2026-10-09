local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local Hud = require("rizu.skin.Hud")
local BgaView = require("rizu.skin.views.BgaView")
local OsuManiaScoreView = require("rizu.skin.osu.mania.views.OsuManiaScoreView")
local OsuManiaAccuracyView = require("rizu.skin.osu.mania.views.OsuManiaAccuracyView")
local OsuManiaComboView = require("rizu.skin.osu.mania.views.OsuManiaComboView")
local OsuManiaJudgeView = require("rizu.skin.osu.mania.views.OsuManiaJudgeView")
local OsuManiaHitMeterView = require("rizu.skin.osu.mania.views.OsuManiaHitMeterView")
local OsuManiaProgressView = require("rizu.skin.osu.mania.views.OsuManiaProgressView")
local OsuSkinGraphics = require("rizu.skin.osu.OsuSkinGraphics")
local OsuManiaFieldRenderer = require("rizu.skin.osu.mania.OsuManiaFieldRenderer")
local OsuManiaKeyRenderer = require("rizu.skin.osu.mania.OsuManiaKeyRenderer")
local OsuManiaNoteRenderer = require("rizu.skin.osu.mania.OsuManiaNoteRenderer")
local OsuManiaStageRenderer = require("rizu.skin.osu.mania.OsuManiaStageRenderer")
local OsuManiaLighting = require("rizu.skin.osu.mania.OsuManiaLighting")
local OsuManiaSkinAssetFinder = require("rizu.skin.osu.mania.OsuManiaSkinAssetFinder")
local OsuManiaBatchPlan = require("rizu.skin.osu.mania.OsuManiaBatchPlan")
local InputMode = require("chart.core.InputMode")
local Settings = require("rizu.config.Settings")
local SkinConfig = require("rizu.skin.SkinConfig")
local OsuImage = require("rizu.skin.osu.OsuImage")
local table_util = require("table_util")

local lg = love.graphics
local MANIA_HEIGHT_SCALE = 480 / 768
local FIELD_WIDTH, FIELD_HEIGHT = 640, 480
local DEFAULT_COLUMN_WIDTH = 30
local DEFAULT_COLUMN_START = 136
local DEFAULT_COLUMN_RIGHT = 19
local DEFAULT_HIT_POSITION = 402
local DEFAULT_HIT_METER_MODE = 0
local NOTE_SCROLL_SPEED = FIELD_HEIGHT
local EMPTY_FRAMES = {}

---@class rizu.skin.osu.OsuManiaRenderer.Property
---@field key string
---@field label string
---@field min number
---@field max number
---@field step number
---@field value_format fun(value: number): string
---@field get fun(): number
---@field set fun(value: number)

---@class rizu.skin.osu.OsuManiaRenderer.ColumnKeys
---@field up rizu.skin.osu.OsuSkinGraphics.Image?
---@field down rizu.skin.osu.OsuSkinGraphics.Image?
---@field up_flip boolean
---@field down_flip boolean

---@class rizu.skin.osu.OsuManiaRenderer : rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.skin.osu.OsuManiaRenderer
---@field skin_graphics rizu.skin.osu.OsuSkinGraphics
---@field batch_plan rizu.skin.osu.mania.OsuManiaBatchPlan
---@field skin rizu.skin.OsuSkinDiscovery?
---@field section rizu.skin.OsuSkinIni.ManiaSection
---@field config rizu.skin.SkinConfig
---@field config_path string?
---@field columns integer
---@field column_widths number[]
---@field column_spacings number[]
---@field column_lines number[]
---@field column_start number
---@field column_right number
---@field hit_position number
---@field special_style integer
---@field note_height_scale number
---@field note_body_styles string[]
---@field default_note_body_style string
---@field upside_down boolean
---@field keys_under_notes boolean
---@field stage_under_keys boolean Draw stage decorations below keys when true.
---@field judgement_line boolean
---@field note_flip boolean
---@field key_flip boolean
---@field engine_input_map {[chart.Column]: integer}
---@field field_renderer rizu.skin.osu.mania.OsuManiaFieldRenderer
---@field key_renderer rizu.skin.osu.mania.OsuManiaKeyRenderer
---@field note_renderer rizu.skin.osu.mania.OsuManiaNoteRenderer
---@field stage_renderer rizu.skin.osu.mania.OsuManiaStageRenderer
---@field foreground_hud rizu.skin.Hud?
---@field conveyor_hud rizu.skin.Hud
---@field private conveyor_hud_transform love.Transform
---@field score_view rizu.skin.osu.mania.views.OsuManiaScoreView
---@field accuracy_view rizu.skin.osu.mania.views.OsuManiaAccuracyView
---@field combo_view rizu.skin.osu.mania.views.OsuManiaComboView
---@field judge_view rizu.skin.osu.mania.views.OsuManiaJudgeView
---@field hit_meter_view rizu.skin.osu.mania.views.OsuManiaHitMeterView
---@field progress_view rizu.skin.osu.mania.views.OsuManiaProgressView
---@field split_stages boolean
---@field stage_separation number
---@field light_position number
---@field light_frame_rate number
---@field lighting_n_widths number[]
---@field lighting_l_widths number[]
---@field stage_lightings rizu.skin.osu.mania.OsuManiaLighting[]
---@field hit_lightings {[integer]: {short: rizu.skin.osu.mania.OsuManiaLighting?, long: rizu.skin.osu.mania.OsuManiaLighting?}}
---@field lighting_notes {[table]: boolean}
---@field lighting_skin rizu.skin.OsuSkinDiscovery?
---@field lighting_loaded boolean
---@field scratch_count integer
---@field scratch_columns {[integer]: boolean}
---@field private lane_widths number[]
---@field private lane_xs number[]
---@field private notes_to_draw table[]
---@field private note_draw_pool table[]
---@field private active_long {[integer]: boolean}
---@field private skin_colors {[string]: number[]}
---@field private column_suffixes {[integer]: "1"|"2"|"S"}
---@field private column_frames {[integer]: {[string]: rizu.skin.osu.OsuSkinGraphics.Image[]}}
---@field private column_keys {[integer]: rizu.skin.osu.OsuManiaRenderer.ColumnKeys}
---@field private note_body_flips boolean[]
---@field private note_head_flips boolean[]
---@field private note_short_flips boolean[]
---@field private lane_colors {[integer]: number[]}
---@field private playfield_width_scale number
---@field private note_base_width number
local OsuManiaRenderer = PlayfieldRenderer + {}
OsuManiaRenderer.field_width = FIELD_WIDTH
OsuManiaRenderer.field_height = FIELD_HEIGHT

---@param game sphere.GameController
---@param input_mode string?
---@param skin_path string?
---@param config rizu.skin.SkinConfig?
---@param config_path string?
function OsuManiaRenderer:new(game, input_mode, skin_path, config, config_path)
	PlayfieldRenderer.new(self, game)
	self.background_hud:add(BgaView(game))
	self.input_mode = input_mode or "4key"
	self.skin_path = skin_path
	self.config = config or SkinConfig()
	self.config_path = config_path
	local mode = InputMode(self.input_mode)
	self.inputs = mode:getInputs()
	self.base_inputs = mode:getInputs()
	self.engine_input_map = mode:getInputMap()
	self.input_map = self.engine_input_map
	self.skin_graphics = OsuSkinGraphics(game.fs)
	self.batch_plan = OsuManiaBatchPlan()
	self.score_view = OsuManiaScoreView(self.skin_graphics)
	self.accuracy_view = OsuManiaAccuracyView(self.skin_graphics)
	self.combo_view = OsuManiaComboView(self.skin_graphics)
	self.judge_view = OsuManiaJudgeView(self.skin_graphics)
	self.hit_meter_view = OsuManiaHitMeterView(self.skin_graphics)
	self.progress_view = OsuManiaProgressView(self.skin_graphics)
	self.foreground_hud = Hud({width = FIELD_WIDTH, height = FIELD_HEIGHT})
	self.conveyor_hud = Hud({width = FIELD_WIDTH, height = FIELD_HEIGHT})
	self.conveyor_hud_transform = love.math.newTransform()
	self.foreground_hud:add(self.score_view)
	self.foreground_hud:add(self.accuracy_view)
	self.foreground_hud:add(self.progress_view)
	self.conveyor_hud:add(self.combo_view)
	self.conveyor_hud:add(self.judge_view)
	self.conveyor_hud:add(self.hit_meter_view)
	self.field_renderer = OsuManiaFieldRenderer()
	self.key_renderer = OsuManiaKeyRenderer()
	self.note_renderer = OsuManiaNoteRenderer()
	self.stage_renderer = OsuManiaStageRenderer()
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
	self.note_body_styles = {}
	self.default_note_body_style = "stretch"
	self.upside_down = false
	self.keys_under_notes = false
	self.stage_under_keys = true
	self.judgement_line = true
	self.note_flip = true
	self.key_flip = true
	self.split_stages = false
	self.stage_separation = 40
	self.light_position = 413
	self.light_frame_rate = 60
	self.lighting_n_widths = {}
	self.lighting_l_widths = {}
	self.stage_lightings = {}
	self.hit_lightings = {}
	self.lighting_notes = setmetatable({}, {__mode = "k"})
	self.lighting_skin = nil
	self.lighting_loaded = false
	self.lighting_input_state = {}
	self.scratch_count = 0
	self.scratch_columns = {}
	self.lane_widths = {}
	self.lane_xs = {}
	self.notes_to_draw = {}
	self.note_draw_pool = {}
	self.active_long = {}
	self.skin_colors = {}
	self.column_suffixes = {}
	self.column_frames = {}
	self.column_keys = {}
	self.note_body_flips = {}
	self.note_head_flips = {}
	self.note_short_flips = {}
	self.lane_colors = {}
	self.playfield_width_scale = 1
	self.note_base_width = DEFAULT_COLUMN_WIDTH
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

---@param columns integer
---@param scratch_count integer
---@param special_style integer
---@return {[integer]: boolean}
local function get_scratch_columns(columns, scratch_count, special_style)
	local scratch_columns = {}
	if special_style == 1 then
		if scratch_count == 1 then
			scratch_columns[1] = true
		elseif scratch_count == 2 then
			scratch_columns[1] = true
			scratch_columns[columns] = true
		end
	elseif special_style == 2 then
		if scratch_count == 1 then
			scratch_columns[columns] = true
		elseif scratch_count == 2 then
			local center = math.floor(columns / 2)
			scratch_columns[center] = true
			scratch_columns[center + 1] = true
		end
	end
	return scratch_columns
end

---@param inputs chart.Column[]
---@param special_style integer
---@return chart.Column[]
local function reorder_scratch_inputs(inputs, special_style)
	local scratches, keys = {}, {}
	for _, input in ipairs(inputs) do
		if input:lower():match("^scratch%d+$") then
			scratches[#scratches + 1] = input
		else
			keys[#keys + 1] = input
		end
	end

	local scratch_columns = get_scratch_columns(#inputs, #scratches, special_style)
	if not next(scratch_columns) then return inputs end

	local reordered = {}
	local scratch_index, key_index = 1, 1
	for column = 1, #inputs do
		if scratch_columns[column] then
			reordered[column] = scratches[scratch_index]
			scratch_index = scratch_index + 1
		else
			reordered[column] = keys[key_index]
			key_index = key_index + 1
		end
	end
	return reordered
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
	self.skin_colors = {}
	self.combo_view:setSkin(skin, section)
	self.judge_view:setSkin(skin, section)
	self.hit_meter_view:setMode(self:getHitMeterMode())
	self.accuracy_view:setSkin(skin, self.score_view.height + 3)
	self.progress_view:setAccuracyView(self.accuracy_view)
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
	local general = skin and skin.skin_ini and skin.skin_ini.General
	local version_value = general and get_section_value(general, "Version")
	local version = tonumber(version_value)
	if version_value and version_value:lower() == "latest" then version = 2.6 end
	self.default_note_body_style = version and version >= 2.5 and "repeat_bottom" or "stretch"
	self.note_body_styles = {}
	for column = 1, columns do
		local style = get_section_value(section, "NoteBodyStyle" .. (column - 1))
			or get_section_value(section, "NoteBodyStyle")
		local style_number = tonumber(style)
		self.note_body_styles[column] = style_number == 2 and "repeat_top"
			or style_number == 3 and "repeat_bottom"
			or style_number == 4 and "repeat_top_and_bottom"
			or style_number == 0 and "stretch"
			or self.default_note_body_style
	end
	self.upside_down = get_boolean(section, "UpsideDown", false)
	self.keys_under_notes = get_boolean(section, "KeysUnderNotes", false)
	self.stage_under_keys = get_boolean(section, "StageUnderKeys", true)
	self.judgement_line = get_boolean(section, "JudgementLine", false)
	self.note_flip = get_boolean(section, "NoteFlipWhenUpsideDown", true)
	self.key_flip = get_boolean(section, "KeyFlipWhenUpsideDown", true)
	self.split_stages = get_boolean(section, "SplitStages", self.columns >= 10)
	self.stage_separation = math.max(5, get_number(section, "StageSeparation", 40))
	self.light_position = math.max(0, math.min(FIELD_HEIGHT, get_number(section, "LightPosition", 413)))
	self.light_frame_rate = math.max(1, get_number(section, "LightFramePerSecond", 60))
	self.lighting_n_widths = get_number_list(section, "LightingNWidth", columns, 0, 0, math.huge)
	self.lighting_l_widths = get_number_list(section, "LightingLWidth", columns, 0, 0, math.huge)
	self.stage_lightings = {}
	self.hit_lightings = {}
	self.lighting_notes = setmetatable({}, {__mode = "k"})
	self.lighting_skin = nil
	self.lighting_loaded = false
	self.lighting_input_state = {}
	if self.split_stages and columns > 1 then
		local split = math.floor(columns / 2)
		self.column_spacings[split] = math.max(self.column_spacings[split] or 0, self.stage_separation)
	end

	local skin_inputs = get_section_value(section, "Inputs" .. self.input_mode)
	if skin_inputs then
		local reordered = {}
		for input in (skin_inputs .. ","):gmatch("(.-),") do
			input = input:match("^%s*(.-)%s*$")
			if input ~= "" then reordered[#reordered + 1] = input end
		end
		if #reordered == columns then self.inputs = reordered end
	end
	self.inputs = reorder_scratch_inputs(self.inputs, self.special_style)
	self.scratch_count = 0
	for _, input in ipairs(self.inputs) do
		if input:lower():match("^scratch%d+$") then self.scratch_count = self.scratch_count + 1 end
	end
	self.scratch_columns = get_scratch_columns(self.columns, self.scratch_count, self.special_style)
	local inputs = {}
	for column, input in ipairs(self.inputs) do inputs[input] = column end
	self.input_map = inputs
	self.column_suffixes = {}
	self.column_frames = {}
	self.column_keys = {}
	self.note_body_flips = {}
	self.note_head_flips = {}
	self.note_short_flips = {}
	self.lane_colors = {}
	for column = 1, columns do
		self:getColumnSuffix(column - 1)
		self:getNoteBodyFlip(column)
		self:getNoteHeadFlip(column, true)
		self:getNoteHeadFlip(column, false)
		self:getColumnLineColor(column)
	end
	local _, _, width_scale = self:getPlayfieldLayout()
	self.playfield_width_scale = width_scale
	local base_width = self.note_height_scale
	if base_width <= 0 then
		base_width = math.huge
		for lane = 1, columns do
			base_width = math.min(base_width, self.column_widths[lane] or DEFAULT_COLUMN_WIDTH)
		end
		if base_width == math.huge then base_width = DEFAULT_COLUMN_WIDTH end
	end
	self.note_base_width = base_width
end

function OsuManiaRenderer:updateHud(dt)
	if self.foreground_hud then self.foreground_hud:update(dt, self.game) end
	self.conveyor_hud:update(dt, self.game)
end

function OsuManiaRenderer:update(dt)
	self.field_renderer:update(dt)
	self.key_renderer:update(dt)
	self.note_renderer:update(dt)
	self.stage_renderer:update(dt)
	for column = 1, self.columns do
		local stage_lighting = self.stage_lightings[column]
		if stage_lighting then stage_lighting:update(dt) end
		local hit_lighting = self.hit_lightings[column]
		if hit_lighting then
			if hit_lighting.short then hit_lighting.short:update(dt) end
			if hit_lighting.long then hit_lighting.long:update(dt) end
		end
	end
end

function OsuManiaRenderer:load()
	local skin = self:getSkin()
	if self.skin == skin and self.skin_graphics.loaded
		and self.skin_graphics.skin == skin
		and self.skin_graphics.fallback_archive == "resources/osu_default_assets.zip" then return end

	-- Consumers release their references before the graphics owner releases GPU
	-- resources. Acquire the HUD only after the complete skin has been uploaded.
	self.foreground_hud:unload(self.game)
	self.conveyor_hud:unload(self.game)
	self.skin_graphics:setFallbackArchive("resources/osu_default_assets.zip")
	if self.skin_graphics.skin ~= skin then self.skin_graphics:setSkin(skin) end
	if self.skin ~= skin then self:loadSkinSettings(skin) end
	if not self.skin_graphics.loaded then
		local limits = love.graphics.getSystemLimits()
		local texture_limit = limits.texturesize > 0 and limits.texturesize or 4096
		self.skin_graphics:setTextureLimit(texture_limit)
		self.skin_graphics:setAtlasLimit(math.min(4096, texture_limit))
		self.skin_graphics:load(self:getSkinAssets())
	end
	self:loadLightings()
	self.foreground_hud:load(self.game)
	self.conveyor_hud:load(self.game)
	self.accuracy_view.y = self.score_view.height + 3
	self.progress_view:setAccuracyView(self.accuracy_view)
end

function OsuManiaRenderer:unload()
	if self.foreground_hud then self.foreground_hud:unload(self.game) end
	self.conveyor_hud:unload(self.game)
	self.skin_graphics:unload()
	self.stage_lightings = {}
	self.hit_lightings = {}
	self.lighting_skin = nil
	self.lighting_loaded = false
	self.lighting_input_state = {}
	self.column_frames = {}
	self.column_keys = {}
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
	local widths = self.column_widths
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

---@param name string?
---@param fallback string
---@return rizu.skin.osu.OsuSkinGraphics.Image[]
function OsuManiaRenderer:getLightingFrames(name, fallback)
	if self.skin_graphics.getAnimationFrames then
		return self.skin_graphics:getAnimationFrames(name, fallback, "standalone")
	end
	return self.skin_graphics:getFrames(name, fallback, "standalone")
end

---@param frames rizu.skin.osu.OsuSkinGraphics.Image[]
---@return number
local function getLightingFrameRate(frames)
	-- osu! advances hit-light animations over 170 ms, but never faster than
	-- the historical 60 Hz update interval.
	return math.min(#frames / 0.17, 60)
end

---@param key string
---@param fallback number[]
---@return number[]
function OsuManiaRenderer:getLightingColor(key, fallback)
	return self:getSkinColor(key, fallback)
end

function OsuManiaRenderer:loadLightings()
	if self.lighting_loaded and self.lighting_skin == self.skin then return end
	self.stage_lightings = {}
	self.hit_lightings = {}
	self.lighting_notes = setmetatable({}, {__mode = "k"})
	self.lighting_skin = self.skin
	if not self.skin_graphics.loaded then return end

	local function get_name(key)
		local name = get_section_value(self.section, key)
		if name and tonumber(name) then return nil end
		return name
	end

	local stage_frames = self:getLightingFrames(get_name("StageLight"), "mania-stage-light")
	local normal_frames = self:getLightingFrames(get_name("LightingN"), "lightingN")
	local long_frames = self:getLightingFrames(get_name("LightingL"), "lightingL")
	if #long_frames == 0 then long_frames = normal_frames end

	local _, _, width_scale = self:getPlayfieldLayout()
	for column = 1, self.columns do
		local lane_width = (self.column_widths[column] or DEFAULT_COLUMN_WIDTH) * width_scale
		local stage_color = self:getLightingColor("ColourLight" .. column, {55 / 255, 1, 1, 1})
		if #stage_frames > 0 then
			local image_width, image_height = OsuImage.dimensions(stage_frames[1])
			if image_width > 0 and image_height > 0 then
				self.stage_lightings[column] = OsuManiaLighting({
					frames = stage_frames,
					mode = "stage",
					frame_rate = self.light_frame_rate,
					width = lane_width,
					scale_y = FIELD_HEIGHT / 768,
					color = stage_color,
					origin_x = 0,
					origin_y = 1,
				})
			end
		end

		local normal = nil
		if #normal_frames > 0 then
			local image_width = OsuImage.dimensions(normal_frames[1])
			local lighting_width = self.lighting_n_widths[column] > 0
				and self.lighting_n_widths[column] * width_scale or lane_width
			if image_width > 0 then
				normal = OsuManiaLighting({
					frames = normal_frames,
					mode = "oneshot",
					frame_rate = getLightingFrameRate(normal_frames),
					width = image_width * lighting_width / 30 * MANIA_HEIGHT_SCALE,
					scale_y = lighting_width / 30 * MANIA_HEIGHT_SCALE,
					color = {1, 1, 1, 1},
					origin_x = 0.5,
					origin_y = 0.5,
					duration = 0.2,
					fade_in = 0.08,
					fade_out = 0.12,
				})
			end
		end

		local long = nil
		if #long_frames > 0 then
			local image_width = OsuImage.dimensions(long_frames[1])
			local lighting_width = self.lighting_l_widths[column] > 0
				and self.lighting_l_widths[column] * width_scale or lane_width
			if image_width > 0 then
				long = OsuManiaLighting({
					frames = long_frames,
					mode = "hold",
					frame_rate = getLightingFrameRate(long_frames),
					width = image_width * lighting_width / 30 * MANIA_HEIGHT_SCALE,
					scale_y = lighting_width / 30 * MANIA_HEIGHT_SCALE,
					color = {1, 1, 1, 1},
					origin_x = 0.5,
					origin_y = 0.5,
					fade_in = 0.08,
					fade_out = 0.12,
				})
			end
		end
		if normal or long then self.hit_lightings[column] = {short = normal, long = long} end
	end
	self.lighting_loaded = true
end

---@param engine rizu.RhythmEngine
function OsuManiaRenderer:updateLightingInput(engine)
	self.lighting_input_state = self.lighting_input_state or {}
	local release_duration = 40 / math.max(engine.chartmeta and engine.chartmeta.tempo or 120, 1)
	for column = 1, self.columns do
		local input = self.inputs[column]
		local engine_column = self.engine_input_map[input] or column
		local pressed = engine.isColumnPressed and engine:isColumnPressed(engine_column) or false
		local was_pressed = self.lighting_input_state[column]
		local lighting = self.stage_lightings[column]
		if lighting and pressed ~= was_pressed then
			lighting:setHeld(pressed, release_duration)
		end
		self.lighting_input_state[column] = pressed
	end
end

---@param notes table[]
function OsuManiaRenderer:updateHitLightings(notes)
	local active_long = self.active_long
	table_util.clear(active_long)
	for _, note in ipairs(notes) do
		local column = self.input_map[note:getColumn()]
		if column then
			local state = note:getState()
			local hit = self.hit_lightings[column]
			if note.type == "long" and state == "startPassedPressed" then
				active_long[column] = true
			elseif hit and (note.type == "short" and state == "passed"
				or note.type == "long" and state == "endPassed")
				and not self.lighting_notes[note] then
				self.lighting_notes[note] = true
				if hit.short then hit.short:trigger() end
			end
		end
	end
	for column = 1, self.columns do
		local hit = self.hit_lightings[column]
		if hit and hit.long then hit.long:setHeld(active_long[column] == true) end
	end
end

---The pass, not each sprite, owns blend state. Avoid setting an unchanged
---mode: even a redundant state call can interrupt automatic batching.
---@param batch rizu.skin.osu.OsuSpriteBatch
---@param mode love.BlendMode
---@return love.BlendMode? previous_mode
---@return love.BlendAlphaMode? previous_alpha
local function begin_lighting_pass(batch, mode)
	batch:flush()
	local previous_mode, previous_alpha = lg.getBlendMode()
	if previous_mode == mode and previous_alpha == "alphamultiply" then return end
	lg.setBlendMode(mode, "alphamultiply")
	return previous_mode, previous_alpha
end

---@param lane_widths number[]
---@param lane_xs number[]
---@param hit_y number
function OsuManiaRenderer:drawStageLightings(lane_widths, lane_xs, hit_y)
	local light_y = self.upside_down and FIELD_HEIGHT - self.light_position or self.light_position
	local started = false
	local previous_mode ---@type love.BlendMode?
	local previous_alpha ---@type love.BlendAlphaMode?
	for column = 1, self.columns do
		local lighting = self.stage_lightings[column]
		if lighting and lighting.active and lighting.alpha > 0 then
			if not started then
				previous_mode, previous_alpha = begin_lighting_pass(self.skin_graphics.batch, "alpha")
				started = true
			end
			lighting:draw(lane_xs[column] - lane_widths[column] / 2, light_y, self.upside_down)
		end
	end
	if previous_mode then lg.setBlendMode(previous_mode, previous_alpha) end
end

---@param lane_xs number[]
---@param hit_y number
function OsuManiaRenderer:drawHitLightings(lane_xs, hit_y)
	local started = false
	local previous_mode ---@type love.BlendMode?
	local previous_alpha ---@type love.BlendAlphaMode?
	for column = 1, self.columns do
		local hit = self.hit_lightings[column]
		if hit then
			local short, long = hit.short, hit.long
			if short and short.active and short.alpha > 0 or long and long.active and long.alpha > 0 then
				if not started then
					previous_mode, previous_alpha = begin_lighting_pass(self.skin_graphics.batch, "add")
					started = true
				end
				if short then short:draw(lane_xs[column], hit_y) end
				if long then long:draw(lane_xs[column], hit_y) end
			end
		end
	end
	if previous_mode then lg.setBlendMode(previous_mode, previous_alpha) end
end

---@return rizu.skin.osu.OsuSkinGraphics.Asset[]
function OsuManiaRenderer:getSkinAssets()
	local finder = OsuManiaSkinAssetFinder({
		section = self.section,
		columns = self.columns,
		column_suffixes = (function()
			local suffixes = {}
			for column = 1, self.columns do suffixes[column] = self:getColumnSuffix(column - 1) end
			return suffixes
		end)(),
		score_assets = self.score_view:getImageAssets(),
		accuracy_assets = self.accuracy_view:getImageAssets(),
		combo_assets = self.combo_view:getImageAssets(),
		judge_assets = self.judge_view:getImageAssets(),
	})
	return self.batch_plan:build(finder:find())
end

---@param column integer one based physical Mania lane index
---@param image any
---@return number width
---@return number height
function OsuManiaRenderer:getNoteDimensions(column, image)
	local width = (self.column_widths[column] or DEFAULT_COLUMN_WIDTH) * self.playfield_width_scale
	local image_width, image_height = OsuImage.dimensions(image)
	local height = image_width > 0 and image_height * self.note_base_width * self.playfield_width_scale / image_width or 0
	return width, height
end

---@param column integer zero based physical Mania lane index
---@return "1"|"2"|"S"
function OsuManiaRenderer:getColumnSuffix(column)
	local suffix = self.column_suffixes[column]
	if suffix then return suffix end
	suffix = self:computeColumnSuffix(column)
	self.column_suffixes[column] = suffix
	return suffix
end

---@param column integer zero based physical Mania lane index
---@return "1"|"2"|"S"
function OsuManiaRenderer:computeColumnSuffix(column)
	local physical_column = column + 1
	local scratch_count = self.scratch_count

	if scratch_count > 0 and (self.special_style == 1 or self.special_style == 2) then
		local scratch_columns = self.scratch_columns
		if scratch_columns[physical_column] then return "S" end

		local scratch_before = 0
		for current = 1, physical_column do
			if scratch_columns[current] then scratch_before = scratch_before + 1 end
		end
		local key = physical_column - scratch_before
		local key_count = self.columns - scratch_count
		if key_count % 2 == 1 then
			local half = (key_count - 1) / 2
			if (key_count + 1) / 2 == key then return "2" end
			return (half - key + 1) % 2 == 1 and "1" or "2"
		end
		local odd = (key_count / 2 - key + 1) % 2 == 1
		local same = key <= key_count / 2
		return odd == same and "2" or "1"
	end

	-- Preserve the original fallback layout for key-only modes and for skins
	-- that declare SpecialStyle without a matching scratch input mode.
	local key = physical_column
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

function OsuManiaRenderer:getHitMeterMode()
	local value = self.config:get("mania", self.input_mode, "hit_meter.mode", DEFAULT_HIT_METER_MODE)
	value = tonumber(value)
	return value == 1 and 1 or DEFAULT_HIT_METER_MODE
end

function OsuManiaRenderer:setHitMeterMode(value)
	assert(type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge,
		"hit meter mode must be finite")
	assert(value == 0 or value == 1, "hit meter mode must be 0 or 1")
	self.config:set("mania", self.input_mode, "hit_meter.mode", value)
	self.hit_meter_view:setMode(value)
end

---@return rizu.skin.osu.OsuManiaRenderer.Property[]
function OsuManiaRenderer:getProperties()
	return {
		{key = "hit_meter.mode", label = "Hit error meter", min = 0, max = 1, step = 1,
			value_format = function(value) return value == 1 and "Timing error" or "Judgement history" end,
			get = function() return self:getHitMeterMode() end,
			set = function(value) self:setHitMeterMode(value) end},
	}
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

---@param column integer one based physical Mania lane index
---@return boolean
function OsuManiaRenderer:getNoteBodyFlip(column)
	local flip = self.note_body_flips[column]
	if flip == nil then
		flip = self:getBoolean("NoteFlipWhenUpsideDown" .. (column - 1) .. "L", self.note_flip)
		self.note_body_flips[column] = flip
	end
	return flip
end

---@param column integer one based physical Mania lane index
---@param long_note boolean
---@return boolean
function OsuManiaRenderer:getNoteHeadFlip(column, long_note)
	local flips = long_note and self.note_head_flips or self.note_short_flips
	local flip = flips[column]
	if flip == nil then
		flip = self:getBoolean("NoteFlipWhenUpsideDown" .. (column - 1) .. (long_note and "H" or ""), self.note_flip)
		flips[column] = flip
	end
	return flip
end

---@param key string
---@param fallback number[]
---@return number[]
function OsuManiaRenderer:getSkinColor(key, fallback)
	local cached = self.skin_colors[key]
	if cached then return cached end
	local color = get_color(self.section, key, fallback)
	if color ~= fallback and get_section_value(self.section, key) ~= nil then
		self.skin_colors[key] = color
	end
	return color
end

---@param column integer one based physical Mania lane index
---@return number[]
function OsuManiaRenderer:getColumnLineColor(column)
	local color = self.lane_colors[column]
	if not color then
		color = self:getSkinColor("Colour" .. column, {0, 0, 0, 1})
		self.lane_colors[column] = color
	end
	return color
end

---@param name string?
---@return rizu.skin.osu.OsuSkinGraphics.Image?
function OsuManiaRenderer:getFirstFrame(name)
	return self.skin_graphics:getFrames(name, nil, "playfield")[1]
end

---@param column integer one based physical Mania lane index
---@return rizu.skin.osu.OsuManiaRenderer.ColumnKeys
function OsuManiaRenderer:getColumnKeys(column)
	local keys = self.column_keys[column]
	if keys then return keys end
	local suffix = self:getColumnSuffix(column - 1)
	local base = "KeyFlipWhenUpsideDown" .. (column - 1)
	local key_name = self:getSkinValue("KeyImage" .. (column - 1))
	local down_name = self:getSkinValue("KeyImage" .. (column - 1) .. "D")
	local key_frame = self:getFirstFrame(key_name)
	local up = key_frame or self:getFirstFrame("mania-key" .. suffix)
	local down = self:getFirstFrame(down_name)
	if not down then down = key_frame end
	if not down then down = self:getFirstFrame("mania-key" .. suffix .. "D") end
	if not down then down = up end
	local function get_flip(postfix)
		local value = self:getSkinValue(base .. postfix)
		if not value then value = self:getSkinValue(base) end
		local flip = value and (value:lower() == "true" or tonumber(value) == 1) or false
		return flip or self.key_flip
	end
	keys = {
		up = up,
		down = down,
		up_flip = get_flip(""),
		down_flip = get_flip("D"),
	}
	self.column_keys[column] = keys
	return keys
end

---@param column integer
---@param suffix string
---@param postfix string
---@return rizu.skin.osu.OsuSkinGraphics.Image[]
function OsuManiaRenderer:getColumnFrames(column, suffix, postfix)
	local column_frames = self.column_frames[column]
	if not column_frames then
		column_frames = {}
		self.column_frames[column] = column_frames
	end
	local frames = column_frames[postfix]
	if frames == nil then
		frames = self:findColumnFrames(column, suffix, postfix)
		column_frames[postfix] = frames
	end
	return frames
end

---@param column integer
---@param suffix string
---@param postfix string
---@return rizu.skin.osu.OsuSkinGraphics.Image[]
function OsuManiaRenderer:findColumnFrames(column, suffix, postfix)
	local graphics = self.skin_graphics
	local animated = true
	local function find(name)
		if not name then return EMPTY_FRAMES end
		if animated and graphics.getAnimationFrames then
			return graphics:getAnimationFrames(name, nil, "playfield")
		end
		return graphics:getFrames(name, nil, "playfield")
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
		return find("mania-note" .. suffix)
	end
	return EMPTY_FRAMES
end

---@param column integer
---@param suffix string
---@param postfix string
---@return rizu.skin.osu.OsuSkinGraphics.Image?
function OsuManiaRenderer:getColumnImage(column, suffix, postfix)
	local frames = self:getColumnFrames(column, suffix, postfix)
	local index = math.floor((self.note_renderer.time or 0) / 0.03) % math.max(#frames, 1) + 1
	return frames[index]
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
	self:drawStageLightings(lane_widths, lane_xs, hit_y)
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
	local lane_widths, lane_xs = self.lane_widths, self.lane_xs
	table_util.clear(lane_widths)
	table_util.clear(lane_xs)
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
	local notes_to_draw = self.notes_to_draw
	table_util.clear(notes_to_draw)
	local direction = self.upside_down and -1 or 1

	lg.push("all")
	lg.translate(offset_x, offset_y)
	lg.scale(scale)
	local batch = self.skin_graphics.batch
	batch:begin()
	for column = 1, math.min(self.columns, #preview.columns) do
		local source_column = column
		if player.column_map and player.column_map[column] then source_column = player.column_map[column] end
		local notes = preview.columns[source_column] or EMPTY_FRAMES
		local display_column = column
		if player.input_mode == self.input_mode then
			display_column = self.input_map[self.base_inputs[column]] or column
		end
		if display_column <= self.columns then
			local lane_x = lane_xs[display_column]
			local lane_width = lane_widths[display_column]
			self.field_renderer:drawLane(self, display_column, lane_width, lane_x, 0.4)
			local first, last = preview:getVisibleRange(source_column, lower, upper)
			for index = first, last do
				local note = notes[index]
				if note and note.end_time >= lower then
					local head_y = hit_y + (time - note.time) * NOTE_SCROLL_SPEED * rate * direction
					local tail_y = hit_y + (time - note.end_time) * NOTE_SCROLL_SPEED * rate * direction
					local item_index = #notes_to_draw + 1
					local item = self.note_draw_pool[item_index]
					if not item then
						item = {}
						self.note_draw_pool[item_index] = item
					end
					notes_to_draw[item_index] = item
					item.column = display_column
					item.long_note = note.end_time > note.time
					item.head_y = head_y
					item.tail_y = tail_y
					item.body_visible = note.end_time > note.time
					item.body_frame = nil
					item.head_visible = note.time >= lower and note.time <= upper
				end
			end
		end
	end
	self:drawNoteList(notes_to_draw, lane_widths, lane_xs)
	batch:finish()
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
	self.conveyor_hud_transform:reset()
	self.conveyor_hud_transform:apply(transform)
	self.conveyor_hud_transform:translate(offset_x, offset_y)
	self.conveyor_hud_transform:scale(scale)
	-- Match the first lane's transform and give the HUD the complete lane span,
	-- including all inter-column gaps.
	self.conveyor_hud_transform:translate(field_left, 0)
	self.conveyor_hud:draw(conveyor_width, FIELD_HEIGHT, self.conveyor_hud_transform)
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function OsuManiaRenderer:draw(width, height, transform)
	local engine = self.game.rhythm_engine
	local visual_engine = engine and engine.visual_engine
	if not visual_engine or self.columns == 0 then return end
	self:load()
	self:updateLightingInput(engine)
	self:updateHitLightings(visual_engine.visible_notes)

	local scale, offset_x, offset_y = self:getFieldTransform(width, height)
	local field_left, column_widths, width_scale = self:getPlayfieldLayout()
	local field_width = 0
	for _, value in ipairs(column_widths) do field_width = field_width + value * width_scale end
	for index = 1, self.columns - 1 do
		field_width = field_width + (self.column_spacings[index] or 0) * width_scale
	end
	local lane_widths, lane_xs = self.lane_widths, self.lane_xs

	table_util.clear(lane_widths)
	table_util.clear(lane_xs)
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

	local batch = self.skin_graphics.batch
	batch:begin()
	self.field_renderer:drawBackground(self, field_left, field_width)
	self.field_renderer:drawLanes(self, lane_widths, lane_xs)
	self.field_renderer:drawGuides(self, field_left, field_width, lane_widths, lane_xs, hit_y, width_scale)

	if self.stage_under_keys then self:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y) end
	if self.keys_under_notes then self:drawKeys(engine, lane_widths, lane_xs, hit_y) end

	local notes_to_draw = self.notes_to_draw
	table_util.clear(notes_to_draw)
	local direction = self.upside_down and -1 or 1
	for _, note in ipairs(visual_engine.visible_notes) do

		local state = note:getState()
		local long_note = note.type == "long"
		local column = self.input_map[note:getColumn()]
		if column and column >= 1 and column <= self.columns then
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
			local item_index = #notes_to_draw + 1
			local item = self.note_draw_pool[item_index]
			if not item then
				item = {}
				self.note_draw_pool[item_index] = item
			end
			notes_to_draw[item_index] = item
			item.column = column
			item.long_note = long_note
			item.head_y = head_y
			item.tail_y = tail_y
			item.body_visible = long_note and state ~= "endPassed"
			item.body_frame = long_note and self:getNoteBodyFrame(note, #self:getColumnFrames(column - 1,
				self:getColumnSuffix(column - 1), "L")) or 1
			item.head_visible = head_visible
		end
	end
	self:drawNoteList(notes_to_draw, lane_widths, lane_xs)

	if not self.keys_under_notes then self:drawKeys(engine, lane_widths, lane_xs, hit_y) end
	if not self.stage_under_keys then self:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y) end
	self:drawHitLightings(lane_xs, hit_y)
	batch:finish()
	lg.pop()
end

return OsuManiaRenderer
