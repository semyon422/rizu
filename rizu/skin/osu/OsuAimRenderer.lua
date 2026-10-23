local AimRenderer = require("rizu.skin.base.AimRenderer")
local OsuCircleRenderer = require("rizu.skin.osu.aim.OsuCircleRenderer")
local OsuFollowPointRenderer = require("rizu.skin.osu.aim.OsuFollowPointRenderer")
local OsuAimSprites = require("rizu.skin.osu.aim.OsuAimSprites")
local SkinTextures = require("rizu.skin.SkinTextures")
local OsuSliderOverlayRenderer = require("rizu.skin.osu.aim.OsuSliderOverlayRenderer")
local OsuSpriteRenderer = require("rizu.skin.osu.aim.OsuSpriteRenderer")
local SliderRenderer = require("rizu.skin.base.osu.aim.SliderRenderer")
local SpinnerRenderer = require("rizu.skin.base.osu.aim.SpinnerRenderer")
local Settings = require("rizu.config.Settings")

---@class rizu.skin.osu.OsuAimRenderer : rizu.skin.base.AimRenderer
---@operator call: rizu.skin.osu.OsuAimRenderer
---@field skin rizu.skin.Skin?
---@field skin_graphics rizu.skin.SkinTextures
---@field slider_graphics {prepare: fun(rules: rizu.aim.CircleRules), unload: fun(), [string]: any}
---@field sprites rizu.skin.osu.aim.OsuAimSprites?
---@field prepared_rules rizu.aim.CircleRules?
local OsuAimRenderer = AimRenderer + {}

local white = {1, 1, 1}
local DEFAULT_ASSETS = "resources/osu_default_assets.zip"

---@param game sphere.GameController
---@param skin rizu.skin.Skin?
function OsuAimRenderer:new(game, skin)
	AimRenderer.new(self, game)
	self.skin = skin
	self.skin_graphics = SkinTextures(game.fs)
end

---@return rizu.api.Gameplay.SkinProperty[]
function OsuAimRenderer:getProperties()
	local settings = self.game.settings
	local key = Settings.keys.gameplay.osu_cursor_scale
	return {
		{key = "cursor.scale", label = "Cursor size", setting = true, min = 0.25, max = 2, step = 0.05,
			value_format = function(value) return ("%.2fx"):format(value) end,
			get = function() return settings:getNumber(key) end,
			set = function(value) settings:setNumber(key, value) end},
	}
end

---Yields while a worker thread decodes the skin, so call it from a coroutine to keep the UI responsive.
function OsuAimRenderer:load()
	local skin = self.skin
	local graphics = self.skin_graphics
	if graphics.loading then return end
	if not graphics.loaded or graphics.skin ~= skin then
		-- The default assets supply the cursor and hit circle numbers a skin omits.
		graphics:setFallbackArchive(DEFAULT_ASSETS)
		graphics:setSkin(skin)
		local limits = love.graphics.getSystemLimits()
		local texture_limit = limits.texturesize > 0 and limits.texturesize or 4096
		graphics:setTextureLimit(texture_limit)
		graphics:setAtlasLimit(math.min(4096, texture_limit))
		if not graphics:loadAsync(OsuAimSprites.getAssets(graphics)) then return end
		self.sprites = OsuAimSprites.load(graphics)
	end
	local rules = self.game.rhythm_engine and self.game.rhythm_engine.rules
	if rules and self.prepared_rules ~= rules then
		---@type fun(graphics: rizu.skin.base.osu.aim.SliderGraphics, rules: rizu.aim.CircleRules)
		local prepare = self.slider_graphics.prepare
		prepare(self.slider_graphics, rules)
		self.prepared_rules = rules
	end
end

---@param width number
---@param height number
---@param transform love.Transform
function OsuAimRenderer:draw(width, height, transform)
	local re = self.game.rhythm_engine
	local rules = re and re.rules
	if not rules then return end
	self:load()
	local scale, ox, oy = self:getField(width, height)
	local time = re.visual_info.time
	local sprites = assert(self.sprites)
	local batch = self.skin_graphics.batch

	love.graphics.push("all")
	love.graphics.applyTransform(transform)
	love.graphics.setColor(0.04, 0.05, 0.08, 0.95)
	love.graphics.rectangle("fill", 0, 0, width, height)
	love.graphics.translate(ox, oy)
	love.graphics.scale(scale)
	love.graphics.setLineWidth(2)

	local objects = rules.objects
	local last_visible = 0
	for i, object in ipairs(objects) do
		if object.time - time > rules.preempt then break end
		last_visible = i
	end

	-- Sprites queue into the atlas batch; slider bodies and primitives flush it.
	batch:begin()
	OsuFollowPointRenderer.draw(rules, time, sprites)
	-- A chart's own combo colours replace the skin's.
	local chart_colors = rules.chart.data.combo_colors ---@type number[][]?
	local combo_colors = chart_colors and #chart_colors > 0 and chart_colors or sprites.combo_colors
	local border_color = sprites.slider_border or white
	-- Earlier heads must remain on top of later members of a stack.
	for i = last_visible, 1, -1 do
		local object = objects[i]
		---@type number[]?
		local color = object.combo_index and combo_colors[object.combo_index % #combo_colors + 1]
		local spinner = rules.spinners[i]
		if spinner and not rules.states[i] then
			batch:flush()
			SpinnerRenderer.draw(spinner, time)
		end

		local slider = rules.sliders[i]
		if slider then
			-- A finished slider stays until its body has faded out.
			local alpha = SliderRenderer.getBodyAlpha(object, slider, time, rules.preempt)
			if alpha > 0 then
				batch:flush()
				SliderRenderer.drawBody(object, slider, time, rules.preempt, self.slider_graphics, i,
					sprites.slider_track or color, border_color)
			end
			local snake_end = SliderRenderer.getSnakeEnd(object, time, rules.preempt)
			OsuSliderOverlayRenderer.drawEndCircle(slider, rules.radius, alpha, snake_end, sprites, color)
			OsuSliderOverlayRenderer.drawHead(object, rules.radius, time, rules.preempt, sprites,
				rules.heads[i], rules.head_times[i], color)
			OsuSliderOverlayRenderer.drawBodyOverlays(slider, rules.radius, time, alpha, snake_end, sprites,
				sprites.animation_framerate, rules.preempt)
		elseif not spinner then
			OsuCircleRenderer.draw(object, rules.radius, time, rules.preempt, sprites, false,
				rules.heads[i], rules.head_times[i], color)
		end
	end

	-- osu! shrinks the cursor while a button is held.
	local cursor_scale = self.game.settings:getNumber(Settings.keys.gameplay.osu_cursor_scale)
		* (rules:isHeld() and 0.9 or 1)
	if OsuSpriteRenderer.isRenderable(sprites.cursor) then
		OsuSpriteRenderer.draw(sprites.cursor, rules.x, rules.y,
			OsuSpriteRenderer.getWidth(sprites.cursor) * cursor_scale, 1)
	else
		batch:flush()
		love.graphics.setColor(1, 0.85, 0.2)
		love.graphics.circle("line", rules.x, rules.y, 9 * cursor_scale)
		love.graphics.circle("fill", rules.x, rules.y, 3)
	end
	batch:finish()
	love.graphics.pop()
end

function OsuAimRenderer:unload()
	self.slider_graphics:unload()
	self.prepared_rules = nil
	self.skin_graphics:unload()
	self.sprites = nil
end

return OsuAimRenderer
