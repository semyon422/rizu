local View = require("gui.View")
local Painter = require("gui.Painter")
local Easing = require("gui.anim.Easing")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local utf8 = require("utf8")

---The first trip from the main menu to song select in a session: tiles ripple in from the
---Play button, the logo shows between two scrolling bands, then the tiles sweep away.
---It calls on_covered once the screen is hidden and removes itself when done.
---@class ui.screens.main_menu.WelcomeTransition : gui.View
---@operator call: ui.screens.main_menu.WelcomeTransition
---@field time number
---@field on_covered fun()?
---@field origin_x number Window-space point the tiles ripple from
---@field origin_y number
---@field band_text love.TextBatch
---@field band_unit number Width of one word and its gap
local WelcomeTransition = View + {}

local ROWS = 9
local TILE_IN_SPREAD, TILE_IN = 0.42, 0.32
local TILE_OUT_START, TILE_OUT_SPREAD, TILE_OUT_STAGGER, TILE_OUT = 1.42, 0.38, 0.12, 0.26
local LOGO_IN_START, LOGO_IN = 0.52, 0.3
local LOGO_OUT_START, LOGO_OUT = 1.3, 0.22
local BAND_IN_START, BAND_IN = 0.25, 0.45
local BAND_OUT_START, BAND_OUT = 1.3, 0.3
WelcomeTransition.COVERED = 0.76
WelcomeTransition.DURATION = TILE_OUT_START + TILE_OUT_SPREAD + TILE_OUT_STAGGER + TILE_OUT

local LOGO_W, LOGO_H = 600, 230
local BAND_H, BAND_GAP = 44, 56 -- band height, distance from the logo
local BAND_TRAVEL = 380
local BAND_SPEED = 120
local BAND_TRACKING = 6
local TILE_ALT = {0x17 / 255, 0x14 / 255, 0x1E / 255, 1}

local out_quart = Easing.resolve("OutQuart")
local in_quad = Easing.resolve("InQuad")
local in_cubic = Easing.resolve("InCubic")

---@param t number
---@param start number
---@param duration number
---@return number progress in [0, 1]
local function progress(t, start, duration)
	return math.max(0, math.min(1, (t - start) / duration))
end

---Tile scale and rotation at time t; tiles ripple in from (ox, oy) and leave along the anti-diagonal.
---@param t number
---@param r integer 0-based row
---@param c integer 0-based column
---@param cols integer
---@param ox number Ripple origin in tile units
---@param oy number
---@return number scale
---@return number rotation
function WelcomeTransition.tile(t, r, c, cols, ox, oy)
	local far_x, far_y = math.max(ox, cols - 1 - ox), math.max(oy, ROWS - 1 - oy)
	local d = math.sqrt((c - ox) ^ 2 + (r - oy) ^ 2) / math.max(1, math.sqrt(far_x ^ 2 + far_y ^ 2))
	local p_in = out_quart(progress(t, d * TILE_IN_SPREAD, TILE_IN))
	local diagonal = (cols - 1 - c + ROWS - 1 - r) / (cols + ROWS - 2)
	local out_start = TILE_OUT_START + diagonal * TILE_OUT_SPREAD + (r + c) % 2 * TILE_OUT_STAGGER
	local p_out = in_quad(progress(t, out_start, TILE_OUT))
	return 1.02 * p_in * (1 - p_out), (1 - p_in) * math.pi / 2
end

---@param on_covered fun()
---@param text string Band word
---@param origin_x number Window-space point the tiles ripple from
---@param origin_y number
function WelcomeTransition:new(on_covered, text, origin_x, origin_y)
	View.new(self)
	self.time = 0
	self.on_covered = on_covered
	self.origin_x, self.origin_y = origin_x, origin_y
	-- Catches clicks so nothing under it is pressed twice mid-transition.
	self.handles_mouse_input = true

	local font = Resources.getFont("bold", 22)
	self.band_text = love.graphics.newTextBatch(font)
	local x = 0
	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		self.band_text:add(char, x, 0)
		x = x + font:getWidth(char) + BAND_TRACKING
	end
	self.band_unit = x + font:getWidth(" ") + BAND_TRACKING * 2
end

---@param dt number
function WelcomeTransition:update(dt)
	self.time = self.time + dt
	local on_covered = self.on_covered
	if on_covered and self.time >= WelcomeTransition.COVERED then
		self.on_covered = nil
		on_covered()
	end
	if self.time >= WelcomeTransition.DURATION and not self.expired then
		self:expire()
	end
end

---@return boolean handled
function WelcomeTransition:onMouseDown() return true end
---@return boolean handled
function WelcomeTransition:onMouseClick() return true end
---@return boolean handled
function WelcomeTransition:onScroll() return true end

---@param y number Top of the band at rest
---@param dir -1|1 Side it slides in from and scroll direction
function WelcomeTransition:drawBand(y, dir)
	local t = self.time
	local away = 1 - out_quart(progress(t, BAND_IN_START, BAND_IN)) + in_cubic(progress(t, BAND_OUT_START, BAND_OUT))
	y = y + dir * BAND_TRAVEL * away
	local lg = love.graphics
	Painter.setColorTable(Colors.success)
	lg.rectangle("fill", 0, y, self.width, BAND_H)
	Painter.setColorTable(Colors.background)
	local unit = self.band_unit
	local shift = (t * BAND_SPEED * dir) % unit
	local text_y = y + math.floor((BAND_H - self.band_text:getHeight()) / 2)
	for x = shift - unit, self.width, unit do
		lg.draw(self.band_text, math.floor(x), text_y)
	end
end

function WelcomeTransition:draw()
	local t = self.time
	local lg = love.graphics
	local size = self.height / ROWS
	local cols = math.ceil(self.width / size)
	local ox, oy = self.world_transform:inverseTransformPoint(self.origin_x, self.origin_y)
	ox, oy = ox / size - 0.5, oy / size - 0.5
	for r = 0, ROWS - 1 do
		for c = 0, cols - 1 do
			local scale, rotation = WelcomeTransition.tile(t, r, c, cols, ox, oy)
			if scale > 0 then
				Painter.setColorTable((r + c) % 2 == 1 and TILE_ALT or Colors.panel)
				lg.push()
				lg.translate((c + 0.5) * size, (r + 0.5) * size)
				lg.rotate(rotation)
				local half = size * scale / 2
				lg.rectangle("fill", -half, -half, half * 2, half * 2)
				lg.pop()
			end
		end
	end

	local cx, cy = self.width / 2, self.height / 2
	local logo_in = out_quart(progress(t, LOGO_IN_START, LOGO_IN))
	local logo_out = in_quad(progress(t, LOGO_OUT_START, LOGO_OUT))
	local opacity = logo_in * (1 - logo_out)
	if opacity > 0 then
		local sprite = Resources.sprites.rizu
		local w, h = sprite:getDimensions()
		local s = (0.8 + 0.2 * logo_in + 0.1 * logo_out) * math.min(LOGO_W / w, LOGO_H / h)
		Painter.setColorRgb(1, 1, 1, opacity)
		sprite:draw(cx - w * s / 2, cy - h * s / 2, 0, s, s)
	end

	self:drawBand(cy - LOGO_H / 2 - BAND_GAP - BAND_H, -1)
	self:drawBand(cy + LOGO_H / 2 + BAND_GAP, 1)
end

return WelcomeTransition
