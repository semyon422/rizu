local Colors = require("ui.Colors")
local FormNavigation = require("ui.views.form.FormNavigation")
local Painter = require("gui.Painter")
local SpringValue = require("gui.anim.SpringValue")
local View = require("gui.View")

---@class ui.views.form.FormSelection.Config
---@field width? number
---@field gap? number

---Draws an animated selection marker for a form.
---@class ui.views.form.FormSelection : gui.View
---@operator call: ui.views.form.FormSelection
---@overload fun(form: ui.views.form.Form, config: ui.views.form.FormSelection.Config?): ui.views.form.FormSelection
---@field form ui.views.form.Form
---@field marker_width number
---@field gap number
---@field private selection_x number
---@field private selection_y gui.anim.SpringValue
---@field private selection_width number
---@field private selection_height gui.anim.SpringValue
---@field private selection_visible boolean
---@field private items_revision integer
---@field private snap_pending boolean
local FormSelection = View + {}

---@param form ui.views.form.Form
---@param config ui.views.form.FormSelection.Config?
function FormSelection:new(form, config)
	View.new(self)
	config = config or {}
	self.form = form
	self.marker_width = config.width or 4
	self.gap = config.gap or 10
	self.selection_x = 0
	self.selection_y = SpringValue({stiffness = 360, damping = 34})
	self.selection_width = 0
	self.selection_height = SpringValue()
	self.selection_visible = false
	self.items_revision = form.items_revision
	self.snap_pending = false
	self:setLayoutIgnore(true)
	self:anchorFill(0, 0, 0, 0)
end

function FormSelection:updateSelection()
	local form = self.form
	if self.items_revision ~= form.items_revision then
		self.items_revision = form.items_revision
		self.snap_pending = true
		return
	end
	if not form.selection_visible then
		self.selection_visible = false
		return
	end

	local target_x = assert(form.selection_target_x)
	local target_y = assert(form.selection_target_y)
	local target_width = assert(form.selection_target_width)
	local target_height = assert(form.selection_target_height)

	-- Animate in form-local space. A scroll offset is part of the form's world
	-- transform and is therefore applied without spring lag while drawing.
	self.selection_x = target_x
	self.selection_width = target_width
	if self.selection_visible and not self.snap_pending then
		self.selection_y:set(target_y)
		self.selection_height:set(target_height)
	else
		self.selection_y:snap(target_y)
		self.selection_height:snap(target_height)
		self.selection_visible = true
	end
	self.snap_pending = false
end

---@param dt number
function FormSelection:update(dt)
	self:updateSelection()
	self.selection_y:update(dt)
	self.selection_height:update(dt)
end

function FormSelection:draw()
	if not self.selection_visible then
		return
	end

	local selection_x = self.selection_x
	local selection_y = self.selection_y:get()
	local selection_width = self.selection_width
	local selection_height = self.selection_height:get()
	local min_x, min_y = math.huge, math.huge
	local max_y = -math.huge
	local corners = {
		{selection_x, selection_y},
		{selection_x + selection_width, selection_y},
		{selection_x, selection_y + selection_height},
		{selection_x + selection_width, selection_y + selection_height},
	}
	for _, corner in ipairs(corners) do
		local world_x, world_y = self.form.world_transform:transformPoint(corner[1], corner[2])
		local x, y = self.world_transform:inverseTransformPoint(world_x, world_y)
		min_x, min_y = math.min(min_x, x), math.min(min_y, y)
		max_y = math.max(max_y, y)
	end

	Painter.setColorTable(Colors.muted)
	Painter.setOpacity(self.form.navigation == FormNavigation.Keyboard and 1 or 0.5)
	love.graphics.rectangle(
		"fill",
		min_x - self.gap - self.marker_width,
		min_y,
		self.marker_width,
		max_y - min_y
	)
end

return FormSelection
