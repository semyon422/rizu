local class = require("class")
local Cursor = require("rizu.app.Cursor")
local loop = require("rizu.loop.Loop")
local brand = require("brand")
local Settings = require("rizu.config.Settings")

---@class rizu.WindowEvent
---@field name string
---@field [1] string?

---@class rizu.WindowModel
---@operator call: rizu.WindowModel
local WindowModel = class()

---@param settings rizu.config.Config
function WindowModel:new(settings)
	self.settings = assert(settings, "settings are required")
	self.cursor = Cursor() --[[@as rizu.Cursor]]
	self.outsideGameplay = true
end

---@return love.WindowFlags
function WindowModel:getFlags()
	local settings = self.settings
	local keys = Settings.keys.graphics
	return {
		borderless = settings:getBoolean(keys.borderless),
		centered = settings:getBoolean(keys.centered),
		displayindex = settings:getNumber(keys.display),
		fullscreen = settings:getBoolean(keys.fullscreen),
		fullscreentype = settings:getChoice(keys.fullscreen_type),
		msaa = settings:getNumber(keys.msaa),
		resizable = settings:getBoolean(keys.resizable),
		usedpiscale = settings:getBoolean(keys.usedpiscale),
		vsync = settings:getNumber(keys.vsync),
	}
end

---@return number, number
function WindowModel:getDimensions()
	if self.settings:getBoolean(Settings.keys.graphics.fullscreen) then
		return love.window.getDesktopDimensions()
	end
	local keys = Settings.keys.graphics
	return self.settings:getNumber(keys.window_width), self.settings:getNumber(keys.window_height)
end

function WindowModel:load()
	local flags = self:getFlags()
	local width, height = self:getDimensions()
	if not love.window.isOpen() then
		love.window.setMode(width, height, flags)
	end

	self:setIcon()
	love.window.setTitle(brand.name)

	self.fullscreen = flags.fullscreen
	self.fullscreentype = flags.fullscreentype
	self.vsync = flags.vsync
	self.cursor_name = self.settings:getChoice(Settings.keys.graphics.cursor)

	self.cursor:createCursors()
	self.cursor:setCursor(self.cursor_name)
end

function WindowModel:update()
	self:updateWindowState()
	local settings = self.settings
	local keys = Settings.keys.graphics

	loop:setFpsLimit(settings:getNumber(keys.fps))
	loop:setUnlimitedFps(settings:getBoolean(keys.unlimited_fps))
	loop:setAsynckey(settings:getBoolean(keys.asynckey))
	loop:setDwmFlush(settings:getBoolean(keys.dwmflush))
	loop:setBusyLoopRatio(settings:getNumber(keys.busy_loop_ratio))
	loop:setSleepFunction(settings:getChoice(keys.sleep_function))
end

function WindowModel:updateWindowState()
	local settings = self.settings
	local keys = Settings.keys.graphics
	local vsync = settings:getNumber(keys.vsync)
	if self.outsideGameplay and settings:getBoolean(keys.vsync_on_select) and vsync == 0 then
		vsync = 1
	end
	if self.vsync ~= vsync then
		self.vsync = vsync
		love.window.setVSync(self.vsync)
	end

	local fullscreen = settings:getBoolean(keys.fullscreen)
	local fullscreen_type = settings:getChoice(keys.fullscreen_type)
	if self.fullscreen ~= fullscreen or (fullscreen and self.fullscreentype ~= fullscreen_type) then
		self.fullscreen = fullscreen
		self.fullscreentype = fullscreen_type
		self:setFullscreen(fullscreen, fullscreen_type)
	end

	local cursor_name = settings:getChoice(keys.cursor)
	if self.cursor_name ~= cursor_name then
		self.cursor_name = cursor_name
		self.cursor:setCursor(cursor_name)
	end
end

---@param event rizu.WindowEvent
function WindowModel:receive(event)
	local keys = Settings.keys.graphics
	if event.name == "keypressed" and event[1] == "f10" then
		local width, height = self:getDimensions()
		love.window.updateMode(width, height, self:getFlags())
	elseif event.name == "keypressed" and event[1] == "f11" then
		local fullscreen = not self.settings:getBoolean(keys.fullscreen)
		self.settings:setBoolean(keys.fullscreen, fullscreen)
		self:setFullscreen(fullscreen, self.settings:getChoice(keys.fullscreen_type))
	end
end

---@param fullscreen boolean
---@param fullscreentype love.FullscreenType
function WindowModel:setFullscreen(fullscreen, fullscreentype)
	local keys = Settings.keys.graphics
	local width = self.settings:getNumber(keys.window_width)
	local height = self.settings:getNumber(keys.window_height)
	if fullscreen then
		width, height = love.window.getDesktopDimensions()
	end
	love.window.updateMode(width, height, {
		fullscreen = fullscreen,
		fullscreentype = fullscreentype,
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
