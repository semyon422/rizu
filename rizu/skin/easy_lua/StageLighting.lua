local class = require("class")

---@class rizu.skin.easy_lua.StageLighting.Config
---@field image love.Image? Single image to display when triggered; mutually exclusive with frames.
---@field fit_width boolean? Fit image frame width to width; defaults to true only when width is given.
---@field frames love.Image[]? Animation frames in playback order.
---@field width number? Full animation width in native units; defaults to the first frame width.
---@field scale_y number? Vertical image scale; defaults to 1.
---@field offset_x number? Offset from the column center; defaults to 0.
---@field offset_y number? Offset from the hit position; defaults to 0.
---@field duration number? Animation duration in seconds; defaults to frame count / frame_rate, or 0.2 for a single image.
---@field frame_rate number? Animation frames per second; defaults to 60.
---@field animation "shrink"|"fade"? Animation applied to scale/alpha; defaults to "shrink".
---@field origin_x number? Normalized horizontal image origin in [0, 1]; defaults to 0.5.
---@field origin_y number? Normalized vertical image origin in [0, 1]; defaults to 0.5.
---@field blend_mode {[1]: string, [2]: string?}? LÖVE blend mode and optional alpha mode.
---@field color number[]? RGBA tint; defaults to white with 0.15 alpha.

---@class rizu.skin.easy_lua.StageLighting
---@operator call: rizu.skin.easy_lua.StageLighting
---@field image love.Image
---@field frames love.Image[]
---@field fit_width boolean
---@field scale_y number
---@field offset_x number
---@field offset_y number
---@field duration number
---@field frame_rate number
---@field animation "shrink"|"fade"
---@field origin_x number
---@field origin_y number
---@field blend_mode {[1]: string, [2]: string?}?
---@field color number[]
---@field elapsed number
---@field active boolean
local StageLighting = class()

---@param config rizu.skin.easy_lua.StageLighting.Config
function StageLighting:new(config)
	assert(type(config) == "table", "stage lighting config must be a table")
	assert(not (config.image and config.frames), "specify either image or frames, not both")
	local frames = config.frames
	if not frames and config.image then
		frames = {config.image}
	end
	assert(type(frames) == "table" and #frames > 0, "stage lighting image or non-empty frames are required")
	for index, frame in ipairs(frames) do
		assert(frame and type(frame.getDimensions) == "function",
			("stage lighting frame %d must be a Love image"):format(index))
	end

	self.frames = frames
	self.image = frames[1]
	local image_width = self.image:getWidth()
	self.width = config.width or image_width
	if config.fit_width == nil then
		self.fit_width = config.width ~= nil
	else
		assert(type(config.fit_width) == "boolean", "stage lighting fit_width must be a boolean")
		self.fit_width = config.fit_width
	end
	self.scale_y = config.scale_y or 1
	self.offset_x = config.offset_x or 0
	self.offset_y = config.offset_y or 0
	self.frame_rate = config.frame_rate or 60
	self.duration = config.duration or (#frames > 1 and #frames / self.frame_rate or 0.2)
	self.animation = config.animation or "shrink"
	self.origin_x = config.origin_x or 0.5
	self.origin_y = config.origin_y or 0.5
	self.blend_mode = config.blend_mode
	self.color = config.color or {1, 1, 1, 0.15}
	self.elapsed = 0
	self.active = false

	assert(type(self.width) == "number" and self.width > 0 and self.width < math.huge,
		"stage lighting width must be positive and finite")
	assert(type(self.scale_y) == "number" and self.scale_y == self.scale_y and math.abs(self.scale_y) < math.huge,
		"stage lighting scale_y must be finite")
	assert(type(self.offset_x) == "number" and self.offset_x == self.offset_x and math.abs(self.offset_x) < math.huge,
		"stage lighting offset_x must be finite")
	assert(type(self.offset_y) == "number" and self.offset_y == self.offset_y and math.abs(self.offset_y) < math.huge,
		"stage lighting offset_y must be finite")
	assert(type(self.frame_rate) == "number" and self.frame_rate > 0 and self.frame_rate < math.huge,
		"stage lighting frame_rate must be positive and finite")
	assert(type(self.duration) == "number" and self.duration > 0 and self.duration < math.huge,
		"stage lighting duration must be positive and finite")
	assert(type(self.animation) == "string" and (self.animation == "shrink" or self.animation == "fade"),
		"stage lighting animation must be 'shrink' or 'fade'")
	assert(type(self.origin_x) == "number" and self.origin_x == self.origin_x
		and self.origin_x >= 0 and self.origin_x <= 1, "stage lighting origin_x must be between 0 and 1")
	assert(type(self.origin_y) == "number" and self.origin_y == self.origin_y
		and self.origin_y >= 0 and self.origin_y <= 1, "stage lighting origin_y must be between 0 and 1")
	if self.blend_mode then
		assert(type(self.blend_mode) == "table" and type(self.blend_mode[1]) == "string"
			and (self.blend_mode[2] == nil or type(self.blend_mode[2]) == "string"),
			"stage lighting blend_mode must contain a mode and optional alpha mode")
	end
	assert(type(self.color) == "table" and #self.color >= 3 and #self.color <= 4,
		"stage lighting color must be RGB or RGBA")
	for i = 1, #self.color do
		local channel = self.color[i]
		assert(type(channel) == "number" and channel == channel and channel >= 0 and channel <= 1,
			"stage lighting color channels must be between 0 and 1")
	end
end

function StageLighting:trigger()
	self.elapsed = 0
	self.active = true
end

---@param dt number
function StageLighting:update(dt)
	if not self.active then return end
	self.elapsed = self.elapsed + dt
	if self.elapsed >= self.duration then
		self.elapsed = self.duration
		self.active = false
	end
end

---@param x number Column centerline.
---@param hit_y number Column hit position.
function StageLighting:draw(x, hit_y)
	if not self.active then return end
	local progress = math.min(self.elapsed / self.duration, 1)
	local frame_index = math.min(math.floor(self.elapsed * self.frame_rate) + 1, #self.frames)
	local image = self.frames[frame_index]
	local scale_factor = self.animation == "shrink" and (1 - progress) * (1 - progress) or 1
	local alpha = (self.color[4] or 1) * (self.animation == "fade" and (1 - progress) or 1)
	local image_width, image_height = image:getDimensions()
	local scale_x = (self.fit_width and self.width / image_width or 1) * scale_factor
	if scale_x <= 0 or alpha <= 0 then return end

	love.graphics.push("all")
	if self.blend_mode then
		love.graphics.setBlendMode(self.blend_mode[1], self.blend_mode[2])
	end
	love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
	love.graphics.draw(image, x + self.offset_x, hit_y + self.offset_y, 0,
		scale_x, self.scale_y, image_width * self.origin_x, image_height * self.origin_y)
	love.graphics.pop()
end

return StageLighting
