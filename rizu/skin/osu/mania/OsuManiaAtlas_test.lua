local FakeFilesystem = require("fs.FakeFilesystem")
local Graphics = require("rizu.skin.SkinTextures")
local Renderer = require("rizu.skin.osu.OsuManiaRenderer")
local Image = require("rizu.skin.TextureImage")
local BitmapFont = require("rizu.skin.BitmapFont")
local Lighting = require("rizu.skin.osu.mania.OsuManiaLighting")
local LoveFilesystem = require("fs.LoveFilesystem")
local Atlas = require("rizu.skin.SkinAtlas")
local FakeGameplay = require("rizu.api.fake.FakeGameplay")

---HUD elements read the play through the game api.
---@param fs fs.IFilesystem
local function fake_game(fs)
	return {fs = fs, api = {gameplay = FakeGameplay()}}
end

local test = {}

---@param width integer
---@param height integer
---@param color number[]?
---@return string
local function png(width, height, color)
	local data = love.image.newImageData(width, height)
	data:mapPixel(function() return unpack(color or {1, 0, 0, 1}) end)
	local encoded = data:encode("png")
	local content = encoded:getString()
	encoded:release()
	data:release()
	return content
end

---@param files {[string]: string}
---@return rizu.skin.SkinTextures
local function fixture(files)
	local fs = FakeFilesystem()
	fs:createDirectory("skin")
	local names = {}
	for name, content in pairs(files) do
		fs:write("skin/" .. name, content)
		names[#names + 1] = name
	end
	return Graphics(fs, {path = "skin", files = names})
end

-- The normal test harness has no graphics context. Model GPU resources explicitly.
local function with_gpu(callback)
	local lg = love.graphics
	local saved, resources, draws = {}, {}, {}
	local function replace(name, fn) saved[name] = lg[name]; lg[name] = fn end
	local function resource(fields)
		fields.releases = 0
		fields.release = function(self) self.releases = self.releases + 1 end
		resources[#resources + 1] = fields
		return fields
	end
	replace("newImage", function(data, settings)
		local w, h = data:getDimensions()
		local d = settings and settings.dpiscale or 1
		return resource({getDimensions = function() return w / d, h / d end,
			getWidth = function() return w / d end, getHeight = function() return h / d end,
			setWrap = function() end})
	end)
	replace("newQuad", function(x, y, w, h, tw, th)
		local q = resource({})
		q.setViewport = function(self, a, b, c, d, e, f) self.viewport = {a, b, c, d, e, f} end
		q.getViewport = function(self) return unpack(self.viewport, 1, 4) end
		q:setViewport(x, y, w, h, tw, th)
		return q
	end)
	replace("draw", function(...)
		local args = {...} ---@type table
		if type(args[2]) == "table" then args.viewport = {args[2]:getViewport()} end
		draws[#draws + 1] = args
	end)
	replace("getSystemLimits", function() return {texturesize = 4096} end)
	local ok, err = xpcall(function() callback(resources, draws) end, debug.traceback)
	for name, fn in pairs(saved) do lg[name] = fn end
	if not ok then error(err) end
end

function test.cpu_pack_gpu_upload_and_shared_font_groups(t)
	local graphics = fixture({["score-0@2x.png"] = png(4, 6)})
	local count, decode = 0, graphics.loadImageData
	graphics.loadImageData = function(self, path) count = count + 1; return decode(self, path) end
	local lg = love.graphics
	love.graphics = nil
	local ok, prepared = pcall(graphics.prepare, graphics, {
		{name = "score-0", group = "font"}, {name = "score-0", group = "playfield"},
		{name = "score-0", group = "playfield"},
	})
	love.graphics = lg
	if not ok then error(prepared) end
	t:eq(count, 1)
	t:eq(prepared.groups.pixel, nil)
	local group = prepared.groups.playfield
	local pixel = group.locations["\0white"]
	t:tdeq({group.atlases[pixel.layer]:getPixel(pixel.x, pixel.y)}, {1, 1, 1, 1})
	local loc = group.locations["skin/score-0@2x.png"]
	t:tdeq({group.atlases[loc.layer]:getPixel(loc.x, loc.y)}, {1, 0, 0, 1})
	with_gpu(function(resources, draws)
		local image, filesystem = love.image, love.filesystem
		love.image, love.filesystem = nil, nil
		local uploaded, err = pcall(graphics.upload, graphics)
		love.image, love.filesystem = image, filesystem
		if not uploaded then error(err) end
		local frame = graphics:getFrames("score-0", nil, "playfield")[1]
		local font = graphics:getFrames("score-0", nil, "font")[1]
		t:ne(frame.texture, font.texture)
		t:tdeq({Image.dimensions(frame)}, {2, 3})
		Image.draw(frame, 10, 20, 0, 2, -2, 1, 3)
		t:tdeq({unpack(draws[1], 3)}, {10, 20, 0, 1, -1, 2, 6})
		t:eq(next(graphics.images), nil)
		graphics:unload()
		graphics:unload()
		for _, resource in ipairs(resources) do t:eq(resource.releases, 1) end
	end)
end

function test.fallback_animation_corruption_and_selected_static_precedence(t)
	local graphics = fixture({["judge.png"] = "corrupt", ["key.png"] = png(2, 2)})
	graphics.fs:createDirectory("fallback")
	graphics.fallback_file_map = {}
	for _, name in ipairs({"judge-0.png", "judge-1.png", "judge-3.png", "key-0.png"}) do
		graphics.fs:write("fallback/" .. name, png(2, 2))
		graphics.fallback_file_map[name] = "fallback/" .. name
	end
	graphics:prepare({{name = "judge", animation = true, group = "playfield"},
		{fallback = "judge", animation = true, group = "font"},
		{name = "missing-custom", fallback = "judge", animation = true, group = "playfield"},
		{name = "key", animation = true, group = "playfield"}})
	with_gpu(function()
		graphics:upload()
		t:eq(#graphics:getAnimationFrames("judge", nil, "playfield"), 2)
		t:eq(#graphics:getAnimationFrames(nil, "judge", "font"), 2)
		t:eq(#graphics:getAnimationFrames("missing-custom", "judge", "playfield"), 2)
		t:eq(#graphics:getAnimationFrames("key", nil, "playfield"), 1)
		t:eq(graphics:getAnimationFrames("key", nil, "playfield")[1], graphics:getAtlasFrame("playfield", "skin/key.png"))
		graphics:unload()
	end)
end

function test.multiple_pages_oversized_crop_and_upload_failure(t)
	local graphics = fixture({["a.png"] = png(6, 6), ["b.png"] = png(6, 6), ["huge@2x.png"] = png(2, 40)})
	graphics:setAtlasLimit(8)
	graphics:setTextureLimit(16)
	local assets = {{name = "a", group = "playfield"}, {name = "b", group = "playfield"},
		{name = "huge", group = "playfield"}, {name = "huge", group = "font"}}
	local prepared = graphics:prepare(assets)
	t:assert(#prepared.groups.playfield.atlases >= 2)
	local group = prepared.groups.playfield
	local location = group.locations["skin/huge@2x.png"]
	t:tdeq({location.width, location.height}, {2, 16})
	t:assert(select(2, group.atlases[location.layer]:getDimensions()) <= 16)
	t:eq(location.x, 0)
	t:eq(location.y, 0)
	t:eq(next(prepared.standalone), nil)
	with_gpu(function(resources)
		graphics:upload()
		t:assert(#graphics.atlas_images.playfield >= 2)
		t:tdeq({Image.dimensions(graphics:getFrames("huge", nil, "playfield")[1])}, {1, 8})
		t:ne(graphics:getFrames("huge", nil, "playfield")[1].texture,
			graphics:getFrames("huge", nil, "font")[1].texture)
		graphics:unload()
		for _, r in ipairs(resources) do t:eq(r.releases, 1) end
	end)
	graphics:prepare(assets)
	local abandoned = graphics.prepared.groups.playfield.atlases[1]
	graphics:prepare(assets)
	t:eq(pcall(abandoned.getDimensions, abandoned), false)
	with_gpu(function(resources)
		local new_quad = love.graphics.newQuad
		love.graphics.newQuad = function() error("quad failure") end
		local ok = pcall(graphics.upload, graphics)
		love.graphics.newQuad = new_quad
		t:eq(ok, false)
		t:eq(graphics.prepared, nil)
		t:eq(graphics.loaded, false)
		t:eq(next(graphics.atlas_images), nil)
		for _, r in ipairs(resources) do t:eq(r.releases, 1) end
		graphics:load(assets)
		t:assert(graphics:getFrames("a", nil, "playfield")[1])
		graphics:unload()
	end)
end

function test.renderer_membership_and_all_draw_paths(t)
	with_gpu(function(resources, draws)
		local fs = FakeFilesystem()
		fs:createDirectory("atlas-skin")
		local files = {"lightingN-0.png", "lightingL-0.png", "mania-stage-bottom.png"}
		for _, name in ipairs(files) do fs:write("atlas-skin/" .. name, png(4, 4)) end
		local skin = {path = "atlas-skin", files = files, skin_ini = {Mania = {}, Fonts = {}}}
		local renderer = Renderer(fake_game(fs), skin, "4key")
		renderer:load()
		local graphics = renderer.skin_graphics
		for _, name in ipairs({"mania-note1", "mania-note1L", "mania-key1", "mania-stage-hint"}) do
			local frame = graphics:getAnimationFrames(name, nil, "playfield")[1]
			t:assert(frame and frame.texture, name)
		end
		for _, name in ipairs({"mania-hit300g", "score-0", "circularmetre", "editor-rate-arrow"}) do
			local frame = graphics:getAnimationFrames(name, nil, "hud")[1]
			t:assert(frame and frame.texture, name)
		end
		t:assert(graphics:getAtlasFrame("hud", "\0white"))
		for _, name in ipairs({"mania-stage-left", "mania-stage-right", "mania-stage-bottom",
			"mania-stage-light", "lightingN", "lightingL"}) do
			local frame = graphics:getAnimationFrames(name, nil, "standalone")[1]
			t:assert(frame, name)
			t:eq(frame.texture, nil, name)
		end
		local old_quad = love.graphics.newQuad
		love.graphics.newQuad = function() error("Quad allocation during draw") end
		local widths, xs = {30, 30, 30, 30}, {15, 45, 75, 105}
		renderer.field_renderer:draw(renderer, 0, 120, widths, xs, 402, 1)
		renderer.key_renderer:draw(renderer, {}, widths, xs, 402)
		renderer.stage_renderer:draw(renderer, 0, 120, widths, xs, 402)
		renderer.note_body_styles[1] = "repeat_bottom"
		renderer.note_renderer:draw(renderer, {{column = 1, long_note = true, body_visible = true,
			head_visible = true, head_y = 200, tail_y = 100}}, widths, xs)
		t:assert(graphics.repeated_quad)
		local quad = graphics.repeated_quad
		renderer.note_renderer:draw(renderer, {{column = 1, long_note = true, body_visible = true,
			head_visible = true, head_y = 200, tail_y = 100}}, widths, xs)
		t:eq(graphics.repeated_quad, quad)
		local score, combo = renderer:getHudElements("screen")[1], renderer:getHudElements("conveyor")[1]
		score:setText("123")
		score:draw()
		combo:setText("123")
		combo.combo_state.alpha = 1
		combo:draw()
		local judge = renderer:getHudElements("conveyor")[2]
		judge:show("perfect", 1)
		judge.judgement_state.elapsed = 0.05
		judge:draw()
		for _, lighting in ipairs(renderer.stage_lightings) do lighting:setHeld(true); lighting:draw(0, 0) end
		t:assert(#draws > 15)
		for _, draw in ipairs(draws) do
			t:assert(draw[1].getDimensions, "draw must receive a GPU Image, not frame metadata")
		end
		love.graphics.newQuad = old_quad
		renderer:unload()
		for _, r in ipairs(resources) do t:eq(r.releases, 1) end
	end)
end

function test.renderer_loads_hud_after_upload_once_per_skin(t)
	with_gpu(function(resources)
		local fs = FakeFilesystem()
		local first = {path = "first", files = {"circularmetre.png", "editor-rate-arrow.png"},
			skin_ini = {Mania = {}, Fonts = {}}}
		local second = {path = "second", files = first.files, skin_ini = first.skin_ini}
		for _, skin in ipairs({first, second}) do
			fs:createDirectory(skin.path)
			for _, name in ipairs(skin.files) do fs:write(skin.path .. "/" .. name, png(4, 4)) end
		end
		local renderer = Renderer(fake_game(fs), first, "4key")
		t:eq(#renderer:getHudElements("screen"), 0)
		renderer:load()
		t:assert(renderer.skin_graphics.loaded)
		local progress = renderer:getHudElements("screen")[3]
		local meter = renderer:getHudElements("conveyor")[3]
		local progress_image, arrow = progress.image, meter.arrow
		t:assert(progress_image and arrow)
		renderer:load()
		t:eq(renderer:getHudElements("screen")[3], progress)
		t:eq(progress.image, progress_image)
		local other = Renderer(fake_game(fs), second, "4key")
		other:load()
		t:ne(other:getHudElements("screen")[3].image, progress_image)
		t:ne(other:getHudElements("conveyor")[3].arrow, arrow)
		other:unload()
		renderer:unload()
		t:eq(progress.image, nil)
		t:eq(meter.arrow, nil)
		for _, resource in ipairs(resources) do t:eq(resource.releases, 1) end
	end)
end

function test.font_consumer_not_prefix_selects_atlas(t)
	local graphics = fixture({["same-0.png"] = png(2, 2), ["score-5.png"] = png(2, 2)})
	with_gpu(function()
		graphics:load({{name = "same-0", group = "playfield"}, {name = "same-0", group = "font"},
			{name = "score-5", group = "playfield"}, {name = "score-5", group = "font"}})
		local score, combo = BitmapFont(graphics, "same", 0, "font"), BitmapFont(graphics, "same", 0, "playfield")
		t:eq(score:getImage("0"), graphics:getAtlasFrame("font", "skin/same-0.png"))
		t:eq(combo:getImage("0"), graphics:getAtlasFrame("playfield", "skin/same-0.png"))
		score:draw("0", 1, 0, 100); combo:draw("0", 1, 0, 100)
		graphics:unload()
	end)
end

function test.real_gpu_regions_density_and_repeated_hold_pixels(t)
	if not love.graphics.isActive() then return end
	local source = love.image.newImageData(4, 4)
	source:mapPixel(function(_, y) return y < 2 and 1 or 0, y >= 2 and 1 or 0, 0, 1 end)
	local encoded = source:encode("png")
	local graphics = fixture({["body@2x.png"] = encoded:getString()})
	encoded:release(); source:release()
	graphics:load({{name = "body", group = "playfield"}})
	local frame = graphics:getFrames("body", nil, "playfield")[1]
	local canvas = love.graphics.newCanvas(12, 16, {dpiscale = 1, format = "rgba8"})
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setColor(1, 1, 1, 1)
	Image.draw(frame, 0, 0, 0, 2, 2)
	local note_renderer = require("rizu.skin.osu.mania.OsuManiaNoteRenderer")()
	local renderer = {
		skin_graphics = graphics, upside_down = false, note_flip = false,
		note_body_styles = {"repeat_bottom"},
		getColumnSuffix = function() return "1" end,
		getColumnFrames = function() return {frame} end,
		getColumnImage = function() return nil end,
		getBoolean = function() return false end,
	}
	note_renderer:draw(renderer, {{column = 1, long_note = true, body_visible = true,
		head_visible = false, head_y = 8, tail_y = 2}}, {4}, {8})
	love.graphics.setCanvas()
	love.graphics.pop()
	local pixels = love.graphics.readbackTexture(canvas)
	t:tdeq({pixels:getPixel(1, 0)}, {1, 0, 0, 1})
	t:tdeq({pixels:getPixel(1, 3)}, {0, 1, 0, 1})
	for y = 0, 5 do
		local red = y % 4 < 2
		t:tdeq({pixels:getPixel(7, y)}, {red and 1 or 0, red and 0 or 1, 0, 1})
	end
	t:tdeq({pixels:getPixel(10, 0)}, {0, 0, 0, 0})
	pixels:release(); canvas:release(); graphics:unload()
end

function test.atlas_draws_keep_order_without_hot_allocations(t)
	local graphics = fixture({["a.png"] = png(2, 2), ["b.png"] = png(2, 2)})
	with_gpu(function(resources, draws)
		graphics:load({{name = "a", group = "playfield"}, {name = "b", group = "font"}})
		local a = graphics:getFrames("a", nil, "playfield")[1]
		local b = graphics:getFrames("b", nil, "font")[1]
		local before = #resources
		for i = 1, 5000 do Image.draw(i % 2 == 0 and a or b, i, 0) end
		t:eq(#resources, before)
		t:eq(#draws, 5000)
		for i = 1, 4 do
			t:eq(draws[i][1], (i % 2 == 0 and a or b).texture)
			t:eq(draws[i][3], i)
		end
		graphics:unload()
	end)
end

function test.standalone_assets_remain_visible_alongside_oversized_atlas_pages(t)
	local graphics = fixture({["small.png"] = png(2, 2), ["huge.png"] = png(2, 20),
		["stage.png"] = png(2, 2)})
	graphics:setAtlasLimit(8)
	with_gpu(function()
		graphics:load({{name = "small", group = "playfield"}, {name = "huge", group = "playfield"},
			{name = "stage", group = "standalone"}})
		t:assert(graphics:getFrames("small", nil, "playfield")[1].texture)
		t:assert(graphics:getFrames("huge", nil, "playfield")[1].texture)
		t:eq(#graphics:getAnimationFrames("huge", nil, "playfield"), 1)
		t:eq(#graphics:getFrames("stage", nil, "standalone"), 1)
		t:eq(#graphics:getFrames("stage"), 1)
		t:eq(graphics.images["skin/huge.png"], nil)
		graphics.fallback_file_map["stage.png"] = "skin/stage.png"
		t:eq(#graphics:getFallbackFrames("stage"), 1)
		graphics:unload()
	end)
end

function test.one_pixel_hold_body_is_stretched_once(t)
	local graphics = fixture({["body.png"] = png(255, 1)})
	with_gpu(function(_, draws)
		graphics:load({{name = "body", group = "playfield"}})
		local body = graphics:getFrames("body", nil, "playfield")[1]
		local renderer = {skin_graphics = graphics, upside_down = false, note_flip = false,
			note_body_styles = {"repeat_bottom"}, getColumnSuffix = function() return "1" end,
			getColumnFrames = function() return {body} end, getColumnImage = function() return nil end,
			getBoolean = function() return false end}
		require("rizu.skin.osu.mania.OsuManiaNoteRenderer")():draw(renderer,
			{{column = 1, long_note = true, head_visible = false, body_visible = true,
				head_y = 300, tail_y = 0}}, {40}, {20})
		t:eq(#draws, 1)
		graphics:unload()
	end)
end

function test.tall_body_crops_top_left_to_device_limit_without_hot_quads(t)
	local data = love.image.newImageData(40, 70000)
	data:setPixel(0, 0, 1, 0, 0, 1)
	data:setPixel(39, 63, 0, 1, 0, 1)
	data:setPixel(39, 64, 0, 0, 1, 1)
	local encoded = data:encode("png")
	local graphics = fixture({["body.png"] = encoded:getString()})
	encoded:release(); data:release()
	graphics:setTextureLimit(64)
	graphics:setAtlasLimit(8)
	local prepared = graphics:prepare({{name = "body", group = "playfield"}})
	local group = prepared.groups.playfield
	local location = group.locations["skin/body.png"]
	local cropped = group.atlases[location.layer]
	t:tdeq({location.width, location.height}, {40, 64})
	t:tdeq({cropped:getPixel(0, 0)}, {1, 0, 0, 1})
	t:tdeq({cropped:getPixel(39, 63)}, {0, 1, 0, 1})
	with_gpu(function(_, draws)
		graphics:upload()
		local body = graphics:getFrames("body", nil, "playfield")[1]
		t:assert(body.texture)
		t:tdeq({Image.dimensions(body)}, {40, 64})
		local renderer = {skin_graphics = graphics, upside_down = false, note_flip = false,
			note_body_styles = {"repeat_bottom"}, getColumnSuffix = function() return "1" end,
			getColumnFrames = function() return {body} end, getColumnImage = function() return nil end,
			getBoolean = function() return false end}
		local new_quad = love.graphics.newQuad
		love.graphics.newQuad = function() error("hot Quad creation") end
		require("rizu.skin.osu.mania.OsuManiaNoteRenderer")():draw(renderer,
			{{column = 1, long_note = true, head_visible = false, body_visible = true,
				head_y = 150, tail_y = 0}}, {40}, {20})
		love.graphics.newQuad = new_quad
		t:assert(#draws > 1)
		for _, draw in ipairs(draws) do
			t:eq(draw[1], body.texture)
			t:eq(draw.viewport[1], 0)
			t:assert(draw.viewport[2] + draw.viewport[4] <= 64)
		end
		graphics:unload()
	end)
end

function test.large_cropped_bodies_share_page_with_heads_and_tails(t)
	local graphics = fixture({["body-0.png"] = png(4, 100), ["body-1.png"] = png(4, 100),
		["head.png"] = png(2, 2), ["tail.png"] = png(2, 2)})
	graphics:setTextureLimit(64)
	graphics:setAtlasLimit(8)
	with_gpu(function(_, draws)
		graphics:load({{name = "body", animation = true, group = "playfield"},
			{name = "head", group = "playfield"}, {name = "tail", group = "playfield"}})
		local frames = graphics:getAnimationFrames("body", nil, "playfield")
		local head = graphics:getFrames("head", nil, "playfield")[1]
		local tail = graphics:getFrames("tail", nil, "playfield")[1]
		t:eq(frames[1].texture, head.texture)
		t:eq(frames[2].texture, head.texture)
		t:eq(tail.texture, head.texture)
		for i = 1, 100 do Image.draw(frames[i % 2 + 1], 0, 0); Image.draw(tail, 0, 0) end
		t:eq(#draws, 200)
		for _, draw in ipairs(draws) do t:eq(draw[1], head.texture) end
		graphics:unload()
	end)
end

---A graphics object whose files a worker could read: it serves a table through the LoveFilesystem class.
---@return rizu.skin.SkinTextures
local function worker_fixture()
	local files = {["note.png"] = png(4, 4)}
	local fs = LoveFilesystem()
	fs.read = function(_, path) return files[path:gsub("^skin/", "")] end
	return Graphics(fs, {path = "skin", files = {"note.png"}})
end

local assets = {{name = "note", group = "playfield"}}

---A stand-in for the worker thread that decodes on the calling thread but yields first, like thread.async.
---@param graphics rizu.skin.SkinTextures
---@param error_message string?
local function fake_worker(graphics, error_message)
	graphics.prepareInThread = function(request)
		coroutine.yield("waiting")
		if error_message then return false, error_message end
		local loader = Atlas.newImageDataLoader(graphics.fs, request.fallback_archive)
		return xpcall(Atlas.prepare, debug.traceback, request, loader)
	end
end

function test.atlas_prepare_packs_plain_data_without_the_gpu(t)
	local data = love.image.newImageData(1, 1)
	local lg = love.graphics
	love.graphics = nil
	local ok, prepared = pcall(Atlas.prepare, {
		file_map = {["note.png"] = "skin/note.png"}, fallback_file_map = {}, assets = assets,
		atlas_limit = 4096,
	}, function(path) return path == "skin/note.png" and love.image.newImageData(4, 4) or nil end)
	love.graphics = lg
	data:release()
	if not ok then error(prepared) end
	t:assert(prepared.groups.playfield.locations["skin/note.png"])
	t:assert(prepared.groups.playfield.locations["\0white"])
	t:eq(prepared.grouped_paths.playfield["skin/note.png"], true)
end

function test.load_async_outside_a_coroutine_loads_synchronously(t)
	local graphics = fixture({["note.png"] = png(4, 4)})
	with_gpu(function()
		t:eq(graphics:loadAsync(assets), true)
		t:eq(graphics.loaded, true)
		graphics:unload()
	end)
end

function test.load_async_yields_while_the_worker_prepares_then_uploads(t)
	local graphics = worker_fixture()
	fake_worker(graphics)
	with_gpu(function()
		local result
		local co = coroutine.create(function() result = graphics:loadAsync(assets) end)
		t:eq(select(2, coroutine.resume(co)), "waiting")
		t:eq(graphics.loading, true)
		t:eq(graphics.loaded, false)
		assert(coroutine.resume(co))
		t:eq(result, true)
		t:eq(graphics.loading, false)
		t:eq(graphics.loaded, true)
		t:assert(graphics:getAtlasFrame("playfield", "skin/note.png"))
		graphics:unload()
	end)
end

function test.load_async_cancelled_by_unload_uploads_nothing(t)
	local graphics = worker_fixture()
	fake_worker(graphics)
	with_gpu(function(resources)
		local result
		local co = coroutine.create(function() result = graphics:loadAsync(assets) end)
		coroutine.resume(co)
		t:eq(graphics:loadAsync(assets), false) -- a second load while one is running does nothing
		graphics:unload()
		assert(coroutine.resume(co))
		t:eq(result, false)
		t:eq(graphics.loaded, false)
		t:eq(graphics.loading, false)
		t:eq(#resources, 0)
	end)
end

function test.load_async_raises_worker_errors_and_stays_unloaded(t)
	local graphics = worker_fixture()
	fake_worker(graphics, "decode failed")
	with_gpu(function()
		local co = coroutine.create(function() graphics:loadAsync(assets) end)
		coroutine.resume(co)
		local ok, err = coroutine.resume(co)
		t:eq(ok, false)
		t:assert(tostring(err):find("decode failed", 1, true))
		t:eq(graphics.loading, false)
		t:eq(graphics.loaded, false)
	end)
end

return test
