local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")

local CYCLE_SECONDS = 2
local HUE_STEP = 0.06

---@param hue number 0..1
---@return number r
---@return number g
---@return number b
local function hueToRgb(hue)
	local h = hue % 1 * 6
	local x = 1 - math.abs(h % 2 - 1)
	if h < 1 then return 1, x, 0 end
	if h < 2 then return x, 1, 0 end
	if h < 3 then return 0, 1, x end
	if h < 4 then return 0, x, 1 end
	if h < 5 then return x, 0, 1 end
	return 1, 0, x
end

local TITLE = "xXx CH34TS 3N4BL3D xXx"

---@param settings rizu.config.Config
---@return string[] lines
local function formatProperties(settings)
	local keys = Settings.keys.gameplay
	local tempo = settings:getChoice(keys.tempo_factor)
	if tempo == "primary" then
		tempo = ("primary %d bpm"):format(settings:getNumber(keys.primary_tempo))
	end
	return {
		("Tempo: %s"):format(tempo),
		("Swap current/local velocity: %s"):format(settings:getBoolean(keys.swap_velocity_type) and "on" or "off"),
		("Input offset: %+d ms"):format(math.floor(settings:getNumber(keys.offset_input) * 1000 + 0.5)),
	}
end

---Rainbow label that is always visible while cheats are enabled.
---@class ui.views.CheatsLabel : gui.View
---@operator call: ui.views.CheatsLabel
---@field title_font love.Font
---@field font love.Font
---@field lines string[]
---@field time number
---@field private unsubscribers function[]
local CheatsLabel = View + {}

---@param settings rizu.config.Config
function CheatsLabel:new(settings)
	View.new(self)
	self.title_font = Resources.getFont("bold", 16)
	self.font = Resources.getFont("regular", 14)
	self.time = 0
	self.lines = {}
	local function refresh()
		self.lines = formatProperties(settings)
		local width = self.title_font:getWidth(TITLE)
		for _, line in ipairs(self.lines) do
			width = math.max(width, self.font:getWidth(line))
		end
		self:setSize(width, self.title_font:getHeight() + #self.lines * self.font:getHeight())
	end
	refresh()
	local cheats_key = Settings.keys.misc.enable_cheats
	self:setVisible(settings:getBoolean(cheats_key))
	self.unsubscribers = {
		settings:subscribeBoolean(cheats_key, function(value)
			self:setVisible(value)
		end),
	}
	for _, key in ipairs(Settings.cheat_keys) do
		self.unsubscribers[#self.unsubscribers + 1] = settings:subscribe(key, refresh)
	end
end

---@param dt number
function CheatsLabel:update(dt)
	if self.visible then
		self.time = (self.time + dt) % CYCLE_SECONDS
	end
end

function CheatsLabel:unload()
	for _, unsubscribe in ipairs(self.unsubscribers) do
		unsubscribe()
	end
end

function CheatsLabel:draw()
	Painter.snapToPixel()
	love.graphics.setFont(self.title_font)
	local colored = {}
	for i = 1, #TITLE do
		local r, g, b = hueToRgb(self.time / CYCLE_SECONDS - i * HUE_STEP)
		colored[#colored + 1] = {r, g, b, 1}
		colored[#colored + 1] = TITLE:sub(i, i)
	end
	Painter.setColorRgb(1, 1, 1, 1)
	love.graphics.print(colored, 0, 0)

	love.graphics.setFont(self.font)
	local y = self.title_font:getHeight()
	for _, line in ipairs(self.lines) do
		love.graphics.print(line, 0, y)
		y = y + self.font:getHeight()
	end
end

return CheatsLabel
