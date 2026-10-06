local SdvxRenderer = require("rizu.skin.base.SdvxRenderer")
local test = {}
local lg = love.graphics

---@param run fun(renderer: rizu.skin.base.SdvxRenderer)
local function with_renderer(run)
	local was_active = lg.isActive()
	if not was_active then assert(love.window.setMode(1000, 720)) end
	local renderer = SdvxRenderer({})
	lg.push("all")
	local ok, err = xpcall(function()
		renderer:load()
		run(renderer)
	end, debug.traceback)
	lg.pop()
	renderer:unload()
	if not was_active then love.window.close() end
	assert(ok, err)
end

---@param renderer rizu.skin.base.SdvxRenderer
---@param x number
---@param y number
---@param z number
---@return number
---@return number
local function project(renderer, x, y, z)
	local m = assert(renderer.world_projection)
	local w = m[4] * x + m[8] * y + m[12] * z + m[16]
	return (1 + (m[1] * x + m[5] * y + m[9] * z + m[13]) / w) * 500,
		(1 - (m[2] * x + m[6] * y + m[10] * z + m[14]) / w) * 360
end

---@return love.Image
local function white_image()
	local data = love.image.newImageData(1, 1)
	data:setPixel(0, 0, 1, 1, 1, 1)
	local image = lg.newImage(data)
	data:release()
	return image
end

---@param t testing.T
function test.world_resources_and_track_framing(t)
	with_renderer(function(renderer)
		t:assert(renderer.world_shader, "3D shader must compile")
		t:assert(renderer.quad_mesh, "3D note mesh must be created")
		t:assert(renderer.laser_mesh, "3D laser mesh must be created")
		local left, near_y = project(renderer, -0.5, 0, 0)
		local right, same_y = project(renderer, 0.5, 0, 0)
		local far_x, far_y = project(renderer, 0, 0, 14)
		t:assert(left > 200 and left < 240, "reference camera must narrow the track")
		t:assert(right > 760 and right < 800)
		t:assert(math.abs(same_y - near_y) < 1)
		t:assert(near_y > 650 and near_y < 700, "track must meet the critical line")
		t:assert(far_x > 490 and far_x < 510)
		t:assert(far_y > 170 and far_y < 220, "track must extend toward the top")
	end)
end

---@param t testing.T
function test.world_notes_above_track_and_viewport_transform(t)
	with_renderer(function(renderer)
		local image = white_image()
		local canvas = lg.newCanvas(1000, 720, {dpiscale = 1})
		for _, transform in ipairs({love.math.newTransform(), love.math.newTransform(120, 50, 0, 0.6, 0.6)}) do
			lg.setCanvas({canvas, depth = true})
			lg.replaceTransform(transform)
			lg.setShader()
			lg.setDepthMode("always", false)
			lg.clear(0, 0, 0, 1)
			local depth_enabled = renderer:beginWorld()
			t:assert(depth_enabled, "world depth mode must be enabled")
			lg.setColor(0, 0, 1, 1)
			renderer:drawWorldRect(image, 0, 0, 7, 1, 14)
			lg.setColor(1, 0, 0, 1)
			renderer:drawHead(image, -0.25, 1, 1 / 6, 0.3)
			lg.setColor(0, 1, 0, 1)
			renderer:drawHead(image, 0.25, 7, 1 / 6, 0.3)
			-- Geometry behind the camera must be clipped, not mirrored onto the field.
			lg.setColor(1, 1, 1, 1)
			renderer:drawHead(image, 0, -10, 100, 1)
			renderer:endWorld(depth_enabled)
			lg.setCanvas()
			local pixels = lg.readbackTexture(canvas)
			local x, y = project(renderer, -0.25, 0.035, 1)
			x, y = transform:transformPoint(x, y)
			t:tdeq({pixels:getPixel(math.floor(x), math.floor(y))}, {1, 0, 0, 1})
			x, y = project(renderer, 0.25, 0.035, 7)
			x, y = transform:transformPoint(x, y)
			t:tdeq({pixels:getPixel(math.floor(x), math.floor(y))}, {0, 1, 0, 1})
			t:tdeq({pixels:getPixel(5, 5)}, {0, 0, 0, 1}, "depth clear must preserve background color")
			pixels:release()
		end
		canvas:release(); image:release()
	end)
end

---@param t testing.T
function test.gameplay_uses_world_objects_not_debug_preview(t)
	with_renderer(function(renderer)
		local rules = {button_rules = {
			first_index = 1,
			objects = {{lane = 1, time = 0.15, end_time = 0.15}},
			states = {{}},
		}, lasers = {}}
		renderer.game.rhythm_engine = {sdvx_rules = rules, visual_info = {time = 0}}
		-- Synthetic colors make the note and track unambiguous in readback.
		local images = assert(renderer.images)
		images.button:release(); images.button = white_image()
		images.track:release(); images.track = white_image()
		renderer.drawCpuObjects = function() error("2D objects must be debug-only") end
		local canvas = lg.newCanvas(1000, 720, {dpiscale = 1})
		lg.setCanvas({canvas, depth = true})
		lg.origin()
		lg.setDepthMode("always", false)
		lg.clear(0, 0, 0, 0)
		renderer:draw(1000, 720, love.math.newTransform())
		lg.setCanvas()
		local pixels = lg.readbackTexture(canvas)
		local x, y = project(renderer, -0.25, 0.035, renderer:zAt(0.15, 0, 1.5))
		t:tdeq({pixels:getPixel(math.floor(x), math.floor(y))}, {1, 1, 1, 1})
		pixels:release(); canvas:release()
	end)
end

---@param t testing.T
function test.static_preview_supports_color_only_canvas(t)
	with_renderer(function(renderer)
		local canvas = lg.newCanvas(1000, 720, {dpiscale = 1})
		lg.setCanvas(canvas)
		lg.origin()
		lg.setDepthMode("always", false)
		lg.clear(0, 0, 0, 0)
		local images = assert(renderer.images)
		images.track:release(); images.track = white_image()
		renderer:drawPreview({}, 1000, 720)
		t:eq(lg.getShader(), nil)
		t:tdeq({lg.getDepthMode()}, {"always", false})
		lg.setCanvas()
		local pixels = lg.readbackTexture(canvas)
		local x, y = project(renderer, 0, 0, 5)
		t:tdeq({pixels:getPixel(math.floor(x), math.floor(y))}, {1, 1, 1, 1})
		pixels:release(); canvas:release()
	end)
end

return test
