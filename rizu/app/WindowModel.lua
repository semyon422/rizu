local class = require("class")
local Cursor = require("rizu.app.Cursor")
local loop = require("rizu.loop.Loop")
local brand = require("brand")

---@class rizu.WindowModel
---@operator call: rizu.WindowModel
local WindowModel = class()

function WindowModel:new()
	self.cursor = Cursor()
end

WindowModel.baseVsync = 1

---@param flags table
---@return table
local function normalizeWindowFlags(flags)
	if flags.display ~= nil and flags.displayindex == nil then
		flags.displayindex = flags.display
	end

	flags.display = nil
	flags.highdpi = nil

	return flags
end

---@param mode table
---@return number
---@return number
local function getDimensions(mode)
	local flags = mode.flags
	if flags.fullscreen then
		return love.window.getDesktopDimensions()
	else
		return mode.window.width, mode.window.height
	end
end

---@param graphics table
function WindowModel:load(graphics)
	self.graphics = graphics
	self.mode = self.graphics.mode
	local mode = self.mode
	local flags = mode.flags
	local normalizedFlags = normalizeWindowFlags(flags)

	local width, height = getDimensions(mode)
	if not love.window.isOpen() then
		love.window.setMode(width, height, normalizedFlags)
	end

	self:setIcon()
	love.window.setTitle(brand.name)

	self.fullscreen = flags.fullscreen
	self.fullscreentype = flags.fullscreentype
	self.vsync = flags.vsync
	self.cursor_name = self.graphics.cursor

	self.cursor:createCursors()
	self.cursor:setCursor(self.cursor_name)
end

function WindowModel:update()
	self:updateWindowState()
	local graphics = self.graphics

	loop:setFpsLimit(graphics.fps)
	loop:setUnlimitedFps(graphics.unlimited_fps)
	loop:setAsynckey(graphics.asynckey)
	loop:setDwmFlush(graphics.dwmflush)
	loop:setBusyLoopRatio(graphics.busy_loop_ratio)
	loop:setSleepFunction(graphics.sleep_function)
end

function WindowModel:updateWindowState()
	local flags = self.mode.flags
	local graphics = self.graphics
	if self.vsync ~= flags.vsync then
		self.vsync = flags.vsync
		love.window.setVSync(self.vsync)
	end
	if self.fullscreen ~= flags.fullscreen or (self.fullscreen and self.fullscreentype ~= flags.fullscreentype) then
		self.fullscreen = flags.fullscreen
		self.fullscreentype = flags.fullscreentype
		self:setFullscreen(self.fullscreen, self.fullscreentype)
	end
	if self.cursor_name ~= graphics.cursor then
		self.cursor_name = graphics.cursor
		self.cursor:setCursor(self.cursor_name)
	end
end

---@param event table
function WindowModel:receive(event)
	if event.name == "keypressed" and event[1] == "f10" then
		local mode = self.mode
		local flags = normalizeWindowFlags(mode.flags)
		local width, height = getDimensions(mode)
		love.window.updateMode(width, height, flags)
	elseif event.name == "keypressed" and event[1] == "f11" then
		local mode = self.mode
		self.fullscreen = not self.fullscreen
		mode.flags.fullscreen = self.fullscreen
		self:setFullscreen(self.fullscreen, mode.flags.fullscreentype)
	end
end

---@param fullscreen boolean
---@param fullscreentype string
function WindowModel:setFullscreen(fullscreen, fullscreentype)
	local mode = self.mode
	local width, height
	if self.fullscreen then
		width, height = love.window.getDesktopDimensions()
	else
		width, height = mode.window.width, mode.window.height
	end
	love.window.updateMode(width, height, {
		fullscreen = fullscreen,
		fullscreentype = fullscreentype
	})
end

local icon_path = "resources/logo.png"
function WindowModel:setIcon()
	local info = love.filesystem.getInfo(icon_path)
	if not info then
		print("Load logo: not found")
		return
	end

	local ok, imageData = pcall(love.image.newImageData, icon_path)
	if not ok then
		print("Load logo: " .. imageData)
		return
	end

	love.window.setIcon(imageData)
end

---@param enabled boolean
function WindowModel:setVsyncOnSelect(enabled)
	local graphics = self.graphics
	if not graphics.vsyncOnSelect then
		return
	end
	local flags = graphics.mode.flags
	if not enabled then
		self.baseVsync = flags.vsync ~= 0 and flags.vsync or 1
		flags.vsync = 0
	elseif flags.vsync == 0 then
		flags.vsync = self.baseVsync
	end
end

---@param visible boolean
function WindowModel:setMouseVisible(visible)
	love.mouse.setVisible(visible)
end

return WindowModel
