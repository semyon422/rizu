local View = require("gui.View")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local string_util = require("string_util")
local TweenValue = require("gui.anim.TweenValue")

---@class yi.ChartHeader: gui.View
---@operator call: yi.ChartHeader
local ChartHeader = View + {}

function ChartHeader:new()
	View.new(self)
	self.font_title = Resources.getFont("bold", 72)
	self.font_artist = Resources.getFont("bold", 46)
	self.font_creator = Resources.getFont("regular", 24)

	self.title_text = "Unknown Title"
	self.artist_text = "Unknown Artist"
	self.creator_text = ""

	self.alpha_title = TweenValue({value = 1, duration = 0.3, easing = "inQuad"})
	self.alpha_artist = TweenValue({value = 1, duration = 0.4, easing = "inQuad"})
	self.alpha_creator = TweenValue({value = 1, duration = 0.45, easing = "inQuad"})

	self:setHeight(self.font_title:getHeight() + self.font_artist:getHeight() + self.font_creator:getHeight() + 4)
end

---@param cv rizu.library.Chartview
function ChartHeader:bind(cv)
	if not cv.hash then
		return
	end

	self.title_text = cv.title or "Unknown Title"
	self.artist_text = cv.artist or "Unknown Artist"

	local creator = cv.creator
	if not creator or creator == "" then
		creator = nil
	end

	self.creator_text = ""
	if cv.format == "stepmania" then
		local path = cv.path or "Unknown Path"
		local spl = string_util.split(path, "/")
		local pack = spl[1] or "Unknown Path"
		if creator then
			self.creator_text = ("%s • %s"):format(creator, pack)
		else
			self.creator_text = ("%s"):format(pack)
		end
	elseif creator then
		self.creator_text = creator
	end
end

function ChartHeader:fadeIn()
	self.alpha_title:snap(0)
	self.alpha_title:set(1)
	self.alpha_artist:snap(0)
	self.alpha_artist:set(1)
	self.alpha_creator:snap(0)
	self.alpha_creator:set(1)
end

local lg = love.graphics

function ChartHeader:update(dt)
	View.update(self, dt)
	self.alpha_title:update(dt)
	self.alpha_artist:update(dt)
	self.alpha_creator:update(dt)
end

function ChartHeader:draw()
	local y = 0
	local t_c = Colors.text
	local m_c = Colors.text_muted

	lg.setFont(self.font_title)
	lg.setColor(t_c[1], t_c[2], t_c[3], (t_c[4] or 1) * self.alpha_title:get())
	lg.print(self.title_text, 0, y)
	y = y + self.font_title:getHeight()

	lg.setFont(self.font_artist)
	lg.setColor(t_c[1], t_c[2], t_c[3], (t_c[4] or 1) * self.alpha_artist:get())
	lg.print(self.artist_text, 0, y)
	y = y + self.font_artist:getHeight()

	lg.setFont(self.font_creator)
	lg.setColor(m_c[1], m_c[2], m_c[3], (m_c[4] or 1) * self.alpha_creator:get())
	y = y + 4
	lg.print(self.creator_text, 0, y)

	lg.setColor(1, 1, 1, 1)
end

return ChartHeader
