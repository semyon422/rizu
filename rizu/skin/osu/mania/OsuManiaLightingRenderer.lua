local class = require("class")
local OsuManiaLighting = require("rizu.skin.osu.mania.OsuManiaLighting")
local TextureImage = require("rizu.skin.TextureImage")
local table_util = require("table_util")

local lg = love.graphics
local MANIA_HEIGHT_SCALE = 480 / 768
local FIELD_HEIGHT = 480

---Stage lightings (held keys) and hit lightings (judged notes).
---@class rizu.skin.osu.mania.OsuManiaLightingRenderer
---@operator call: rizu.skin.osu.mania.OsuManiaLightingRenderer
---@field stage_lightings rizu.skin.osu.mania.OsuManiaLighting[]
---@field hit_lightings {[integer]: {short: rizu.skin.osu.mania.OsuManiaLighting?, long: rizu.skin.osu.mania.OsuManiaLighting?}}
---@field private hit_notes {[table]: boolean} Notes that already triggered their hit lighting
---@field private pressed {[integer]: boolean}
---@field private active_long {[integer]: boolean}
---@field private skin rizu.skin.Skin?
---@field private loaded boolean
local OsuManiaLightingRenderer = class()

function OsuManiaLightingRenderer:new()
	self.active_long = {}
	self:reset()
end

function OsuManiaLightingRenderer:reset()
	self.stage_lightings = {}
	self.hit_lightings = {}
	self.hit_notes = setmetatable({}, {__mode = "k"})
	self.pressed = {}
	self.skin = nil
	self.loaded = false
end

---@param dt number
function OsuManiaLightingRenderer:update(dt)
	for _, lighting in pairs(self.stage_lightings) do lighting:update(dt) end
	for _, hit in pairs(self.hit_lightings) do
		if hit.short then hit.short:update(dt) end
		if hit.long then hit.long:update(dt) end
	end
end

---@param graphics rizu.skin.SkinTextures
---@param name string?
---@param fallback string
---@return rizu.skin.SkinTextures.Image[]
local function get_frames(graphics, name, fallback)
	if graphics.getAnimationFrames then
		return graphics:getAnimationFrames(name, fallback, "standalone")
	end
	return graphics:getFrames(name, fallback, "standalone")
end

---@param frames rizu.skin.SkinTextures.Image[]
---@return number
local function get_hit_frame_rate(frames)
	-- osu! advances hit-light animations over 170 ms, but never faster than
	-- the historical 60 Hz update interval.
	return math.min(#frames / 0.17, 60)
end

---@param frames rizu.skin.SkinTextures.Image[]
---@param mode "oneshot"|"hold"
---@param skin_width number LightingNWidth or LightingLWidth of the column, 0 for the lane width
---@param lane_width number
---@param width_scale number
---@return rizu.skin.osu.mania.OsuManiaLighting?
local function create_hit_lighting(frames, mode, skin_width, lane_width, width_scale)
	if #frames == 0 then return end
	local image_width = TextureImage.dimensions(frames[1])
	if image_width <= 0 then return end
	local lighting_width = skin_width > 0 and skin_width * width_scale or lane_width
	return OsuManiaLighting({
		frames = frames,
		mode = mode,
		frame_rate = get_hit_frame_rate(frames),
		width = image_width * lighting_width / 30 * MANIA_HEIGHT_SCALE,
		scale_y = lighting_width / 30 * MANIA_HEIGHT_SCALE,
		color = {1, 1, 1, 1},
		origin_x = 0.5,
		origin_y = 0.5,
		duration = mode == "oneshot" and 0.2 or nil,
		fade_in = 0.08,
		fade_out = 0.12,
	})
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
function OsuManiaLightingRenderer:load(renderer)
	if self.loaded and self.skin == renderer.skin then return end
	self:reset()
	self.skin = renderer.skin
	local graphics = renderer.skin_graphics
	if not graphics.loaded then return end

	local function get_name(key)
		local name = renderer:getSkinValue(key)
		if name and tonumber(name) then return nil end
		return name
	end

	local stage_frames = get_frames(graphics, get_name("StageLight"), "mania-stage-light")
	local normal_frames = get_frames(graphics, get_name("LightingN"), "lightingN")
	local long_frames = get_frames(graphics, get_name("LightingL"), "lightingL")
	if #long_frames == 0 then long_frames = normal_frames end

	local _, _, width_scale = renderer:getPlayfieldLayout()
	for column = 1, renderer.columns do
		local lane_width = renderer.column_widths[column] * width_scale
		if #stage_frames > 0 then
			local image_width, image_height = TextureImage.dimensions(stage_frames[1])
			if image_width > 0 and image_height > 0 then
				self.stage_lightings[column] = OsuManiaLighting({
					frames = stage_frames,
					mode = "stage",
					frame_rate = renderer.light_frame_rate,
					width = lane_width,
					scale_y = FIELD_HEIGHT / 768,
					color = renderer:getSkinColor("ColourLight" .. column, {55 / 255, 1, 1, 1}),
					origin_x = 0,
					origin_y = 1,
				})
			end
		end

		local short = create_hit_lighting(normal_frames, "oneshot", renderer.lighting_n_widths[column], lane_width,
			width_scale)
		local long = create_hit_lighting(long_frames, "hold", renderer.lighting_l_widths[column], lane_width,
			width_scale)
		if short or long then self.hit_lightings[column] = {short = short, long = long} end
	end
	self.loaded = true
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param engine rizu.RhythmEngine
function OsuManiaLightingRenderer:updateInput(renderer, engine)
	local release_duration = 40 / math.max(engine.chartmeta and engine.chartmeta.tempo or 120, 1)
	for column = 1, renderer.columns do
		local input = renderer.inputs[column]
		local engine_column = renderer.engine_input_map[input] or column
		local pressed = engine.isColumnPressed and engine:isColumnPressed(engine_column) or false
		local lighting = self.stage_lightings[column]
		if not renderer.disable_stage_lightings and lighting and pressed ~= self.pressed[column] then
			lighting:setHeld(pressed, release_duration)
		end
		self.pressed[column] = pressed
	end
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param notes table[]
function OsuManiaLightingRenderer:updateHits(renderer, notes)
	if renderer.disable_hit_lightings then return end
	local active_long = self.active_long
	table_util.clear(active_long)
	for _, note in ipairs(notes) do
		local column = renderer.input_map[note:getColumn()]
		if column then
			local state = note:getState()
			local hit = self.hit_lightings[column]
			if note.type == "long" and state == "startPassedPressed" then
				active_long[column] = true
			elseif hit and (note.type == "short" and state == "passed"
				or note.type == "long" and state == "endPassed")
				and not self.hit_notes[note] then
				self.hit_notes[note] = true
				if hit.short then hit.short:trigger() end
			end
		end
	end
	for column = 1, renderer.columns do
		local hit = self.hit_lightings[column]
		if hit and hit.long then hit.long:setHeld(active_long[column] == true) end
	end
end

---The pass, not each sprite, owns blend state. Avoid setting an unchanged
---mode: even a redundant state call can interrupt automatic batching.
---@param mode love.BlendMode
---@return love.BlendMode? previous_mode
---@return love.BlendAlphaMode? previous_alpha
local function begin_pass(mode)
	local previous_mode, previous_alpha = lg.getBlendMode()
	if previous_mode == mode and previous_alpha == "alphamultiply" then return end
	lg.setBlendMode(mode, "alphamultiply")
	return previous_mode, previous_alpha
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param lane_widths number[]
---@param lane_xs number[]
function OsuManiaLightingRenderer:drawStage(renderer, lane_widths, lane_xs)
	if renderer.disable_stage_lightings then return end
	local offset = renderer:getHitPositionOffset()
	local light_y = renderer.upside_down and FIELD_HEIGHT - renderer.light_position + offset
		or renderer.light_position - offset
	local started = false
	local previous_mode ---@type love.BlendMode?
	local previous_alpha ---@type love.BlendAlphaMode?
	for column = 1, renderer.columns do
		local lighting = self.stage_lightings[column]
		if lighting and lighting.active and lighting.alpha > 0 then
			if not started then
				previous_mode, previous_alpha = begin_pass("alpha")
				started = true
			end
			lighting:draw(lane_xs[column] - lane_widths[column] / 2, light_y, renderer.upside_down)
		end
	end
	if previous_mode then lg.setBlendMode(previous_mode, previous_alpha) end
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param lane_xs number[]
---@param hit_y number
function OsuManiaLightingRenderer:drawHits(renderer, lane_xs, hit_y)
	if renderer.disable_hit_lightings then return end
	local started = false
	local previous_mode ---@type love.BlendMode?
	local previous_alpha ---@type love.BlendAlphaMode?
	for column = 1, renderer.columns do
		local hit = self.hit_lightings[column]
		if hit then
			local short, long = hit.short, hit.long
			if short and short.active and short.alpha > 0 or long and long.active and long.alpha > 0 then
				if not started then
					previous_mode, previous_alpha = begin_pass("add")
					started = true
				end
				if short then short:draw(lane_xs[column], hit_y) end
				if long then long:draw(lane_xs[column], hit_y) end
			end
		end
	end
	if previous_mode then lg.setBlendMode(previous_mode, previous_alpha) end
end

return OsuManiaLightingRenderer
