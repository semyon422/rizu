local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")

local lg = love.graphics

local FIELD_WIDTH = 1000
local FIELD_HEIGHT = 720
local TRACK_WIDTH = 1
local TRACK_LENGTH = 14
local PREEMPT = 1.5

local assets = {
	background = "resources/sdvx/bg.png",
	track = "resources/sdvx/track.png",
	button = "resources/sdvx/button.png",
	button_hold = "resources/sdvx/buttonhold.png",
	fx_button = "resources/sdvx/fxbutton.png",
	fx_button_hold = "resources/sdvx/fxbuttonhold.png",
	laser_left = "resources/sdvx/laser_l.png",
	laser_right = "resources/sdvx/laser_r.png",
	laser_entry_left = "resources/sdvx/laser_entry_l.png",
	laser_entry_right = "resources/sdvx/laser_entry_r.png",
	laser_exit_left = "resources/sdvx/laser_exit_l.png",
	laser_exit_right = "resources/sdvx/laser_exit_r.png",
}

local laser_colors = {
	{0.12, 0.72, 1.00},
	{1.00, 0.25, 0.70},
}

local lane_centers = {
	[1] = -0.25,
	[2] = -1 / 12,
	[3] = 1 / 12,
	[4] = 0.25,
	[5] = -1 / 6,
	[6] = 1 / 6,
}

-- The shader turns real 3D positions into pixels in the renderer's 1000x720
-- field. The normal LÖVE transform_projection then applies the UI viewport
-- transform. This keeps the renderer compatible with transformed UI views.
local world_vertex_shader_code = [[
extern mat4 world_projection;
extern vec2 viewport_size;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
	vec4 clip = world_projection * vertex_position;
	// Keep homogeneous coordinates: the GPU must perform the perspective
	// divide for texture interpolation and clipping at the camera plane.
	vec2 pixel = vec2(
		(clip.x + clip.w) * 0.5 * viewport_size.x,
		(clip.w - clip.y) * 0.5 * viewport_size.y
	);
	vec4 position = transform_projection * vec4(pixel, 0.0, clip.w);
	// Do not feed world depth through the UI's orthographic projection,
	// which negates z and makes the track occlude notes above its surface.
	position.z = clip.z;
	return position;
}
]]

local world_fragment_shader_code = [[
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	vec4 result = Texel(texture, texture_coords) * color;
	if (result.a < 0.005) discard;
	return result;
}
]]

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function lerp(a, b, amount)
	return a + (b - a) * amount
end

---@param value number
---@return number
local function finite(value)
	if value ~= value or value == math.huge or value == -math.huge then return 0 end
	return value
end

---@param a number[]
---@param b number[]
---@return number[]
local function multiply_matrix(a, b)
	local result = {}
	for column = 0, 3 do
		for row = 0, 3 do
			local value = 0
			for k = 0, 3 do
				value = value + a[k * 4 + row + 1] * b[column * 4 + k + 1]
			end
			result[column * 4 + row + 1] = value
		end
	end
	return result
end

---@param fov number
---@param aspect number
---@param near number
---@param far number
---@return number[]
local function perspective(fov, aspect, near, far)
	local scale = 1 / math.tan(fov / 2)
	return {
		scale / aspect, 0, 0, 0,
		0, scale, 0, 0,
		0, 0, (far + near) / (near - far), -1,
		0, 0, 2 * far * near / (near - far), 0,
	}
end

---@param pitch number
---@param yaw number
---@param roll number
---@return number[]
local function rotation_matrix(pitch, yaw, roll)
	pitch = -math.rad(pitch)
	yaw = -math.rad(yaw)
	roll = -math.rad(roll)
	local a, b = math.cos(pitch), math.sin(pitch)
	local c, d = math.cos(yaw), math.sin(yaw)
	local e, f = math.cos(roll), math.sin(roll)
	local ad, bd = a * d, b * d
	return {
		c * e, -c * f, d, 0,
		bd * e + a * f, -bd * f + a * e, -b * c, 0,
		-ad * e + b * f, ad * f + b * e, a * c, 0,
		0, 0, 0, 1,
	}
end

---@param x number
---@param y number
---@param z number
---@return number[]
local function translation_matrix(x, y, z)
	return {
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		x, y, z, 1,
	}
end

---@return number[]
local function camera_matrix()
	-- Match unnamed-sdvx-clone's landscape camera: a 60 degree FOV with the
	-- critical line at 95% of the screen height. Its track is built in an XY
	-- plane, rotated upright, while this renderer uses Z for track distance.
	local track_origin = multiply_matrix(
		multiply_matrix(translation_matrix(0, -0.9, 0), rotation_matrix(1.5, 0, 0)),
		multiply_matrix(translation_matrix(0, 0, -0.9), rotation_matrix(-90, 0, 0))
	)
	local axis_swap = {
		1, 0, 0, 0,
		0, 0, 1, 0,
		0, 1, 0, 0,
		0, 0, 0, 1,
	}

	local crit_x = track_origin[13]
	local crit_y = track_origin[14]
	local crit_z = track_origin[15]
	local crit_length = math.sqrt(crit_x * crit_x + crit_y * crit_y + crit_z * crit_z)
	crit_y, crit_z = crit_y / crit_length, crit_z / crit_length
	local rot_to_crit = -math.deg(math.atan(crit_y, -crit_z))
	local camera_pitch = rot_to_crit - (60 / 2 - 60 * 0.05)
	return multiply_matrix(rotation_matrix(camera_pitch, 0, 0),
		multiply_matrix(track_origin, axis_swap))
end

---@class rizu.skin.base.SdvxRenderer : rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.skin.base.SdvxRenderer
---@field images {[string]: love.Image}?
---@field world_shader love.Shader?
---@field quad_mesh love.Mesh?
---@field laser_mesh love.Mesh?
---@field world_projection number[]?
local SdvxRenderer = PlayfieldRenderer + {}

---@param game sphere.GameController
function SdvxRenderer:new(game)
	PlayfieldRenderer.new(self, game)
	self.images = nil
	self.world_shader = nil
	self.quad_mesh = nil
	self.laser_mesh = nil
	self.world_projection = nil
end

---@param image love.Image
---@param x number
---@param y number
---@param width number
---@param height number
function SdvxRenderer:drawImage(image, x, y, width, height)
	lg.draw(image, x, y, 0, width / image:getWidth(), height / image:getHeight())
end

function SdvxRenderer:load()
	if self.images then return end
	self.images = {}
	for name, path in pairs(assets) do
		local ok, image = pcall(lg.newImage, path)
		if ok and image then
			self.images[name] = image
			pcall(image.setFilter, image, "linear", "linear", 16)
		end
	end

	self.world_shader = lg.newShader(world_vertex_shader_code, world_fragment_shader_code)
	local view = camera_matrix()
	local projection = perspective(math.rad(60), FIELD_WIDTH / FIELD_HEIGHT, 0.1, 30)
	self.world_projection = multiply_matrix(projection, view)
	self.world_shader:send("world_projection", "column", self.world_projection)
	self.world_shader:send("viewport_size", {FIELD_WIDTH, FIELD_HEIGHT})
	self:ensureMeshes()
end

function SdvxRenderer:ensureMeshes()
	local vertex_format = {
		{format = "floatvec3", location = 0},
		{format = "floatvec2", location = 1},
	}
	if not self.quad_mesh then
		self.quad_mesh = lg.newMesh(vertex_format, 6, "triangles", "dynamic")
	end
	if not self.laser_mesh then
		self.laser_mesh = lg.newMesh(vertex_format, 6, "triangles", "dynamic")
	end
end

function SdvxRenderer:unload()
	if self.images then
		for _, image in pairs(self.images) do pcall(image.release, image) end
	end
	self.images = nil
	if self.world_shader then pcall(self.world_shader.release, self.world_shader) end
	self.world_shader = nil
	if self.quad_mesh then pcall(self.quad_mesh.release, self.quad_mesh) end
	if self.laser_mesh then pcall(self.laser_mesh.release, self.laser_mesh) end
	self.quad_mesh = nil
	self.laser_mesh = nil
	self.world_projection = nil
end

---@param width number
---@param height number
---@return number scale
---@return number x
---@return number y
function SdvxRenderer:getField(width, height)
	local scale = math.min(width / FIELD_WIDTH, height / FIELD_HEIGHT)
	return math.max(scale, 0.001), (width - FIELD_WIDTH * scale) / 2, (height - FIELD_HEIGHT * scale) / 2
end

---@param image love.Image?
---@param vertices number[][] Four vertices containing x, y, z, u, v.
function SdvxRenderer:drawWorldQuad(image, vertices)
	if not image or not self.quad_mesh or not self.world_shader then return end
	self.quad_mesh:setVertices({
		vertices[1], vertices[2], vertices[3],
		vertices[1], vertices[3], vertices[4],
	})
	self.quad_mesh:setTexture(image)
	lg.draw(self.quad_mesh)
end

---@param image love.Image?
---@param x number
---@param y number
---@param z number
---@param width number
---@param length number
function SdvxRenderer:drawWorldRect(image, x, y, z, width, length)
	local half_width = width / 2
	local half_length = length / 2
	self:drawWorldQuad(image, {
		{x - half_width, y, z - half_length, 0, 0},
		{x + half_width, y, z - half_length, 1, 0},
		{x + half_width, y, z + half_length, 1, 1},
		{x - half_width, y, z + half_length, 0, 1},
	})
end

function SdvxRenderer:drawBackground(width, height)
	lg.setShader()
	local image = self.images and self.images.background
	lg.setColor(1, 1, 1, 0.32)
	if image then
		self:drawImage(image, 0, 0, width, height)
	else
		lg.setColor(0.015, 0.025, 0.06, 1)
		lg.rectangle("fill", 0, 0, width, height)
	end
	lg.setColor(0.01, 0.015, 0.03, 0.46)
	lg.rectangle("fill", 0, 0, width, height)
end

---@param use_depth boolean? Disabled for the static preview's color-only canvas.
---@return boolean depth_enabled
function SdvxRenderer:beginWorld(use_depth)
	if not self.world_shader then return false end
	self.world_shader:send("world_projection", "column", self.world_projection)
	lg.setShader(self.world_shader)
	lg.setMeshCullMode("none")
	local depth_enabled = use_depth ~= false
	lg.setDepthMode(depth_enabled and "lequal" or "always", depth_enabled)
	if depth_enabled then
		-- Clear only depth; a color table here clears the field's background.
		lg.clear(false, false, 1)
	end
	return depth_enabled
end

---@param depth_enabled boolean
function SdvxRenderer:endWorld(depth_enabled)
	lg.setShader()
	if depth_enabled then lg.setDepthMode("always", false) end
end

function SdvxRenderer:project(z, x)
	local m = assert(self.world_projection)
	local clip_x = m[1] * x + m[9] * z + m[13]
	local clip_y = m[2] * x + m[10] * z + m[14]
	local clip_w = m[4] * x + m[12] * z + m[16]
	local screen_x = (clip_x / clip_w + 1) * FIELD_WIDTH * 0.5
	local screen_y = (1 - clip_y / clip_w) * FIELD_HEIGHT * 0.5
	local left = (m[1] * (x - 0.5) + m[9] * z + m[13]) /
		(m[4] * (x - 0.5) + m[12] * z + m[16])
	local right = (m[1] * (x + 0.5) + m[9] * z + m[13]) /
		(m[4] * (x + 0.5) + m[12] * z + m[16])
	return screen_x, screen_y, math.abs(right - left) * FIELD_WIDTH * 0.5
end

---@param rules rizu.sdvx.Rules
---@param now number
function SdvxRenderer:drawCriticalLine()
	local left_x, y = self:project(0, -0.5)
	local right_x = self:project(0, 0.5)
	lg.setColor(1, 0.22, 0.28, 0.95)
	lg.setLineWidth(4)
	lg.line(left_x, y, right_x, y)
end

function SdvxRenderer:drawTrack()
	local image = self.images and self.images.track
	self:drawWorldQuad(image, {
		{-TRACK_WIDTH / 2, 0, TRACK_LENGTH, 0, 0},
		{TRACK_WIDTH / 2, 0, TRACK_LENGTH, 1, 0},
		{TRACK_WIDTH / 2, 0, 0, 1, 1},
		{-TRACK_WIDTH / 2, 0, 0, 0, 1},
	})
end

---@param time number
---@param now number
---@param preempt number
---@return number
function SdvxRenderer:zAt(time, now, preempt)
	return (time - now) / preempt * TRACK_LENGTH
end

---@param position number
---@param extended boolean
---@return number
function SdvxRenderer:laserX(position, extended)
	return (extended and position * 2 or position) * (5 / 6) - (5 / 12)
end

---@param image love.Image?
---@param x number
---@param z number
---@param width number
---@param length number
function SdvxRenderer:drawHead(image, x, z, width, length)
	self:drawWorldRect(image, x, 0.035, z, width, length)
end

---@param image love.Image?
---@param x number
---@param head_time number
---@param tail_time number
---@param now number
---@param preempt number
---@param width number
function SdvxRenderer:drawHold(image, x, head_time, tail_time, now, preempt, width)
	if tail_time < now - preempt then return end
	head_time = math.max(head_time, now)
	local head_z = math.max(self:zAt(head_time, now, preempt), 0)
	local tail_z = math.max(self:zAt(tail_time, now, preempt), 0)
	local image_ratio = image and image:getHeight() / image:getWidth() or 0.35
	local half_width = width / 2
	self:drawWorldQuad(image, {
		{x - half_width, 0.018, head_z, 0, 0},
		{x + half_width, 0.018, head_z, 1, 0},
		{x + half_width, 0.018, tail_z, 1, math.max(1, (tail_z - head_z) / width / image_ratio)},
		{x - half_width, 0.018, tail_z, 0, math.max(1, (tail_z - head_z) / width / image_ratio)},
	})
end

---@param chain chart.ksm.SdvxLaser
---@param segment chart.ksm.SdvxLaserSegment
---@param now number
---@param preempt number
---@return number[]
function SdvxRenderer:laserPoints(chain, segment, now, preempt)
	if segment.end_time < now - preempt or segment.time > now + preempt then return {} end
	local start_time = math.max(segment.time, now - preempt)
	local end_time = math.min(segment.end_time, now + preempt)
	if segment.slam or segment.end_time <= segment.time then start_time, end_time = segment.time, segment.time end
	local duration = segment.end_time - segment.time
	local count = segment.slam and 1 or 6
	local points = {}
	for i = 0, count do
		local t = lerp(start_time, end_time, i / count)
		local progress = segment.slam and (i == 0 and 0 or 1)
			or (duration > 0 and clamp((t - segment.time) / duration, 0, 1) or 1)
		local x = self:laserX(lerp(segment.from, segment.to, progress), chain.extended)
		points[#points + 1] = x
		points[#points + 1] = self:zAt(t, now, preempt)
	end
	return points
end

---@param chain chart.ksm.SdvxLaser
---@param laser rizu.sdvx.Laser
---@param now number
---@param preempt number
function SdvxRenderer:drawLaser(chain, laser, now, preempt)
	local color = laser_colors[chain.lane]
	local image = self.images[chain.lane == 1 and "laser_left" or "laser_right"]
	for _, segment in ipairs(chain.segments) do
		local points = self:laserPoints(chain, segment, now, preempt)
		for i = 1, #points - 2, 2 do
			local x1, z1 = points[i], points[i + 1]
			local x2, z2 = points[i + 2], points[i + 3]
			local dx, dz = x2 - x1, z2 - z1
			local length = math.sqrt(dx * dx + dz * dz)
			if length > 0 and self.laser_mesh and self.world_shader then
				local width = 0.045
				local nx, nz = -dz / length * width, dx / length * width
				self.laser_mesh:setVertices({
					{x1 - nx, 0.06, z1 - nz, 0, 0}, {x1 + nx, 0.06, z1 + nz, 1, 0},
					{x2 + nx, 0.06, z2 + nz, 1, 1}, {x1 - nx, 0.06, z1 - nz, 0, 0},
					{x2 + nx, 0.06, z2 + nz, 1, 1}, {x2 - nx, 0.06, z2 - nz, 0, 1},
				})
				self.laser_mesh:setTexture(image)
				lg.setColor(color[1], color[2], color[3], 0.95)
				lg.draw(self.laser_mesh)
			end
		end
	end

	local first, last = chain.segments[1], chain.segments[#chain.segments]
	local entry_image = self.images[chain.lane == 1 and "laser_entry_left" or "laser_entry_right"]
	local exit_image = self.images[chain.lane == 1 and "laser_exit_left" or "laser_exit_right"]
	local entry_z = self:zAt(first.time, now, preempt)
	local exit_z = self:zAt(last.end_time, now, preempt)
	local entry_width = 0.11
	local exit_width = 0.11
	lg.setColor(color[1], color[2], color[3], 0.9)
	if first.time >= now - preempt and first.time <= now + preempt then
		self:drawWorldRect(entry_image, self:laserX(first.from, chain.extended), 0.065,
			entry_z - 0.2, entry_width, 0.4)
	end
	if last.end_time >= now - preempt and last.end_time <= now + preempt then
		self:drawWorldRect(exit_image, self:laserX(last.to, chain.extended), 0.065,
			exit_z + 0.2, exit_width, 0.4)
	end

	if now >= first.time and now <= last.end_time + 0.1 then
		local x = self:laserX(laser.position, chain.extended)
		lg.setColor(1, 1, 1, laser.captured and 1 or 0.65)
		self:drawWorldRect(image, x, 0.08, 0, 0.12, 0.12)
	end
end

---@param rules rizu.sdvx.Rules
---@param now number
function SdvxRenderer:drawObjects(rules, now)
	local preempt = rules.preempt or PREEMPT
	local objects = rules.button_rules.objects
	local states = rules.button_rules.states

	for i = rules.button_rules.first_index, #objects do
		local object, state = objects[i], states[i]
		if object.time > now + preempt then break end
		if object.end_time >= now - preempt and not state.result then
			local x = lane_centers[object.lane] or 0
			local image = object.lane <= 4 and self.images.button_hold or self.images.fx_button_hold
			local width = object.lane <= 4 and 1 / 6 or 1 / 3
			if object.end_time > object.time then
				local head_time = state.head and not state.failed and math.max(object.time, now) or object.time
				self:drawHold(image, x, head_time, object.end_time, now, preempt, width)
			end
		end
	end

	for _, laser in ipairs(rules.lasers) do
		self:drawLaser(laser.chain, laser, now, preempt)
	end

	for i = rules.button_rules.first_index, #objects do
		local object, state = objects[i], states[i]
		if object.time > now + preempt then break end
		if (object.time >= now - preempt or state.head) and not state.result then
			local x = lane_centers[object.lane] or 0
			local image = object.lane <= 4 and self.images.button or self.images.fx_button
			local width = object.lane <= 4 and 1 / 6 or 1 / 3
			local head_time = state.head and not state.failed and math.max(object.time, now) or object.time
			local length = width * (image:getHeight() / image:getWidth())
			lg.setColor(1, 1, 1, state.failed and 0.3 or 1)
			self:drawHead(image, x, self:zAt(head_time, now, preempt), width, length)
		end
	end
end

---@param width number
---@param height number
---@param transform love.Transform
function SdvxRenderer:draw(width, height, transform)
	local re = self.game.rhythm_engine
	local rules = re and re.sdvx_rules
	if not rules then return end
	self:load()
	local scale, offset_x, offset_y = self:getField(width, height)
	local now = finite(re.visual_info.time)
	lg.push("all")
	lg.applyTransform(transform)
	lg.translate(offset_x, offset_y)
	lg.scale(scale)
	self:drawBackground(FIELD_WIDTH, FIELD_HEIGHT)
	local depth_ok = self:beginWorld()
	lg.setColor(1, 1, 1, 1)
	self:drawTrack()
	self:drawObjects(rules, now)
	self:endWorld(depth_ok)
	self:drawCriticalLine()
	lg.pop()
end

---@param player rizu.preview.NotesPreviewPlayer
---@param width number
---@param height number
function SdvxRenderer:drawPreview(player, width, height)
	self:load()
	local scale, offset_x, offset_y = self:getField(width, height)
	lg.push("all")
	lg.applyTransform(love.math.newTransform())
	lg.translate(offset_x, offset_y)
	lg.scale(scale)
	self:drawBackground(FIELD_WIDTH, FIELD_HEIGHT)
	local depth_ok = self:beginWorld(false)
	lg.setColor(1, 1, 1, 1)
	self:drawTrack()
	self:endWorld(depth_ok)
	lg.pop()
end

return SdvxRenderer
