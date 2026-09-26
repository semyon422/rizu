local AimRenderer = require("rizu.skin.base.AimRenderer")
local OsuCircleRenderer = require("rizu.skin.osu.aim.OsuCircleRenderer")
local OsuSkinGraphics = require("rizu.skin.osu.aim.OsuSkinGraphics")
local OsuSliderOverlayRenderer = require("rizu.skin.osu.aim.OsuSliderOverlayRenderer")
local SliderRenderer = require("rizu.skin.base.osu.aim.SliderRenderer")
local SpinnerRenderer = require("rizu.skin.base.osu.aim.SpinnerRenderer")
local Settings = require("rizu.config.Settings")

---@class rizu.skin.osu.OsuAimRenderer : rizu.skin.base.AimRenderer
---@operator call: rizu.skin.osu.OsuAimRenderer
---@field skin_graphics rizu.skin.osu.aim.OsuSkinGraphics
---@field slider_graphics {prepare: fun(rules: rizu.aim.CircleRules), unload: fun(), [string]: any}
---@field sprites rizu.skin.osu.aim.OsuSkinGraphics.Sprites?
---@field prepared_rules rizu.aim.CircleRules?
local OsuAimRenderer = AimRenderer + {}

---@param game sphere.GameController
function OsuAimRenderer:new(game)
	AimRenderer.new(self, game)
	self.skin_graphics = OsuSkinGraphics(game.fs)
end

---@return rizu.skin.OsuSkinDiscovery?
function OsuAimRenderer:getSkin()
	local registry = self.game and self.game.skinRegistry
	if not registry then return nil end

	---@type string?
	local skin_path
	local settings = self.game.settings
	if settings then
		local skin_paths = settings:getStringMap(Settings.keys.gameplay.skins)
		skin_path = skin_paths["osu/1osu"] or skin_paths.osu
	end
	if skin_path then
		local normalized_path = skin_path:gsub("\\", "/"):gsub("/+$", "")
		local skin = registry:getOsuSkin(normalized_path)
		if skin then return skin end
	end
	return registry:getOsuSkins()[1]
end

function OsuAimRenderer:load()
	local skin = self:getSkin()
	if self.skin_graphics.skin ~= skin then
		self.skin_graphics:setSkin(skin)
		self.skin_graphics:load()
	elseif not self.skin_graphics.loaded then
		self.skin_graphics:load()
	end
	self.sprites = self.skin_graphics.images
	local rules = self.game.rhythm_engine and self.game.rhythm_engine.aim_rules
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
	local rules = re and re.aim_rules
	if not rules then return end
	self:load()
	local scale, ox, oy = self:getField(width, height)
	local time = re.visual_info.time
	local sprites = self.skin_graphics.images

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

	-- Earlier heads must remain on top of later members of a stack.
	for i = last_visible, 1, -1 do
		local object = objects[i]
		local spinner = rules.spinners[i]
		if spinner and not rules.states[i] then
			SpinnerRenderer.draw(spinner, time)
		end

		local slider = rules.sliders[i]
		if slider and not rules.states[i] then
			local alpha = SliderRenderer.drawBody(object, slider, time, rules.preempt, self.slider_graphics, i)
			if not rules.heads[i] then
				OsuSliderOverlayRenderer.drawHead(object, rules.radius, time, rules.preempt, sprites)
			end
			OsuSliderOverlayRenderer.drawBodyOverlays(slider, rules.radius, time, alpha,
				SliderRenderer.getSnakeEnd(object, time, rules.preempt), sprites,
				self.skin_graphics.animation_framerate)
		elseif not spinner and not rules.heads[i] then
			OsuCircleRenderer.draw(object, rules.radius, time, rules.preempt, sprites)
		end
	end

	love.graphics.setColor(1, 0.85, 0.2)
	love.graphics.circle("line", rules.x, rules.y, 9)
	love.graphics.circle("fill", rules.x, rules.y, 3)
	love.graphics.pop()
end

function OsuAimRenderer:unload()
	self.slider_graphics:unload()
	self.prepared_rules = nil
	self.skin_graphics:unload()
	self.sprites = nil
end

return OsuAimRenderer
