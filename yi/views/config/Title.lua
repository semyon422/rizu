local View = require("ui.View")
local Colors = require("yi.Colors")
local Painter = require("yi.Painter")

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
Title.title_offset_x = -3
Title.right_margin = 10
Title.thing_gap = 4
Title.things_bottom_margin = 20

---@param atlas love.Image
---@param quads {[string]: love.Quad}
function Title:new(atlas, quads)
	View.new(self)

	self.atlas = atlas
	self.quads = quads
	self.title = quads.configuration_menu
	self.description = quads.configuration_description
	self.thing = quads.config_thing

	self.gap = Title.gap
	self.title_offset_x = Title.title_offset_x
	self.right_margin = Title.right_margin
	self.thing_gap = Title.thing_gap
	self.things_bottom_margin = Title.things_bottom_margin

	local _, _, title_w, title_h = self.title:getViewport()
	self.title_width = title_w
	self.title_height = title_h

	local _, _, description_w, description_h = self.description:getViewport()
	self.description_width = description_w
	self.description_height = description_h

	local _, _, thing_w, thing_h = self.thing:getViewport()
	self.thing_width = thing_w
	self.thing_height = thing_h
	self.line_height = Title.line_height
end

local lg = love.graphics

function Title:draw()
	local t = love.timer.getTime()
	local title_alpha = 1
	local dim_t = t % self.title_dim_period
	if dim_t < self.title_dim_duration then
		local phase = dim_t / self.title_dim_duration
		local pulse = math.sin(phase * math.pi)
		title_alpha = 1 - (1 - self.title_dim_alpha) * pulse
	end

	lg.setColor(1, 1, 1, title_alpha)
	lg.push()
	lg.draw(self.atlas, self.title)
	lg.translate(0, Painter.getQuadHeight(self.title) + self.gap)
	lg.setColor(Colors.text)
	lg.draw(self.atlas, self.description, -self.title_offset_x)
	lg.pop()

	local count = 5
	local total_w = self.thing_width * count + self.thing_gap * (count - 1)
	local things_x = self.box.width - total_w - self.right_margin
	local things_y = self.box.height - self.thing_height - self.things_bottom_margin
	lg.push()
	lg.translate(things_x, things_y)

	local cycle_duration = self.thing_activation_span
		+ self.thing_active_hold
		+ self.thing_deactivation_span
		+ self.thing_inactive_hold
	local cycle_t = t % cycle_duration
	local steps = math.max(1, count - 1)
	local activation_step = self.thing_activation_span / steps
	local deactivation_step = self.thing_deactivation_span / steps

	lg.setBlendMode("add")

	for i = 1, count do
		local is_active = false
		if cycle_t < self.thing_activation_span then
			is_active = cycle_t >= activation_step * (i - 1)
		elseif cycle_t < self.thing_activation_span + self.thing_active_hold then
			is_active = true
		elseif cycle_t < self.thing_activation_span + self.thing_active_hold + self.thing_deactivation_span then
			local off_t = cycle_t - self.thing_activation_span - self.thing_active_hold
			is_active = off_t < deactivation_step * (i - 1)
		end
		if is_active then
			lg.setColor(1, 1, 1, 0.4)
		else
			lg.setColor(1, 1, 1, 0.2)
		end
		lg.draw(self.atlas, self.thing)
		lg.translate(self.thing_width + self.thing_gap, 0)
	end

	lg.pop()

	lg.setColor(1, 1, 1, 0.5)
	lg.draw(self.atlas, self.quads.pixel, 0, self.box.height - self.line_height, 0, self.box.width, self.line_height)
end

return Title
