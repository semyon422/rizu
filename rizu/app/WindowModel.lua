local class = require("class")
local Cursor = require("rizu.app.Cursor")
local loop = require("rizu.loop.Loop")
local brand = require("brand")

---@class rizu.WindowFlags
---@field display integer?
---@field displayindex integer?
---@field fullscreen boolean
---@field fullscreentype love.FullscreenType
---@field highdpi boolean?
---@field vsync integer

---@class rizu.WindowDimensions
---@field width number
---@field height number

---@class rizu.WindowMode
---@field flags rizu.WindowFlags
---@field window rizu.WindowDimensions
---@field fullscreen rizu.WindowDimensions

---@class rizu.GraphicsConfig
---@field asynckey boolean
---@field busy_loop_ratio number
---@field cursor string
---@field dwmflush boolean
---@field fps number
---@field mode rizu.WindowMode
---@field sleep_function string
---@field unlimited_fps boolean
---@field vsyncOnSelect boolean

---@class rizu.WindowEvent
---@field name string
---@field [1] string?

---@class rizu.WindowModel
---@operator call: rizu.WindowModel
local WindowModel = class()

function WindowModel:new()
	self.cursor = Cursor() --[[@as rizu.Cursor]]
	self.outsideGameplay = true
end

---@param flags rizu.WindowFlags
---@return rizu.WindowFlags
local function normalizeWindowFlags(flags)
	if flags.display ~= nil and flags.displayindex == nil then
		flags.displayindex = flags.display
	end

	flags.display = nil
	flags.highdpi = nil

	return flags
end

---@param mode rizu.WindowMode
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

---@param graphics rizu.GraphicsConfig
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
	local vsync = flags.vsync
	if self.outsideGameplay and graphics.vsyncOnSelect and vsync == 0 then
		vsync = 1
	end
	if self.vsync ~= vsync then
		self.vsync = vsync
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

---@param event rizu.WindowEvent
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
---@param fullscreentype love.FullscreenType
function WindowModel:setFullscreen(fullscreen, fullscreentype)
	local mode = self.mode
	local width = mode.window.width
	local height = mode.window.height
	if self.fullscreen then
		width, height = love.window.getDesktopDimensions()
	end
	love.window.updateMode(width, height, {
		fullscreen = fullscreen,
		fullscreentype = fullscreentype
	})
end

--- Sets the window resolution and applies it immediately.
---@param width number
---@param height number
function WindowModel:setResolution(width, height)
	local mode = self.mode
	mode.window.width = width
	mode.window.height = height
	local flags = normalizeWindowFlags(mode.flags)
	love.window.updateMode(width, height, flags)
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
	self.outsideGameplay = enabled
end

---@param visible boolean
function WindowModel:setMouseVisible(visible)
	love.mouse.setVisible(visible)
end

return WindowModel
