local View = require("ui.View")
local Projector = require("yi.views.globe.Projector")

---@class yi.WireframeGlobe : ui.View
---@overload fun(opts?: table): yi.WireframeGlobe
local WireframeGlobe = View + {}

WireframeGlobe.default_latitudes = 10
WireframeGlobe.default_longitudes = 14
WireframeGlobe.default_rotation_speed_y = 0.35
WireframeGlobe.default_rotation_speed_x = 0.08
WireframeGlobe.default_tilt = -0.32
WireframeGlobe.default_alpha = 0.9
WireframeGlobe.default_back_alpha = 0.2
WireframeGlobe.default_line_width = 1.25
WireframeGlobe.default_margin = 12
WireframeGlobe.default_perspective = 2.6
WireframeGlobe.default_camera_distance = 3.2

---@param opts table?
function WireframeGlobe:new(opts)
	View.new(self)

	opts = opts or {}
	self:setSize(opts.width or 280, opts.height or 280)

	self.color = opts.color or {1, 1, 1, 1}
	self.alpha = opts.alpha or self.default_alpha
	self.back_alpha = opts.back_alpha or self.default_back_alpha
	self.line_width = opts.line_width or self.default_line_width
	self.margin = opts.margin or self.default_margin
	self.perspective_factor = opts.perspective_factor or self.default_perspective
	self.camera_distance_factor = opts.camera_distance_factor or self.default_camera_distance
	self.rotation_x = opts.rotation_x or self.default_tilt
	self.rotation_y = opts.rotation_y or 0
	self.rotation_speed_x = opts.rotation_speed_x or self.default_rotation_speed_x
	self.rotation_speed_y = opts.rotation_speed_y or self.default_rotation_speed_y
	self.latitudes = opts.latitudes or self.default_latitudes
	self.longitudes = opts.longitudes or self.default_longitudes
	self.segments = {}

	self:rebuildSegments()
end

function WireframeGlobe:onLayoutUpdate()
	self:rebuildSegments()
end

function WireframeGlobe:rebuildSegments()
	local radius = math.max(1, math.min(self.width, self.height) / 2 - self.margin)
	self.radius = radius
	self.segments = Projector.buildWireframe(radius, self.latitudes, self.longitudes)
end

---@param dt number
function WireframeGlobe:update(dt)
	self.rotation_x = self.rotation_x + self.rotation_speed_x * dt
	self.rotation_y = self.rotation_y + self.rotation_speed_y * dt
end

function WireframeGlobe:draw()
	local lg = love.graphics
	local center_x = self.width / 2
	local center_y = self.height / 2
	local perspective = self.radius * self.perspective_factor
	local camera_z = self.radius * self.camera_distance_factor
	local color = self.color

	lg.push("all")
	lg.setLineWidth(self.line_width)
	lg.setLineStyle("rough")
	lg.setColor(color[1], color[2], color[3], color[4] or 1)

	for _, segment in ipairs(self.segments) do
		local x1, y1, z1 = Projector.rotatePoint(
			segment[1], segment[2], segment[3],
			self.rotation_x, self.rotation_y
		)
		local x2, y2, z2 = Projector.rotatePoint(
			segment[4], segment[5], segment[6],
			self.rotation_x, self.rotation_y
		)

		local sx1, sy1 = Projector.projectPoint(x1, y1, z1, center_x, center_y, perspective, camera_z)
		local sx2, sy2 = Projector.projectPoint(x2, y2, z2, center_x, center_y, perspective, camera_z)

		if sx1 and sx2 then
			local normalized_depth = 1 - (((z1 + z2) * 0.5 / self.radius + 1) * 0.5)
			local alpha = self.back_alpha + (self.alpha - self.back_alpha) * normalized_depth
			lg.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
			lg.line(sx1, sy1, sx2, sy2)
		end
	end

	lg.pop()
end

return WireframeGlobe
