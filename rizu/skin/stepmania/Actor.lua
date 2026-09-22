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
---@field image love.Image?
---@field definition table?
---@field columns integer
---@field rows integer
---@field x number
---@field y number
---@field zoom_x number
---@field zoom_y number
---@field rotation_z number
---@field opacity number
---@field frame integer
---@field quad love.Quad?
---@field tweens rizu.skin.stepmania.Actor.Tween[]
---@field children rizu.skin.stepmania.Actor[]
local Actor = class()

---@param image love.Image?
---@param definition table?
---@param columns integer?
---@param rows integer?
---@param resolve fun(texture: table): love.Image?, integer?, integer?
function Actor:new(image, definition, columns, rows, resolve)
	self.image = image
	self.definition = definition
	self.columns = columns or 1
	self.rows = rows or 1
	self.x, self.y = 0, 0
	self.zoom_x, self.zoom_y = 1, 1
	self.rotation_z = 0
	self.opacity = 1
	self.frame = 0
	self.tweens = {}
	self.children = {}
	if image then
		local image_width, image_height = image:getDimensions()
		self.quad = lg.newQuad(0, 0, image_width / self.columns, image_height / self.rows, image_width, image_height)
	end
	if definition then
		for _, child_definition in ipairs(definition) do
			if type(child_definition) == "table" then
				local child_image, child_columns, child_rows
				if type(child_definition.Texture) == "table" then
					child_image, child_columns, child_rows = resolve(child_definition.Texture)
				end
				self.children[#self.children + 1] = Actor(child_image, child_definition, child_columns, child_rows, resolve)
			end
		end
		self:runCommand(definition.InitCommand)
	end
end

---@param command string|function?
function Actor:runCommand(command)
	if type(command) == "string" then
		self:playCommand(command)
	elseif type(command) == "function" then
		local proxy = setmetatable({}, {__index = function(_, name)
			return function(_, value)
				if name == "diffusealpha" then self.opacity = value
				elseif name == "zoom" then self.zoom_x, self.zoom_y = value, value
				elseif name == "zoomx" then self.zoom_x = value
				elseif name == "zoomy" then self.zoom_y = value
				elseif name == "x" then self.x = value
				elseif name == "y" then self.y = value
				elseif name == "rotationz" then self.rotation_z = math.rad(value) end
				return proxy
			end
		end})
		pcall(command, proxy)
	end
end

---@param name string
function Actor:play(name)
	self:runCommand(self.definition and self.definition[name .. "Command"])
	for _, child in ipairs(self.children) do child:play(name) end
end

---@param command string?
function Actor:playCommand(command)
	if not command or command == "" then return end
	local duration = 0
	for part in command:gmatch("[^;]+") do
		local name, value = part:match("^%s*([%a_]+)%s*,?%s*([%d%.%-]*)")
		name, value = name and name:lower(), tonumber(value)
		if name == "stoptweening" or name == "finishtweening" then
			self.tweens = {}
		elseif name == "linear" and value then
			duration = value
		elseif name == "zoom" then
			self:addTween("zoom_x", value, duration)
			self:addTween("zoom_y", value, duration)
			duration = 0
		elseif name == "zoomx" then self:addTween("zoom_x", value, duration); duration = 0
		elseif name == "zoomy" then self:addTween("zoom_y", value, duration); duration = 0
		elseif name == "x" then self:addTween("x", value, duration); duration = 0
		elseif name == "y" then self:addTween("y", value, duration); duration = 0
		elseif name == "rotationz" then self:addTween("rotation_z", math.rad(value), duration); duration = 0
		elseif name == "diffusealpha" then self:addTween("opacity", value, duration); duration = 0
		end
	end
end

---@param property string
---@param value number
---@param duration number
function Actor:addTween(property, value, duration)
	if duration == 0 then self[property] = value return end
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
	if self.image then
		if not self.definition then
			-- Plain receptor sheets advance once per beat. Actor definitions can
			-- override this with explicit Frame####/Delay#### timings.
			self.frame = math.floor(beat_modulo * self.columns * self.rows) % (self.columns * self.rows)
		else
			local frames, duration = {}, 0
			for i = 0, self.columns * self.rows - 1 do
				local frame = self.definition["Frame" .. string.format("%04d", i)]
				local delay = self.definition["Delay" .. string.format("%04d", i)]
				if type(frame) ~= "number" or type(delay) ~= "number" then break end
				frames[#frames + 1], duration = {frame = frame, delay = delay}, duration + delay
			end
			if duration > 0 then
				local time = beat_modulo * duration
				for _, entry in ipairs(frames) do
					if time < entry.delay then self.frame = entry.frame break end
					time = time - entry.delay
				end
			end
		end
	end
	for _, child in ipairs(self.children) do child:update(dt, beat_modulo) end
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param rotation number?
function Actor:draw(x, y, width, height, rotation)
	lg.push()
	lg.translate(x + self.x, y + self.y)
	lg.rotate(self.rotation_z)
	lg.scale(self.zoom_x, self.zoom_y)
	if self.image and self.opacity > 0 then
		local image_width, image_height = self.image:getDimensions()
		local frame_width, frame_height = image_width / self.columns, image_height / self.rows
		local column, row = self.frame % self.columns, math.floor(self.frame / self.columns) % self.rows
		self.quad:setViewport(column * frame_width, row * frame_height, frame_width, frame_height, image_width, image_height)
		lg.setColor(1, 1, 1, self.opacity)
		lg.draw(self.image, self.quad, 0, 0, rotation or 0, width / frame_width, height / frame_height, frame_width / 2, frame_height / 2)
	end
	for _, child in ipairs(self.children) do child:draw(0, 0, width, height, rotation) end
	lg.pop()
end

return Actor
