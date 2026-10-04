local class = require("class")
local OsuManiaImage = require("rizu.skin.osu.mania.OsuManiaImage")

local lg = love.graphics

---@class rizu.skin.osu.mania.OsuManiaLighting.Config
---@field frames rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]
---@field mode "stage"|"oneshot"|"hold"
---@field frame_rate number
---@field width number
---@field scale_y number
---@field color number[]
---@field blend_mode {[1]: string, [2]: string?}
---@field origin_x number
---@field origin_y number
---@field fit_width boolean?
---@field duration number?
---@field fade_in number?
---@field fade_out number?

---@class rizu.skin.osu.mania.OsuManiaLighting
---@operator call: rizu.skin.osu.mania.OsuManiaLighting
---@field frames rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]
---@field mode "stage"|"oneshot"|"hold"
---@field frame_rate number
---@field width number
---@field scale_y number
---@field color number[]
---@field blend_mode {[1]: string, [2]: string?}
---@field origin_x number
---@field origin_y number
---@field elapsed number
---@field active boolean
---@field held boolean
---@field fading boolean
---@field fade_elapsed number
---@field fade_duration number
---@field alpha number
---@field scale_factor number
---@field fit_width boolean
local OsuManiaLighting = class()

---@param config rizu.skin.osu.mania.OsuManiaLighting.Config
function OsuManiaLighting:new(config)
	assert(type(config.frames) == "table" and #config.frames > 0, "lighting frames are required")
	self.frames = config.frames
	self.mode = config.mode
	self.frame_rate = config.frame_rate
	self.width = config.width
	self.scale_y = config.scale_y
	self.color = config.color
	self.blend_mode = config.blend_mode
	self.origin_x = config.origin_x
	self.origin_y = config.origin_y
	self.fit_width = config.fit_width or false
	self.duration = config.duration or 0.2
	self.fade_in = config.fade_in or 0.08
	self.fade_out = config.fade_out or 0.12
	self.elapsed = 0
	self.active = false
	self.held = false
	self.fading = false
	self.fade_elapsed = 0
	self.fade_duration = 0
	self.alpha = (self.mode == "stage" and 1 or 0)
	self.scale_factor = 1
end

function OsuManiaLighting:trigger()
	self.elapsed = 0
	self.active = true
	self.held = false
	self.fading = false
	self.fade_elapsed = 0
	self.alpha = self.mode == "oneshot" and 0 or 1
	self.scale_factor = 1
end

---@param held boolean
---@param fade_duration number?
function OsuManiaLighting:setHeld(held, fade_duration)
	if self.mode ~= "stage" and self.mode ~= "hold" then return end
	if held then
		if self.held and not self.fading then return end
		self.elapsed = 0
		self.active = true
		self.held = true
		self.fading = false
		self.fade_elapsed = 0
		self.fade_duration = 0
		self.alpha = self.mode == "stage" and 1 or 0
		self.scale_factor = 1
		return
	end
	-- Only the held-to-released transition starts the fade. The renderer
	-- supplies the current held state every draw, including while fading.
	if not self.held then return end
	self.held = false
	self.fading = true
	self.fade_elapsed = 0
	self.fade_duration = math.max(fade_duration or self.fade_out, 0.001)
end

---@param dt number
function OsuManiaLighting:update(dt)
	if not self.active then return end
	self.elapsed = self.elapsed + math.max(dt, 0)

	if self.mode == "oneshot" then
		if self.elapsed < self.fade_in then
			self.alpha = self.elapsed / self.fade_in
		elseif self.elapsed < self.fade_in + self.fade_out then
			self.alpha = 1 - (self.elapsed - self.fade_in) / self.fade_out
		else
			self.alpha = 0
		end
		if self.elapsed >= math.max(self.duration, self.fade_in + self.fade_out) then
			self.active = false
		end
		return
	end

	if self.mode == "stage" and self.held then
		self.alpha = 1
		self.scale_factor = 1
		return
	end

	if self.mode == "hold" and self.held then
		self.alpha = math.min(self.elapsed / self.fade_in, 1)
		self.scale_factor = 1
		return
	end

	if self.fading then
		local progress = math.min(self.fade_elapsed / self.fade_duration, 1)
		self.alpha = 1 - progress
		if self.mode == "stage" then self.scale_factor = 1 - progress end
		self.fade_elapsed = self.fade_elapsed + math.max(dt, 0)
		progress = math.min(self.fade_elapsed / self.fade_duration, 1)
		self.alpha = 1 - progress
		if self.mode == "stage" then self.scale_factor = 1 - progress end
		if progress >= 1 then
			self.active = false
			self.fading = false
			self.alpha = 0
			self.scale_factor = 0
		end
	end
end

---@param x number
---@param y number
---@param upside_down boolean?
function OsuManiaLighting:draw(x, y, upside_down)
	if not self.active or self.alpha <= 0 then return end
	local frame_index = math.floor(self.elapsed * self.frame_rate) + 1
	if self.mode == "stage" or self.mode == "hold" then
		frame_index = (frame_index - 1) % #self.frames + 1
	else
		frame_index = math.min(frame_index, #self.frames)
	end
	local image = self.frames[frame_index]
	if not image then return end
	local image_width, image_height = OsuManiaImage.dimensions(image)
	if image_width <= 0 or image_height <= 0 then return end

	local scale_x = self.width / image_width
	local scale_y = self.fit_width and scale_x * self.scale_y or self.scale_y * self.scale_factor
	local origin_y = upside_down and 0 or self.origin_y
	if upside_down then scale_y = -scale_y end
	if scale_x <= 0 or math.abs(scale_y) <= 0 then return end

	local batch = image.texture and image.batch
	if batch and batch.collecting then
		batch:setBlendMode(self.blend_mode[1], self.blend_mode[2])
		lg.setColor(self.color[1], self.color[2], self.color[3], (self.color[4] or 1) * self.alpha)
		OsuManiaImage.draw(image, x, y, 0, scale_x, scale_y, image_width * self.origin_x,
			image_height * origin_y)
		return
	end

	if batch then batch:flush() end
	lg.push("all")
	lg.setBlendMode(self.blend_mode[1], self.blend_mode[2])
	lg.setColor(self.color[1], self.color[2], self.color[3], (self.color[4] or 1) * self.alpha)
	-- Keeping the origin at the lower edge reproduces osu!'s BottomLeft
	-- origin in normal scroll and its flipped TopLeft origin in upside-down
	-- mode when the Y scale is negative.
	OsuManiaImage.draw(image, x, y, 0, scale_x, scale_y, image_width * self.origin_x,
		image_height * origin_y)
	if batch then batch:flush() end
	lg.pop()
end

return OsuManiaLighting
