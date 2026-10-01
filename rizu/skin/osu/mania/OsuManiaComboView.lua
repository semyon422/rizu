local View = require("rizu.skin.View")
local OsuManiaBitmapFont = require("rizu.skin.osu.mania.OsuManiaBitmapFont")

local lg = love.graphics
local COMBO_SCALE = 1.28 * 0.625
local COMBO_INCREASE_DURATION = 0.3
local BREAK_DURATION = 0.2
local BREAK_SCALE = 4

---@class rizu.skin.osu.mania.OsuManiaComboView : rizu.skin.View
---@operator call: rizu.skin.osu.mania.OsuManiaComboView
---@field bitmap_font rizu.skin.osu.mania.OsuManiaBitmapFont
---@field combo integer
---@field display_combo integer
---@field target_combo integer
---@field elapsed number
---@field scale_x number
---@field scale_y number
---@field alpha number
---@field color number[]
---@field hold_color number[]
---@field break_color number[]
---@field draw_color number[]
---@field breaking boolean
---@field display_text string?
---@field display_text_combo integer?
local OsuManiaComboView = View + {}

---@param graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
function OsuManiaComboView:new(graphics)
	self.bitmap_font = OsuManiaBitmapFont(graphics)
	self.bitmap_font.prefix = "score"
	self.combo = 0
	self.display_combo = 0
	self.target_combo = 0
	self.elapsed = 0
	self.scale_x = 1
	self.scale_y = 1
	self.alpha = 0
	self.color = {1, 1, 1, 1}
	self.hold_color = {1, 1, 1, 1}
	self.break_color = {1, 0.035, 0.035, 1}
	self.draw_color = {1, 1, 1, 1}
	self.breaking = false
	View.new(self, {anchor = "top", origin = "center", x = 0, y = 125, width = 0, height = 0})
	self:setSkin(nil)
end

---@param skin rizu.skin.OsuSkinDiscovery?
---@param section rizu.skin.OsuSkinIni.ManiaSection?
function OsuManiaComboView:setSkin(skin, section)
	self.bitmap_font:setSkin(skin, "Combo")
	section = section or (skin and skin.skin_ini.Mania and skin.skin_ini.Mania[1]) or {}
	local position = tonumber(section.ComboPosition)
	if position == nil or position ~= position or position == math.huge or position == -math.huge then position = 111 end
	if section.UpsideDown == "1" or section.UpsideDown == "true" then position = 480 - position end
	self.y = math.max(0, math.min(480, position))
	local break_color = self.break_color
	break_color[1], break_color[2], break_color[3], break_color[4] = 1, 0.035, 0.035, 1
	local value = section.ColourBreak
	if value then
		local channels = {}
		for component in (value .. ","):gmatch("(.-),") do channels[#channels + 1] = tonumber(component:match("^%s*(.-)%s*$")) end
		if #channels >= 3 and channels[1] and channels[2] and channels[3] then
			break_color[1] = math.max(0, math.min(255, channels[1])) / 255
			break_color[2] = math.max(0, math.min(255, channels[2])) / 255
			break_color[3] = math.max(0, math.min(255, channels[3])) / 255
			break_color[4] = 1
		end
	end
	self.break_color = break_color
	self:refreshSize()
end

function OsuManiaComboView:refreshSize()
	local font_width, font_height = self.bitmap_font:measure("000000")
	self.width = font_width * COMBO_SCALE
	self.height = font_height * COMBO_SCALE
end

---@return string[]
function OsuManiaComboView:getImageAssets()
	return self.bitmap_font:getImageAssets(true)
end

---@param dt number
function OsuManiaComboView:update(dt)
	local engine = self.game and self.game.rhythm_engine
	local score_engine = engine and engine.score_engine
	local source = score_engine and score_engine.comboSource
	local combo = source and source.getCombo and source:getCombo() or 0
	combo = math.max(0, math.floor(tonumber(combo) or 0))
	local previous = self.target_combo
	self.target_combo = combo
	if combo ~= previous then
		if combo > previous then
			self.breaking = false
			self.display_combo = combo > previous + 10 and combo or math.max(self.display_combo, previous)
			self.elapsed = 0
			self.alpha = 1
			self.scale_x, self.scale_y = 1, 1.4
		elseif combo == 0 and self.display_combo > 0 then
			self.breaking = true
			self.elapsed = 0
			self.alpha = 0.8
			self.break_combo = self.display_combo
			self.display_combo = 0
		end
	end
	self.combo = combo
	if not self.breaking and self.display_combo < self.target_combo then
		self.display_combo = self.display_combo + 1
	end

	self.elapsed = self.elapsed + math.max(0, dt)
	if self.breaking then
		local progress = math.min(1, self.elapsed / BREAK_DURATION)
		self.alpha = 0.8 * (1 - progress)
		self.scale_x = 1 + (BREAK_SCALE - 1) * progress
		self.scale_y = self.scale_x
		if progress >= 1 then
			self.display_combo = 0
			self.breaking = false
		end
	elseif self.elapsed < COMBO_INCREASE_DURATION then
		local progress = self.elapsed / COMBO_INCREASE_DURATION
		self.scale_y = 1.4 + (1 - 1.4) * progress
	else
		self.scale_x, self.scale_y = 1, 1
	end
	if self.combo == 0 and not self.breaking then self.alpha = math.max(0, self.alpha - dt * 2) end
end

function OsuManiaComboView:draw()
	local combo = self.breaking and (self.break_combo or self.display_combo) or self.display_combo
	if combo <= 0 or self.alpha <= 0 then return end
	local color = self.breaking and self.break_color or self.color
	local text = self.display_text
	if not text or self.display_text_combo ~= combo then
		text = tostring(combo)
		self.display_text, self.display_text_combo = text, combo
	end
	local text_width, text_height = self.bitmap_font:measure(text)
	local draw_scale_x = self.scale_x
	local draw_scale_y = self.scale_y
	lg.push()
	lg.translate(self.width / 2, self.height / 2)
	lg.scale(draw_scale_x, draw_scale_y)
	lg.translate(-self.width / 2, -self.height / 2)
	local draw_color = self.draw_color
	draw_color[1], draw_color[2], draw_color[3] = color[1], color[2], color[3]
	draw_color[4] = (color[4] or 1) * self.alpha
	self.bitmap_font:draw(text, COMBO_SCALE, (self.height - text_height * COMBO_SCALE) / 2,
		(self.width + text_width * COMBO_SCALE) / 2, draw_color)
	lg.pop()
end

return OsuManiaComboView
