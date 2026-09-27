local TaikoRenderer = require("rizu.skin.base.TaikoRenderer")
local OsuTaikoSkinGraphics = require("rizu.skin.osu.taiko.OsuTaikoSkinGraphics")
local Settings = require("rizu.config.Settings")

---@class rizu.skin.osu.OsuTaikoRenderer : rizu.skin.base.TaikoRenderer
---@operator call: rizu.skin.osu.OsuTaikoRenderer
---@field skin_graphics rizu.skin.osu.taiko.OsuTaikoSkinGraphics
local OsuTaikoRenderer = TaikoRenderer + {}

local WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_SPRITE_SCALE = 640, 480, 480 / 768
local BAR_Y, BAR_HEIGHT = 135, 200 * WINDOW_SPRITE_SCALE
-- Stable derives GamefieldSpriteRatio from its 512px gamefield width and forced
-- Taiko CS=-3. Outer window scaling supplies WindowManager.Ratio separately.
local GAMEFIELD_SPRITE_SCALE = (512 / 8 * (1 - 0.7 * -3 / 5)) / 128
local HIT_CIRCLE_SIZE = 113
-- GamefieldWide uses osu!'s field offset: the 384px gamefield is placed 72px
-- below the top of the 480px window (75% of the 96px vertical remainder).
local HIT_X, HIT_Y = 160, 125 + 72
-- Stable scales normal hitcircles to 65% of the large hitcircle.

---@param image love.Image
---@param x number
---@param y number
---@param width_scale number
---@param height_scale number
---@param red number
---@param green number
---@param blue number
---@param alpha number
local function drawSkinCircle(image, x, y, width_scale, height_scale, red, green, blue, alpha)
	local width, height = image:getDimensions()
	if width <= 1 or height <= 1 or width_scale <= 0 or height_scale <= 0 then return end
	love.graphics.setColor(red, green, blue, alpha)
	love.graphics.draw(image, x, y, 0, width_scale, height_scale, width / 2, height / 2)
end

---@param game sphere.GameController
function OsuTaikoRenderer:new(game)
	TaikoRenderer.new(self, game)
	self.skin_graphics = OsuTaikoSkinGraphics(game.fs)
end

---@return rizu.skin.OsuSkinDiscovery?
function OsuTaikoRenderer:getSkin()
	local registry = self.game and self.game.skinRegistry
	if not registry then return nil end
	local settings = self.game.settings
	---@type string?
	local skin_path
	if settings then
		local skin_paths = settings:getStringMap(Settings.keys.gameplay.skins)
		skin_path = skin_paths["osu/1taiko"] or skin_paths["osu/1osu"] or skin_paths.osu
	end
	if skin_path then
		local normalized_path = skin_path:gsub("\\", "/"):gsub("/+$", "")
		local skin = registry:getOsuSkin(normalized_path)
		if skin then return skin end
	end
	return registry:getOsuSkins()[1]
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@return number scale
---@return number logical_width
function OsuTaikoRenderer:getField(width, height)
	-- osu! scales its 640x480 coordinate space from viewport height, extending
	-- the logical width on widescreen rather than scaling the playfield to width.
	local scale = math.max(0.001, height / WINDOW_HEIGHT)
	return scale, width / scale
end

---@return number
function OsuTaikoRenderer:getWindowSpriteScale()
	return WINDOW_SPRITE_SCALE
end

---@return number
function OsuTaikoRenderer:getGamefieldSpriteScale()
	return GAMEFIELD_SPRITE_SCALE
end

---@param big boolean
---@return number
function OsuTaikoRenderer:getNoteSpriteScale(big)
	return self:getGamefieldSpriteScale() * (big and 1 or 0.65)
end

---@param field_width number
---@param image_width number
---@return number
function OsuTaikoRenderer:getStretchedSpriteScale(field_width, image_width)
	-- Stretch the loaded image's actual pixel width to this lane width.
	return field_width / image_width
end

---@param object_time number
---@param current_time number
---@param field_width number
---@param preempt number
---@return number x
---@return number y
function OsuTaikoRenderer:getNotePosition(object_time, current_time, field_width, preempt)
	local approach_distance = math.max(1, field_width - 40)
	return HIT_X + (object_time - current_time) * approach_distance / preempt, HIT_Y
end

function OsuTaikoRenderer:load()
	local skin = self:getSkin()
	if self.skin_graphics.skin ~= skin or not self.skin_graphics.loaded then
		self.skin_graphics:setSkin(skin)
		self.skin_graphics:load()
	end
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function OsuTaikoRenderer:draw(width, height, transform)
	local re = self.game.rhythm_engine
	local rules = re and re.taiko_rules
	if not rules then return end
	self:load()

	local scale, field_width = self:getField(width, height)
	local time = re.visual_info.time
	local images = self.skin_graphics.images

	love.graphics.push("all")
	love.graphics.applyTransform(transform)
	love.graphics.setColor(0.04, 0.05, 0.08)
	love.graphics.rectangle("fill", 0, 0, width, height)
	love.graphics.scale(scale)

	-- The long bar spans the playfield. The osu! Taiko left bar/drum sits over it.
	local bar_left, bar_right = images.bar_left, images.bar_right
	if bar_right then
		local asset_width = bar_right:getWidth()
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(bar_right, 0, BAR_Y, 0,
			self:getStretchedSpriteScale(field_width, asset_width), self:getWindowSpriteScale())
	else
		love.graphics.setColor(0.12, 0.13, 0.16)
		love.graphics.rectangle("fill", 0, BAR_Y, field_width, BAR_HEIGHT)
	end
	if bar_left then
		love.graphics.setColor(1, 1, 1)
		local left_scale = self:getWindowSpriteScale()
		love.graphics.draw(bar_left, 0, BAR_Y, 0, left_scale, left_scale)
	end

	-- Hit objects map (160, 125) through GamefieldWide's 72px field offset.
	local target_name = images.taikobigcircle and "taikobigcircle" or "taikohitcircle"
	local target = images[target_name]
	if target then
		local target_scale = self:getGamefieldSpriteScale() * 0.7
		drawSkinCircle(target, HIT_X, HIT_Y, target_scale, target_scale, 1, 1, 1, 0.48)
	end
	local inner, outer = images.drum_inner, images.drum_outer
	if inner then
		local d = self:getWindowSpriteScale()
		local drum_y = BAR_Y + 31
		love.graphics.setColor(1, 1, 1, 0.8)
		love.graphics.draw(inner, 18, drum_y, 0, d, d)
		love.graphics.draw(inner, 54, drum_y, 0, -d, d)
	end
	if outer then
		local d = self:getWindowSpriteScale()
		local drum_y = BAR_Y + 23
		love.graphics.setColor(1, 1, 1, 0.8)
		love.graphics.draw(outer, 8, drum_y, 0, -d, d)
		love.graphics.draw(outer, 53, drum_y, 0, d, d)
	end

	-- Taiko notes travel right-to-left to the osu! reference hit location.
	for i = rules.first_index, #rules.objects do
		local object, state = rules.objects[i], rules.states[i]
		local x, y = self:getNotePosition(object.time, time, field_width, rules.preempt)
		if x > field_width + 120 then break end
		if not (x < -120 and object.kind == "note") and not state.result then
			if object.kind == "note" then
				local asset_name = object.big and "taikobigcircle" or "taikohitcircle"
				local overlay_name = object.big and "taikobigcircleoverlay" or "taikohitcircleoverlay"
				local image, overlay = images[asset_name], images[overlay_name]
				local note_scale = self:getNoteSpriteScale(object.big)
				local red, green, blue = object.color == "don" and 0.92 or 0.26,
					object.color == "don" and 0.27 or 0.65,
					object.color == "don" and 0.18 or 0.82
				local size = HIT_CIRCLE_SIZE * note_scale
				if image then
					drawSkinCircle(image, x, y, note_scale, note_scale, red, green, blue, 1)
					if overlay then
						drawSkinCircle(overlay, x, y, note_scale, note_scale, 1, 1, 1, 1)
					end
				else
					love.graphics.setColor(red, green, blue)
					love.graphics.circle("fill", x, y, size / 2)
				end
			else
				local end_x = self:getNotePosition(object.end_time, time, field_width, rules.preempt)
				local left, right = math.max(x, 0), math.min(end_x, field_width + 80)
				if right > left then
					local middle, end_image = images.roll_middle, images.roll_end
					if middle and end_image then
						love.graphics.setColor(1, 1, 1)
						local iw, ih = middle:getDimensions()
						local middle_scale = self:getGamefieldSpriteScale()
						love.graphics.draw(middle, left, y - ih * middle_scale / 2, 0,
							self:getStretchedSpriteScale(right - left, iw), middle_scale)
						local ew, eh = end_image:getDimensions()
						local end_scale = self:getGamefieldSpriteScale()
						love.graphics.draw(end_image, right - ew * end_scale / 2,
							y - eh * end_scale / 2, 0, end_scale, end_scale)
					else
						love.graphics.setColor(object.kind == "roll" and 1 or 0.72,
							object.kind == "roll" and 0.67 or 0.35, 0.12)
						love.graphics.setLineWidth(HIT_CIRCLE_SIZE * GAMEFIELD_SPRITE_SCALE)
						love.graphics.line(left, y, right, y)
					end
				end
			end
		end
	end

	love.graphics.pop()
end

function OsuTaikoRenderer:unload()
	self.skin_graphics:unload()
end

return OsuTaikoRenderer
