local View = require("ui.View")
local Colors = require("yi.Colors")

---@class yi.ConfigTitle : ui.View
---@operator call: yi.ConfigTitle
local Title = View + {}

Title.gap = 8
Title.line_height = 4
Title.title_dim_period = 5
Title.title_dim_duration = 0.18
Title.title_dim_alpha = 0.82
Title.thing_activation_span = 0.4
Title.thing_active_hold = 0.1
Title.thing_deactivation_span = 0.4
Title.thing_inactive_hold = 0.1

---@param atlas love.Image
---@param quads {[string]: love.Quad}
function Title:new(atlas, quads)
	View.new(self)

	self.atlas = atlas
	self.quads = quads
	self.title = quads.configuration_menu
	self.description = quads.configuration_description
	self.thing = quads.config_thing

	local _, _, _, title_h = self.title:getViewport()
	local total_h = title_h
	local _, _, _, desc_h = self.description:getViewport()
	total_h = total_h + self.gap + desc_h + self.gap + self.line_height
	self:setWidthPercent(1)
	self:setHeight(total_h)

	local _, _, thing_w, _ = self.thing:getViewport()
	self.thing_w = thing_w

	self.description_tf = love.math.newTransform(0, title_h + self.gap)
end

function Title:draw()
	local t = love.timer.getTime()
	local title_alpha = 1
	local dim_t = t % self.title_dim_period
	if dim_t < self.title_dim_duration then
		local phase = dim_t / self.title_dim_duration
		local pulse = math.sin(phase * math.pi)
		title_alpha = 1 - (1 - self.title_dim_alpha) * pulse
	end

	love.graphics.setColor(1, 1, 1, title_alpha)
	love.graphics.draw(self.atlas, self.title, -3)
	love.graphics.setColor(Colors.white)
	love.graphics.draw(self.atlas, self.description, self.description_tf)
	love.graphics.setColor(1, 1, 1, 0.5)
	love.graphics.setBlendMode("add")
	love.graphics.draw(self.atlas, self.quads.pixel, 0, self.height - self.line_height, 0, self.width, self.line_height)

	local count = 5
	local gap = 4
	local total_w = self.thing_w * count + gap

	love.graphics.translate(self.width - total_w - 15, 40)
	local cycle_duration = self.thing_activation_span
		+ self.thing_active_hold
		+ self.thing_deactivation_span
		+ self.thing_inactive_hold
	local cycle_t = t % cycle_duration
	local steps = math.max(1, count - 1)
	local activation_step = self.thing_activation_span / steps
	local deactivation_step = self.thing_deactivation_span / steps

	for i = 1, count do
		local is_active = false
		if cycle_t < self.thing_activation_span then
			is_active = cycle_t >= activation_step * (i - 1)
		elseif cycle_t < self.thing_activation_span + self.thing_active_hold then
			is_active = true
		elseif cycle_t < self.thing_activation_span + self.thing_active_hold + self.thing_deactivation_span then
			local off_t = cycle_t - self.thing_activation_span - self.thing_active_hold
			is_active = off_t < deactivation_step * (i - 1)
		else
			is_active = false
		end
		if is_active then
			love.graphics.setColor(1, 1, 1, 0.4)
		else
			love.graphics.setColor(1, 1, 1, 0.2)
		end
		love.graphics.draw(self.atlas, self.thing)
		love.graphics.translate(self.thing_w + gap, 0)
	end
end

return Title
