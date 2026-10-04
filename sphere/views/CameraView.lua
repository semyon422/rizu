local class = require("class")
local s3dc = require("s3dc")
local Settings = require("rizu.config.Settings")

---@param settings rizu.config.Config
---@return sphere.views.CameraView.Perspective
local function getPerspective(settings)
	local keys = Settings.keys.graphics
	return {
		camera = settings:getBoolean(keys.perspective_camera),
		rx = settings:getBoolean(keys.perspective_rx),
		ry = settings:getBoolean(keys.perspective_ry),
		x = settings:getNumber(keys.perspective_x),
		y = settings:getNumber(keys.perspective_y),
		z = settings:getNumber(keys.perspective_z),
		pitch = settings:getNumber(keys.perspective_pitch),
		yaw = settings:getNumber(keys.perspective_yaw),
	}
end

---@param settings rizu.config.Config
---@param perspective {x: number, y: number, z: number, pitch: number, yaw: number}
local function setPerspective(settings, perspective)
	local keys = Settings.keys.graphics
	settings:setNumber(keys.perspective_x, perspective.x)
	settings:setNumber(keys.perspective_y, perspective.y)
	settings:setNumber(keys.perspective_z, perspective.z)
	settings:setNumber(keys.perspective_pitch, perspective.pitch)
	settings:setNumber(keys.perspective_yaw, perspective.yaw)
end

---@class sphere.views.CameraView.Perspective
---@field camera boolean
---@field rx boolean
---@field ry boolean
---@field x number
---@field y number
---@field z number
---@field pitch number
---@field yaw number

---@class sphere.CameraView
---@operator call: sphere.CameraView
---@field game sphere.GameController
local CameraView = class()

CameraView.sensitivity = 0.5
CameraView.speed = 500

function CameraView:load()
	local perspective = getPerspective(self.game.settings)
	self.camera = perspective.camera
	if not self.camera or not self.draw_start then
		return
	end
	self:loadCamera()
end

function CameraView:loadCamera()
	s3dc.load()
	local w, h = love.graphics.getDimensions()
	self.w, self.h = w, h
	local perspective = getPerspective(self.game.settings)
	s3dc.translate(perspective.x * w, perspective.y * h, perspective.z * h)
	s3dc.rotate(perspective.pitch, perspective.yaw)
end

function CameraView:unload()
	if not self.camera or not self.draw_start then
		return
	end

	local w, h = self.w, self.h
	local x, y, z = unpack(s3dc.pos)
	local perspective = {
		x = x / w,
		y = y / h,
		z = z / h,
		pitch = s3dc.angle.pitch,
		yaw = s3dc.angle.yaw,
	}
	setPerspective(self.game.settings, perspective)
end

---@param event table
function CameraView:receive(event)
	if not self.draw_start then
		return
	end

	if event.name == "keypressed" and self.camera then
		local key = event[2]
		if key == "f10" then
			s3dc.show(0, 0, love.graphics.getDimensions())
		elseif key == "f9" then
			self.moveCamera = not self.moveCamera
			self:unload()
		end
	elseif event.name == "mousepressed" and self.moveCamera then
		local button = event[3]
		if button == 1 then
			self.dragging = true
			love.mouse.setRelativeMode(true)
		end
	elseif event.name == "mousereleased" and self.moveCamera then
		local button = event[3]
		if button == 1 then
			self.dragging = false
			love.mouse.setRelativeMode(false)
		end
	elseif event.name == "mousemoved" and self.dragging and self.camera and self.moveCamera then
		local dx, dy = event[3], event[4]
		local angle = self.sensitivity

		local perspective = getPerspective(self.game.settings)
		if not perspective.ry then
			dy = 0
		end
		if not perspective.rx then
			dx = 0
		end
		s3dc.rotate(math.rad(-dy) * angle, math.rad(dx) * angle)
	end
end

---@param dt number
function CameraView:update(dt)
	if not self.draw_start then
		return
	end

	local w, h = love.graphics.getDimensions()
	if self.w ~= w or self.h ~= h then
		self:unload()
		self:loadCamera()
	end

	if not self.camera or not self.moveCamera then
		return
	end

	local dx = self.speed * dt
	if love.keyboard.isDown("a") then
		s3dc.left(dx)
	elseif love.keyboard.isDown("d") then
		s3dc.right(dx)
	end
	if love.keyboard.isDown("w") then
		s3dc.forward(dx)
	elseif love.keyboard.isDown("s") then
		s3dc.backward(dx)
	end
	if love.keyboard.isDown("lshift") then
		s3dc.down(dx)
	elseif love.keyboard.isDown("space") then
		s3dc.up(dx)
	end
end

function CameraView:draw()
	if not self.camera then
		return
	end

	if self.draw_start then
		s3dc.draw_start()
	end
	if self.draw_end then
		s3dc.draw_end()
	end
end

return CameraView
