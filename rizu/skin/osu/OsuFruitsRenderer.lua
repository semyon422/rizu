local FruitsRenderer = require("rizu.skin.base.FruitsRenderer")
local OsuFruitsGraphics = require("rizu.skin.osu.fruits.OsuFruitsGraphics")
local Settings = require("rizu.config.Settings")

local fruits = {"pear", "grapes", "apple", "orange"}

---@class rizu.skin.osu.OsuFruitsRenderer : rizu.skin.base.FruitsRenderer
---@operator call: rizu.skin.osu.OsuFruitsRenderer
---@field skin_graphics rizu.skin.osu.fruits.OsuFruitsGraphics
---@field hyperdash_color number[]
---@field hyperdash_fruit_color number[]
local OsuFruitsRenderer = FruitsRenderer + {}

---@param game sphere.GameController
function OsuFruitsRenderer:new(game)
	FruitsRenderer.new(self, game)
	self.skin_graphics = OsuFruitsGraphics(game.fs)
	self.hyperdash_color = {1, 0, 0}
	self.hyperdash_fruit_color = {1, 0, 0}
end

---@return rizu.skin.OsuSkinDiscovery?
function OsuFruitsRenderer:getSkin()
	local registry = self.game and self.game.skinRegistry
	if not registry then return nil end

	local settings = self.game.settings
	local skin_path
	if settings then
		local skin_paths = settings:getStringMap(Settings.keys.gameplay.skins)
		skin_path = skin_paths["osu/1fruits"] or skin_paths["osu/1osu"] or skin_paths.osu
	end
	if skin_path then
		local normalized_path = skin_path:gsub("\\", "/"):gsub("/+$", "")
		local skin = registry:getOsuSkin(normalized_path)
		if skin then return skin end
	end
	return registry:getOsuSkins()[1]
end

---@param value string?
---@param fallback number[]
---@return number[]
local function parseColor(value, fallback)
	if not value then return fallback end
	local red, green, blue = value:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
	if not red then return fallback end
	return {
		math.max(0, math.min(255, tonumber(red))) / 255,
		math.max(0, math.min(255, tonumber(green))) / 255,
		math.max(0, math.min(255, tonumber(blue))) / 255,
	}
end

function OsuFruitsRenderer:load()
	local skin = self:getSkin()
	if self.skin_graphics.skin ~= skin then
		self.skin_graphics:setSkin(skin)
		self.skin_graphics:load()
	elseif not self.skin_graphics.loaded then
		self.skin_graphics:load()
	end
	local catch = skin and skin.skin_ini.CatchTheBeat
	self.hyperdash_color = parseColor(catch and catch.HyperDash, {1, 0, 0})
	self.hyperdash_fruit_color = parseColor(catch and catch.HyperDashFruit, self.hyperdash_color)
end

function OsuFruitsRenderer:unload()
	self.skin_graphics:unload()
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@return number scale
---@return number x
---@return number y
function OsuFruitsRenderer:getField(width, height)
	local scale = math.max(0.001, math.min(width / 640, height / 480))
	return scale, (width - 512 * scale) / 2, (height - 384 * scale) / 2
end

---@param x number Window x coordinate in drawable pixels
---@param y number Window y coordinate in drawable pixels
---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform
---@return number
---@return number
function OsuFruitsRenderer:toChart(x, y, width, height, transform)
	x, y = transform:inverseTransformPoint(x, y)
	local scale, ox, oy = self:getField(width, height)
	return (x - ox) / scale, (y - oy) / scale
end

---@param sprite rizu.skin.osu.fruits.Image?
---@param x number
---@param y number
---@param reference_size number
---@param alpha number
---@param color number[]?
---@param rotation number?
local function drawSprite(sprite, x, y, reference_size, alpha, color, rotation)
	if not sprite then return false end
	local image = sprite.image
	local width, height = image:getDimensions()
	if width <= 1 or height <= 1 or reference_size <= 0 then return false end
	local scale = reference_size / width
	color = color or {1, 1, 1}
	love.graphics.setColor(color[1], color[2], color[3], alpha)
	love.graphics.draw(image, x, y, rotation or 0, scale, scale, width / 2, height / 2)
	return true
end

---@param rules rizu.catch.Rules
---@param time number
---@param sprites rizu.skin.osu.fruits.OsuFruitsGraphics.Images
---@param hyperdash_fruit_color number[]
local function drawObjects(rules, time, sprites, hyperdash_fruit_color)
	local objects = rules.objects
	local preempt = rules.preempt
	local fruit_size = 64 * (1 - 0.7 * ((rules.chart.data.circle_size - 5) / 5))
	-- Missed fruits keep falling for the short interval between the catcher
	-- line and the bottom edge of the 384px gamefield.
	local first_index = rules.next_index
	local fall_tail = preempt * (384 + fruit_size / 2 - 340) / 440
	while first_index > 1 and objects[first_index - 1].time >= time - fall_tail do
		first_index = first_index - 1
	end
	for index = first_index, #objects do
		local object = objects[index]
		local remaining = object.time - time
		if remaining > preempt then break end
		if rules.states[index] ~= "hit" then
			local progress = math.max(0, 1 - remaining / preempt)
			local x = object.x
			local y = -100 + 440 * progress
			local name, size_factor
			if object.kind == "tiny" then
				name, size_factor = "drop", 0.4
			elseif object.kind == "droplet" then
				name, size_factor = "drop", 0.8
			elseif object.kind == "banana" then
				name, size_factor = "bananas", 1 - 0.4 * progress
			else
				name, size_factor = fruits[(index - 1) % #fruits + 1], 1
			end
			local elapsed = preempt * progress
			local alpha = 1
			local fruit_sprites = sprites.fruits[name]
			local hyperdash = rules.hyper_targets[index] ~= nil
			local image = fruit_sprites and fruit_sprites.image
			local base_width = image and image.image:getWidth() * image.density or 128
			local sprite_size = base_width * fruit_size / 128 * size_factor
			if image then
				local rotation = object.kind == "banana" and elapsed * (0.5 + index % 3 * 0.15) or nil
				if hyperdash then
					local pulse = 1 + 0.12 * math.sin(elapsed * math.pi * 4)
					drawSprite(image, x, y, sprite_size * pulse, alpha, hyperdash_fruit_color, rotation)
				else
					drawSprite(image, x, y, sprite_size, alpha, nil, rotation)
				end
				if fruit_sprites.overlay then
					drawSprite(fruit_sprites.overlay, x, y, sprite_size, alpha)
				end
			else
				if object.kind == "tiny" then love.graphics.setColor(0.5, 0.8, 1, alpha)
				elseif object.kind == "droplet" then love.graphics.setColor(0.4, 0.7, 1, alpha)
				elseif object.kind == "banana" then love.graphics.setColor(1, 0.85, 0.2, alpha)
				else love.graphics.setColor(1, 0.4, 0.4, alpha) end
				love.graphics.circle("fill", x, y, math.max(2, sprite_size / 2))
			end
			if hyperdash then
				love.graphics.setColor(hyperdash_fruit_color[1], hyperdash_fruit_color[2], hyperdash_fruit_color[3], 0.85)
				love.graphics.setLineWidth(2)
				love.graphics.circle("line", x, y, sprite_size * 0.62)
			end
		end
	end
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function OsuFruitsRenderer:draw(width, height, transform)
	local re = self.game.rhythm_engine
	local rules = re and re.catch_rules
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

	drawObjects(rules, time, sprites, self.hyperdash_fruit_color)

	local catcher_frames = sprites.catcher.idle
	local last_event = rules.events[#rules.events]
	if last_event and not last_event.hit then
		catcher_frames = sprites.catcher.fail
	elseif rules.time < rules.hyper_until or rules:isDash() then
		catcher_frames = sprites.catcher.kiai
	end
	if #catcher_frames == 0 then catcher_frames = sprites.catcher.fail end
	if #catcher_frames > 0 then
		local framerate = self.skin_graphics.animation_framerate or #catcher_frames
		local frame = math.floor(math.max(0, time) * framerate) % #catcher_frames + 1
		local catcher_scale = 0.7 * (1 - 0.7 * ((rules.chart.data.circle_size - 5) / 5)) / 2
		local catcher = catcher_frames[frame]
		local sprite = catcher.image
		local width_px = sprite:getWidth()
		local factor = catcher_scale
		local tint = rules.time < rules.hyper_until and self.hyperdash_color or {1, 1, 1}
		love.graphics.setColor(tint[1], tint[2], tint[3], 1)
		love.graphics.draw(sprite, rules.x, 340 - 16 * catcher_scale,
			0, factor, factor, width_px / 2, 0)
	else
		if rules.time < rules.hyper_until then love.graphics.setColor(self.hyperdash_color)
		elseif rules:isDash() then love.graphics.setColor(1, 0.85, 0.2)
		else love.graphics.setColor(0.4, 1, 0.65) end
		love.graphics.setLineWidth(10)
		love.graphics.line(rules.x - rules.half_width, 340, rules.x + rules.half_width, 340)
	end
	love.graphics.pop()
end

return OsuFruitsRenderer
