local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local BgaView = require("rizu.skin.views.BgaView")
local SkinTextures = require("rizu.skin.SkinTextures")
local OsuManiaFieldRenderer = require("rizu.skin.osu.mania.OsuManiaFieldRenderer")
local OsuManiaKeyRenderer = require("rizu.skin.osu.mania.OsuManiaKeyRenderer")
local OsuManiaNoteRenderer = require("rizu.skin.osu.mania.OsuManiaNoteRenderer")
local OsuManiaStageRenderer = require("rizu.skin.osu.mania.OsuManiaStageRenderer")
local OsuManiaLightingRenderer = require("rizu.skin.osu.mania.OsuManiaLightingRenderer")
local OsuManiaSkinAssetFinder = require("rizu.skin.osu.mania.OsuManiaSkinAssetFinder")
local OsuManiaBatchPlan = require("rizu.skin.osu.mania.OsuManiaBatchPlan")
local OsuManiaSkinSettings = require("rizu.skin.osu.mania.OsuManiaSkinSettings")
local InputMode = require("chart.core.InputMode")
local SkinConfig = require("rizu.skin.SkinConfig")
local TextureImage = require("rizu.skin.TextureImage")
local table_util = require("table_util")

local get_section_value = OsuManiaSkinSettings.get_value
local get_number = OsuManiaSkinSettings.get_number
local get_boolean = OsuManiaSkinSettings.get_boolean
local get_color = OsuManiaSkinSettings.get_color

local lg = love.graphics
local FIELD_WIDTH, FIELD_HEIGHT = 640, 480
local DEFAULT_COLUMN_WIDTH = 30
local DEFAULT_HIT_METER_MODE = 0
local DEFAULT_HIT_METER_Y = -4
local DEFAULT_BGA_BRIGHTNESS = 0.15
local NOTE_SCROLL_SPEED = FIELD_HEIGHT
local EMPTY_FRAMES = {}

---@alias rizu.skin.osu.OsuManiaRenderer.PropertyType "slider"|"checkbox"|"segmented"|"dropdown"

---Editor property rendered by the skin editor. `type` selects the control:
---"slider" (default), "checkbox", "segmented", or "dropdown".
---@class rizu.skin.osu.OsuManiaRenderer.Property
---@field key string
---@field label string
---@field type rizu.skin.osu.OsuManiaRenderer.PropertyType?
---@field min number?
---@field max number?
---@field step number?
---@field value_format (fun(value: number): string)?
---@field options any[]? Values for segmented and dropdown controls
---@field format (fun(value: any): string)? Value label for segmented and dropdown controls
---@field get fun(): any
---@field set fun(value: any)

---@class rizu.skin.osu.OsuManiaRenderer.ColumnKeys
---@field up rizu.skin.SkinTextures.Image?
---@field down rizu.skin.SkinTextures.Image?
---@field up_flip boolean
---@field down_flip boolean

---Fields from skin.ini come from rizu.skin.osu.mania.OsuManiaSkinSettings, copied in loadSkinSettings.
---@class rizu.skin.osu.OsuManiaRenderer : rizu.gameplay.views.PlayfieldRenderer, rizu.skin.osu.mania.OsuManiaSkinSettings
---@operator call: rizu.skin.osu.OsuManiaRenderer
---@field skin_graphics rizu.skin.SkinTextures
---@field batch_plan rizu.skin.osu.mania.OsuManiaBatchPlan
---@field skin rizu.skin.Skin?
---@field config rizu.skin.SkinConfig
---@field config_path string?
---@field hit_position number
---@field move_with_hit_position boolean Move keys and stage lightings with the effective hit position.
---@field disable_hit_lightings boolean
---@field disable_stage_lightings boolean
---@field disable_mines boolean
---@field upside_down boolean
---@field engine_input_map {[chart.Column]: integer}
---@field field_renderer rizu.skin.osu.mania.OsuManiaFieldRenderer
---@field key_renderer rizu.skin.osu.mania.OsuManiaKeyRenderer
---@field note_renderer rizu.skin.osu.mania.OsuManiaNoteRenderer
---@field stage_renderer rizu.skin.osu.mania.OsuManiaStageRenderer
---@field bga_view rizu.skin.views.BgaView
---@field lighting_renderer rizu.skin.osu.mania.OsuManiaLightingRenderer
---@field private lane_widths number[]
---@field private lane_xs number[]
---@field private notes_to_draw table[]
---@field private note_draw_pool table[]
---@field private skin_colors {[string]: number[]}
---@field private column_frames {[integer]: {[string]: rizu.skin.SkinTextures.Image[]}}
---@field private column_keys {[integer]: rizu.skin.osu.OsuManiaRenderer.ColumnKeys}
---@field private note_body_flips boolean[]
---@field private note_head_flips boolean[]
---@field private note_short_flips boolean[]
---@field private lane_colors {[integer]: number[]}
---@field private playfield_width_scale number
local OsuManiaRenderer = PlayfieldRenderer + {}
OsuManiaRenderer.field_width = FIELD_WIDTH
OsuManiaRenderer.field_height = FIELD_HEIGHT
OsuManiaRenderer.gamemode = "mania"
OsuManiaRenderer.hud_layers = {"screen", "conveyor"}

---@param game sphere.GameController
---@param skin rizu.skin.Skin
---@param input_mode string?
---@param config rizu.skin.SkinConfig?
---@param config_path string?
function OsuManiaRenderer:new(game, skin, input_mode, config, config_path)
	PlayfieldRenderer.new(self, game)
	self.bga_view = BgaView(game)
	self.background_hud:add(self.bga_view)
	self.input_mode = input_mode or "4key"
	self.config = config or SkinConfig()
	self.config_path = config_path
	self.bga_view.brightness = self:getBgaBrightness()
	local mode = InputMode(self.input_mode)
	self.inputs = mode:getInputs()
	self.base_inputs = mode:getInputs()
	self.engine_input_map = mode:getInputMap()
	self.input_map = self.engine_input_map
	self.skin_graphics = SkinTextures(game.fs)
	self.textures = self.skin_graphics
	self.batch_plan = OsuManiaBatchPlan()
	self.field_renderer = OsuManiaFieldRenderer()
	self.key_renderer = OsuManiaKeyRenderer()
	self.note_renderer = OsuManiaNoteRenderer()
	self.stage_renderer = OsuManiaStageRenderer()
	self.lighting_renderer = OsuManiaLightingRenderer()
	self.lane_widths = {}
	self.lane_xs = {}
	self.notes_to_draw = {}
	self.note_draw_pool = {}
	self:loadSkinSettings(skin)
end

---@param skin rizu.skin.Skin?
function OsuManiaRenderer:loadSkinSettings(skin)
	self.skin = skin
	for key, value in pairs(OsuManiaSkinSettings.read(skin and skin.skin_ini, self.base_inputs, self.input_mode)) do
		self[key] = value
	end
	self.upside_down = self:getUpscroll()
	self.hit_position = self:getHitPosition()
	self.move_with_hit_position = self:getMoveWithHitPosition()
	self.disable_hit_lightings = self:getDisableHitLightings()
	self.disable_stage_lightings = self:getDisableStageLightings()
	self.disable_mines = self:getDisableMines()
	self.lighting_renderer:reset()
	self.skin_colors = {}
	self.column_frames = {}
	self.column_keys = {}
	self.note_body_flips = {}
	self.note_head_flips = {}
	self.note_short_flips = {}
	self.lane_colors = {}
	for column = 1, self.columns do
		self:getNoteBodyFlip(column)
		self:getNoteHeadFlip(column, true)
		self:getNoteHeadFlip(column, false)
		self:getColumnLineColor(column)
	end
	local _, _, width_scale = self:getPlayfieldLayout()
	self.playfield_width_scale = width_scale
end

function OsuManiaRenderer:update(dt)
	self.field_renderer:update(dt)
	self.key_renderer:update(dt)
	self.note_renderer:update(dt)
	self.stage_renderer:update(dt)
	self.lighting_renderer:update(dt)
end

---Yields while a worker thread decodes the skin, so call it from a coroutine to keep the UI responsive.
function OsuManiaRenderer:load()
	local skin = self.skin
	if self.skin_graphics.loading then return end
	if self.skin_graphics.loaded
		and self.skin_graphics.skin == skin
		and self.skin_graphics.fallback_archive == "resources/osu_default_assets.zip" then return end

	-- Consumers release their references before the graphics owner releases GPU
	-- resources. Acquire the HUD only after the complete skin has been uploaded.
	self:unloadHud()
	self.skin_graphics:setFallbackArchive("resources/osu_default_assets.zip")
	if self.skin_graphics.skin ~= skin then self.skin_graphics:setSkin(skin) end
	self:buildHud()
	if not self.skin_graphics.loaded then
		local limits = love.graphics.getSystemLimits()
		local texture_limit = limits.texturesize > 0 and limits.texturesize or 4096
		self.skin_graphics:setTextureLimit(texture_limit)
		self.skin_graphics:setAtlasLimit(math.min(4096, texture_limit))
		-- unload() while waiting cancels the load; there is nothing to build then.
		if not self.skin_graphics:loadAsync(self:getSkinAssets()) then return end
	end
	self.lighting_renderer:load(self)
	self:loadHud()
end

function OsuManiaRenderer:unload()
	self:unloadHud()
	self.skin_graphics:unload()
	self.lighting_renderer:reset()
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
	local full_width = 0
	for index, width in ipairs(self.column_widths) do
		full_width = full_width + width + (index > 1 and self.column_spacings[index - 1] or 0)
	end
	local left = math.max(0, math.min(self.column_start, FIELD_WIDTH - self.column_right))
	local right = math.max(0, math.min(self.column_right, FIELD_WIDTH - left))
	local available_width = math.max(0, FIELD_WIDTH - left - right)
	local scale = full_width > available_width and available_width / full_width or 1
	return left, self.column_widths, scale, full_width
end

---Fills lane_widths and lane_xs with the scaled width and center of each lane.
---@return number field_left
---@return number field_width
---@return number width_scale
function OsuManiaRenderer:layoutLanes()
	local field_left, column_widths, width_scale, full_width = self:getPlayfieldLayout()
	local lane_widths, lane_xs = self.lane_widths, self.lane_xs
	local x = field_left
	for column = 1, self.columns do
		if column > 1 then x = x + self.column_spacings[column - 1] * width_scale end
		lane_widths[column] = column_widths[column] * width_scale
		lane_xs[column] = x + lane_widths[column] / 2
		x = x + lane_widths[column]
	end
	return field_left, full_width * width_scale, width_scale
end

---@return table item A pooled draw item appended to notes_to_draw
function OsuManiaRenderer:addNoteToDraw()
	local index = #self.notes_to_draw + 1
	local item = self.note_draw_pool[index]
	if not item then
		item = {}
		self.note_draw_pool[index] = item
	end
	self.notes_to_draw[index] = item
	return item
end

---@return rizu.skin.SkinTextures.Asset[]
function OsuManiaRenderer:getSkinAssets()
	local finder = OsuManiaSkinAssetFinder({
		section = self.section,
		columns = self.columns,
		column_suffixes = (function()
			local suffixes = {}
			for column = 1, self.columns do suffixes[column] = self:getColumnSuffix(column - 1) end
			return suffixes
		end)(),
	})
	local assets = self.batch_plan:build(finder:find())
	for _, asset in ipairs(self:getHudAssets()) do assets[#assets + 1] = asset end
	return assets
end

---@param column integer one based physical Mania lane index
---@param image any
---@return number width
---@return number height
function OsuManiaRenderer:getNoteDimensions(column, image)
	local width = (self.column_widths[column] or DEFAULT_COLUMN_WIDTH) * self.playfield_width_scale
	local image_width, image_height = TextureImage.dimensions(image)
	local height = image_width > 0 and image_height * self.note_base_width * self.playfield_width_scale / image_width or 0
	return width, height
end

---@param column integer zero based physical Mania lane index
---@return "1"|"2"|"S"
function OsuManiaRenderer:getColumnSuffix(column)
	return self.column_suffixes[column]
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param key string
---@return boolean
local function get_flag(renderer, key)
	return renderer.config:get("mania", renderer.input_mode, key) == true
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param key string
---@param field string Renderer field that caches the flag
---@param value boolean
local function set_flag(renderer, key, field, value)
	assert(type(value) == "boolean", key .. " must be a boolean")
	renderer[field] = value
	renderer.config:set("mania", renderer.input_mode, key, value)
end

---@return boolean
function OsuManiaRenderer:getMoveWithHitPosition() return get_flag(self, "hit_position.move_keys") end

---@param value boolean
function OsuManiaRenderer:setMoveWithHitPosition(value)
	set_flag(self, "hit_position.move_keys", "move_with_hit_position", value)
end

---@return boolean
function OsuManiaRenderer:getDisableHitLightings() return get_flag(self, "lighting.disable_hit") end

---@param value boolean
function OsuManiaRenderer:setDisableHitLightings(value)
	set_flag(self, "lighting.disable_hit", "disable_hit_lightings", value)
end

---@return boolean
function OsuManiaRenderer:getDisableStageLightings() return get_flag(self, "lighting.disable_stage") end

---@param value boolean
function OsuManiaRenderer:setDisableStageLightings(value)
	set_flag(self, "lighting.disable_stage", "disable_stage_lightings", value)
end

---@return boolean
function OsuManiaRenderer:getDisableMines() return get_flag(self, "notes.disable_mines") end

---@param value boolean
function OsuManiaRenderer:setDisableMines(value)
	set_flag(self, "notes.disable_mines", "disable_mines", value)
end

---@return number
function OsuManiaRenderer:getHitPositionOffset()
	if not self.move_with_hit_position then return 0 end
	return self.skin_hit_position - self.hit_position
end

---Effective scroll direction: the config override when set, otherwise the
---skin's UpsideDown value. True means upscroll (osu!'s UpsideDown).
---@return boolean upscroll
function OsuManiaRenderer:getUpscroll()
	local override = self.config:get("mania", self.input_mode, "scroll.upscroll")
	if type(override) == "boolean" then return override end
	return self.skin_upside_down
end

---@param upscroll boolean
function OsuManiaRenderer:setUpscroll(upscroll)
	assert(type(upscroll) == "boolean", "upscroll must be a boolean")
	self.config:set("mania", self.input_mode, "scroll.upscroll", upscroll)
	self.upside_down = upscroll
	-- The default layout follows the scroll direction; a saved one stays where the player put it.
	if self.skin_graphics.loaded and not self.config:getHud("mania", self.input_mode) then
		self:buildHud()
		self:loadHud()
	end
end

---Effective hit position: the config override when set, otherwise the skin's
---HitPosition value.
---@return number
function OsuManiaRenderer:getHitPosition()
	local override = self.config:get("mania", self.input_mode, "hit_position")
	if type(override) == "number" and override == override
		and override ~= math.huge and override ~= -math.huge then
		return math.max(240, math.min(480, override))
	end
	return self.skin_hit_position
end

---@param value number
function OsuManiaRenderer:setHitPosition(value)
	assert(type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge,
		"hit position must be finite")
	self.hit_position = math.max(240, math.min(480, value))
	self.config:set("mania", self.input_mode, "hit_position", self.hit_position)
end

---@return number
function OsuManiaRenderer:getBgaBrightness()
	local value = self.config:get("mania", self.input_mode, "bga.brightness", DEFAULT_BGA_BRIGHTNESS)
	value = tonumber(value)
	if not value or value ~= value or value == math.huge or value == -math.huge then
		return DEFAULT_BGA_BRIGHTNESS
	end
	return math.max(0, math.min(1, value))
end

---@param value number
function OsuManiaRenderer:setBgaBrightness(value)
	assert(type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge,
		"bga brightness must be finite")
	value = math.max(0, math.min(1, value))
	self.config:set("mania", self.input_mode, "bga.brightness", value)
	self.bga_view.brightness = value
end

---@param name "Score"|"Combo"
---@return string prefix
---@return number overlap
function OsuManiaRenderer:getFont(name)
	local fonts = self.skin and self.skin.skin_ini.Fonts or {}
	local prefix = get_section_value(fonts, name .. "Prefix")
	if not prefix or prefix == "" then prefix = "score" end
	return prefix, get_number(fonts, name .. "Overlap", 0)
end

---Judgement texture of a grade: the skin.ini name when the skin has that file, otherwise osu!'s.
---@param grade string
---@return string
function OsuManiaRenderer:getJudgementTexture(grade)
	local custom = get_section_value(self.section, "Hit" .. grade)
	if custom and not tonumber(custom) and self.skin_graphics:findAsset(custom, self.skin_graphics.file_map) then
		return custom
	end
	return "mania-hit" .. grade
end

---osu!'s HUD from skin.ini. The keys of the hit error meter and judgement animation options this
---renderer had before HUD layouts seed it.
---@return rizu.skin.hud.HudLayout.Data
function OsuManiaRenderer:getDefaultHudLayout()
	local section = self.section
	---@param key string
	---@param default number
	local function position(key, default)
		local value = get_number(section, key, default)
		if self.upside_down then value = FIELD_HEIGHT - value end
		return math.max(0, math.min(FIELD_HEIGHT, value))
	end
	local score_prefix, score_overlap = self:getFont("Score")
	local combo_prefix, combo_overlap = self:getFont("Combo")
	local config = self.config
	local judge_animation = config:get("mania", self.input_mode, "judge.animation") ~= false and "osu" or "osu_fade"
	local hit_meter_mode = tonumber(config:get("mania", self.input_mode, "hit_meter.mode", DEFAULT_HIT_METER_MODE))
	local hit_meter_y = tonumber(config:get("mania", self.input_mode, "hit_meter.y")) or DEFAULT_HIT_METER_Y

	local conveyor = {
		{type = "combo", anchor = "top", origin = "center", y = position("ComboPosition", 111), scale = 0.8,
			font = combo_prefix, overlap = combo_overlap, animation = "osu",
			break_color = get_color(section, "ColourBreak", {1, 0.035, 0.035, 1})},
		{type = "judgement", anchor = "top", origin = "center", y = position("ScorePosition", 325), scale = 480 / 768,
			animation = judge_animation,
			texture_1 = self:getJudgementTexture("300g"), texture_2 = self:getJudgementTexture("300"),
			texture_3 = self:getJudgementTexture("200"), texture_4 = self:getJudgementTexture("100"),
			texture_5 = self:getJudgementTexture("50"), texture_6 = self:getJudgementTexture("0")},
	}
	if hit_meter_mode ~= 2 then
		conveyor[#conveyor + 1] = {type = "osu_hit_error", anchor = "bottom", origin = "bottom", y = hit_meter_y,
			mode = hit_meter_mode == 1 and "timing" or "judgements", arrow = "editor-rate-arrow"}
	end
	-- Positions under the score assume the default score glyphs, 46 units tall.
	return {
		screen = {
			{type = "score", anchor = "top_right", origin = "top_right", x = -6, y = 0, scale = 0.6,
				font = score_prefix, overlap = score_overlap, digits = 8, animation = "osu"},
			{type = "accuracy", anchor = "top_right", origin = "top_right", x = -6, y = 31, scale = 0.36,
				font = score_prefix, overlap = score_overlap, animation = "osu"},
			{type = "osu_radial_progress", anchor = "top_right", origin = "center", x = -100, y = 39, texture = "circularmetre"},
		},
		conveyor = conveyor,
	}
end

---@return rizu.skin.osu.OsuManiaRenderer.Property[]
function OsuManiaRenderer:getProperties()
	return {
		{key = "hit_position.move_keys", label = "Move keys with hit position", type = "checkbox",
			get = function() return self:getMoveWithHitPosition() end,
			set = function(value) self:setMoveWithHitPosition(value) end},
		{key = "lighting.disable_hit", label = "Disable hit lightings", type = "checkbox",
			get = function() return self:getDisableHitLightings() end,
			set = function(value) self:setDisableHitLightings(value) end},
		{key = "lighting.disable_stage", label = "Disable stage lightings", type = "checkbox",
			get = function() return self:getDisableStageLightings() end,
			set = function(value) self:setDisableStageLightings(value) end},
		{key = "notes.disable_mines", label = "Disable mines", type = "checkbox",
			get = function() return self:getDisableMines() end,
			set = function(value) self:setDisableMines(value) end},
		{key = "scroll.upscroll", label = "Upscroll", type = "checkbox",
			get = function() return self:getUpscroll() end,
			set = function(value) self:setUpscroll(value) end},
		{key = "hit_position", label = "Hit position", min = 240, max = 480, step = 1,
			get = function() return self:getHitPosition() end,
			set = function(value) self:setHitPosition(value) end},
		{key = "bga.brightness", label = "BGA brightness", min = 0, max = 1, step = 0.01,
			value_format = function(value) return ("%d%%"):format(math.floor(value * 100 + 0.5)) end,
			get = function() return self:getBgaBrightness() end,
			set = function(value) self:setBgaBrightness(value) end},
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
---@return rizu.skin.SkinTextures.Image?
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
---@return rizu.skin.SkinTextures.Image[]
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
---@return rizu.skin.SkinTextures.Image[]
function OsuManiaRenderer:findColumnFrames(column, suffix, postfix)
	local graphics = self.skin_graphics
	local animated = true
	-- osu! has no bundled hold tail, so the tail never comes from the fallback skin.
	local skin_only = postfix == "T"
	local function find(name)
		if not name then return EMPTY_FRAMES end
		if animated and graphics.getAnimationFrames then
			return graphics:getAnimationFrames(name, nil, "playfield", skin_only)
		end
		return graphics:getFrames(name, nil, "playfield", skin_only)
	end

	local frames = find(get_section_value(self.section, "NoteImage" .. column .. postfix))
	if #frames > 0 then return frames end
	if postfix == "H" then
		frames = find(get_section_value(self.section, "NoteImage" .. column))
		if #frames > 0 then return frames end
	end

	frames = find("mania-note" .. suffix .. postfix)
	if #frames > 0 then return frames end
	if postfix == "H" then
		return find("mania-note" .. suffix)
	end
	-- osu! falls back to the head texture (drawn flipped) when the tail is missing.
	if postfix == "T" then
		return self:getColumnFrames(column, suffix, "H")
	end
	return EMPTY_FRAMES
end

---@param column integer
---@param suffix string
---@param postfix string
---@return rizu.skin.SkinTextures.Image?
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
	self.lighting_renderer:drawStage(self, lane_widths, lane_xs)
end

---@param notes {column: integer, long_note: boolean, head_y: number, tail_y: number, body_visible: boolean, body_frame: integer?, head_visible: boolean, mine: boolean?}[]
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
	self:layoutLanes()
	local lane_widths, lane_xs = self.lane_widths, self.lane_xs
	local hit_y = self.upside_down and FIELD_HEIGHT - self.hit_position or self.hit_position
	local rate = math.max(player.rate or 1, 0.01)
	local time = player.time or 0
	local lower = time - 1.5 / rate
	local upper = time + (self.upside_down and 1 or 1.5) / rate
	table_util.clear(self.notes_to_draw)
	local direction = self.upside_down and -1 or 1

	lg.push("all")
	lg.translate(offset_x, offset_y)
	lg.scale(scale)
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
					local item = self:addNoteToDraw()
					item.column = display_column
					item.long_note = note.end_time > note.time
					item.head_y = head_y
					item.tail_y = tail_y
					item.body_visible = note.end_time > note.time
					item.body_frame = nil
					item.head_visible = note.time >= lower and note.time <= upper
					item.mine = false
				end
			end
		end
	end
	self:drawNoteList(self.notes_to_draw, lane_widths, lane_xs)
	lg.pop()
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@return number
function OsuManiaRenderer:getHudScale(width, height)
	return (self:getFieldTransform(width, height))
end

---The complete lane span, including all inter-column gaps.
---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@return number? x
---@return number? y
---@return number? width
---@return number? height
function OsuManiaRenderer:getConveyorRect(width, height)
	local scale, offset_x, offset_y = self:getFieldTransform(width, height)
	if scale <= 0 then return end
	local field_left, _, column_scale, field_width = self:getPlayfieldLayout()
	return offset_x / scale + field_left, offset_y / scale, field_width * column_scale, FIELD_HEIGHT
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function OsuManiaRenderer:draw(width, height, transform)
	local engine = self.game.rhythm_engine
	local visual_engine = engine and engine.visual_engine
	if not visual_engine or self.columns == 0 then return end
	self:load()
	self.lighting_renderer:updateInput(self, engine)
	self.lighting_renderer:updateHits(self, visual_engine.visible_notes)

	local scale, offset_x, offset_y = self:getFieldTransform(width, height)
	local field_left, field_width, width_scale = self:layoutLanes()
	local lane_widths, lane_xs = self.lane_widths, self.lane_xs
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

	table_util.clear(self.notes_to_draw)
	local direction = self.upside_down and -1 or 1
	for _, note in ipairs(visual_engine.visible_notes) do
		local state = note:getState()
		local long_note = note.type == "long"
		local column = self.input_map[note:getColumn()]
		local mine = note.linked_note ~= nil and note.linked_note:getType() == "mine"
		if column and column >= 1 and column <= self.columns and not (mine and self.disable_mines) then
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
			local item = self:addNoteToDraw()
			item.column = column
			item.long_note = long_note
			item.head_y = head_y
			item.tail_y = tail_y
			item.body_visible = long_note and state ~= "endPassed"
			item.body_frame = long_note and self:getNoteBodyFrame(note, #self:getColumnFrames(column - 1,
				self:getColumnSuffix(column - 1), "L")) or 1
			item.head_visible = head_visible
			item.mine = mine
		end
	end
	self:drawNoteList(self.notes_to_draw, lane_widths, lane_xs)

	if not self.keys_under_notes then self:drawKeys(engine, lane_widths, lane_xs, hit_y) end
	if not self.stage_under_keys then self:drawStageDecorations(field_left, field_width, lane_widths, lane_xs, hit_y) end
	self.lighting_renderer:drawHits(self, lane_xs, hit_y)
	lg.pop()
end

return OsuManiaRenderer
