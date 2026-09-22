local class = require("class")

local lg = love.graphics

---@class rizu.skin.stepmania.Actor.Tween
---@field duration number
---@field elapsed number
---@field from number
---@field to number
---@field property string

---@class rizu.skin.stepmania.Actor
---@operator call: rizu.skin.stepmania.Actor
---@field image love.Image
---@field definition table?
---@field columns integer
---@field rows integer
---@field x number
---@field y number
---@field zoom_x number
---@field zoom_y number
---@field rotation_z number
---@field frame integer
---@field quad love.Quad
---@field tweens rizu.skin.stepmania.Actor.Tween[]
local Actor = class()

---@param image love.Image
---@param definition table?
---@param columns integer?
---@param rows integer?
function Actor:new(image, definition, columns, rows)
	self.image = image
	self.definition = definition
	self.columns = columns or 1
	self.rows = rows or 1
	self.x, self.y = 0, 0
	self.zoom_x, self.zoom_y = 1, 1
	self.rotation_z = 0
	self.frame = 0
	local image_width, image_height = image:getDimensions()
	self.quad = lg.newQuad(0, 0, image_width / self.columns, image_height / self.rows, image_width, image_height)
	self.tweens = {}
end

---@param command string?
function Actor:playCommand(command)
	if not command or command == "" then return end
	local duration = 0
	for part in command:gmatch("[^;]+") do
		local name, value = part:match("^%s*([%a_]+)%s*,?%s*([%d%.%-]*)")
		name = name and name:lower()
		value = tonumber(value)
		if name == "stoptweening" then
			self.tweens = {}
		elseif name == "linear" and value then
			duration = value
		elseif name:lower() == "zoom" then
			self:addTween("zoom_x", value, duration)
			self:addTween("zoom_y", value, duration)
			duration = 0
		elseif name:lower() == "zoomx" then
			self:addTween("zoom_x", value, duration)
			duration = 0
		elseif name:lower() == "zoomy" then
			self:addTween("zoom_y", value, duration)
			duration = 0
		elseif name:lower() == "x" then
			self:addTween("x", value, duration)
			duration = 0
		elseif name:lower() == "y" then
			self:addTween("y", value, duration)
			duration = 0
		elseif name:lower() == "rotationz" then
			self:addTween("rotation_z", math.rad(value), duration)
			duration = 0
		end
	end
end

---@param property string
---@param value number
---@param duration number
function Actor:addTween(property, value, duration)
	if duration == 0 then
		self[property] = value
		return
	end
	table.insert(self.tweens, {property = property, from = self[property], to = value, duration = duration, elapsed = 0})
end

---@param dt number
---@param beat_modulo number
function Actor:update(dt, beat_modulo)
	for i = #self.tweens, 1, -1 do
		local tween = self.tweens[i]
		tween.elapsed = tween.elapsed + dt
		local progress = math.min(tween.elapsed / tween.duration, 1)
		self[tween.property] = tween.from + (tween.to - tween.from) * progress
		if progress == 1 then table.remove(self.tweens, i) end
	end

	local definition = self.definition
	if not definition then
		self.frame = math.floor(beat_modulo * self.columns * self.rows) % (self.columns * self.rows)
		return
	end
	local frames, duration = {}, 0
	for i = 0, self.columns * self.rows - 1 do
		local frame = definition["Frame" .. string.format("%04d", i)]
		local delay = definition["Delay" .. string.format("%04d", i)]
		if type(frame) ~= "number" or type(delay) ~= "number" then break end
		frames[#frames + 1] = {frame = frame, delay = delay}
		duration = duration + delay
	end
	if duration == 0 then return end
	local time = beat_modulo * duration
	for _, entry in ipairs(frames) do
		if time < entry.delay then self.frame = entry.frame return end
		time = time - entry.delay
	end
	self.frame = frames[#frames].frame
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param rotation number?
function Actor:draw(x, y, width, height, rotation)
	local image_width, image_height = self.image:getDimensions()
	local frame_width, frame_height = image_width / self.columns, image_height / self.rows
	local column = self.frame % self.columns
	local row = math.floor(self.frame / self.columns) % self.rows
	self.quad:setViewport(column * frame_width, row * frame_height, frame_width, frame_height, image_width, image_height)
	lg.draw(self.image, self.quad, x + self.x, y + self.y, (rotation or 0) + self.rotation_z,
		width / frame_width * self.zoom_x, height / frame_height * self.zoom_y, frame_width / 2, frame_height / 2)
end

return Actor
