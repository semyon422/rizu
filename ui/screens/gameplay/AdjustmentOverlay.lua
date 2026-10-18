local View = require("gui.View")
local Label = require("ui.views.Label")

---@class ui.screens.gameplay.AdjustmentOverlay : gui.View
---@operator call: ui.screens.gameplay.AdjustmentOverlay
---@field localization ui.localization.Localization
---@field label ui.views.Label
---@field time number Seconds left before the overlay is gone
local AdjustmentOverlay = View + {}

local DURATION = 1.5
local FADE = 0.4

---@param localization ui.localization.Localization
function AdjustmentOverlay:new(localization)
	View.new(self)
	self.localization = localization
	self.time = 0
	self:setSize(320, 90)
	self:setAlignment(0.5, 0.5)
	self:setOpacity(0)
	self.label = self:add(Label({font_name = "bold", font_size = 24, text = "", align = "center"}))
	self.label:setAlignment(0.5, 0.5)
end

---@param scroll_speed string
---@param local_offset number seconds
function AdjustmentOverlay:show(scroll_speed, local_offset)
	local localization = self.localization
	self.label:setText(localization:get("gameplay.adjust.scroll_speed", {
		value = scroll_speed,
	}) .. "\n" .. localization:get("gameplay.adjust.local_offset", {
		value = ("%+d"):format(math.floor(local_offset * 1000 + 0.5)),
	}))
	self.time = DURATION
	self:setOpacity(1)
end

function AdjustmentOverlay:hide()
	self.time = 0
	self:setOpacity(0)
end

---@param dt number
function AdjustmentOverlay:update(dt)
	if self.time > 0 then
		self.time = math.max(0, self.time - dt)
		self:setOpacity(math.min(1, self.time / FADE))
	end
end

function AdjustmentOverlay:draw()
	love.graphics.setColor(0, 0, 0, 0.85)
	love.graphics.rectangle("fill", 0, 0, self.width, self.height, 8, 8)
end

return AdjustmentOverlay
