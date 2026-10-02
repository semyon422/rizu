-- This file requires real LÖVE threads/images; run with ./test-love.
if not love.thread or not love.image then return {} end

local Loader = require("rizu.skin.SkinResourceLoader")
local thread = require("thread")

local test = {}

---@param t testing.T
function test.real_pool_image_data_round_trip(t)
	local decoded ---@type rizu.skin.SkinDecodedResources?
	local installed ---@type rizu.skin.SkinInstalledResources?
	local ResourceRenderer = require("rizu.skin.test.ResourceRenderer")
	local renderer = ResourceRenderer({})
	local context = require("rizu.skin.SkinResourceContext")(nil, {
		skin_path = "test-renderer", directory_path = "resources/yi/batch", files = {"icon_x.png"},
	})
	local had_window = love.window.isOpen()
	if not had_window then assert(love.window.setMode(32, 32)) end
	local ok, err = xpcall(function()
		local future = Loader.startAsync({
			skin_path = "worker-round-trip", directory_path = "resources/yi/batch",
			files = {"icon_x.png"},
			assets = {
				{name = "image", path = "icon_x.png"},
				{name = "alias", path = "./icon_x.png"},
			},
		})
		local deadline = love.timer.getTime() + 10
		while not future.done and love.timer.getTime() < deadline do
			thread.update()
			love.timer.sleep(0.001)
		end
		t:assert(future.done, "skin image worker timed out")
		local decode_error
		decoded, decode_error = Loader.waitAsync(future)
		assert(decoded, decode_error)
		local path = decoded.assets.image
		t:eq(path, "resources/yi/batch/icon_x.png")
		t:eq(decoded.assets.alias, path)
		local data = decoded.images[path]
		t:assert(data:typeOf("ImageData"))
		local expected = love.image.newImageData(path)
		local w, h = expected:getDimensions()
		t:eq(data:getWidth(), w)
		t:eq(data:getHeight(), h)
		t:eq(data:getString(), expected:getString())
		expected:release()
		local upload_error
		installed, upload_error = Loader.install(decoded)
		assert(installed, upload_error)
		t:assert(installed.assets.image:typeOf("Texture"))
		t:eq(installed.assets.image:getWidth(), w)
		t:eq(installed.assets.image, installed.assets.alias)
		t:eq(next(decoded.images), nil)
		t:assert(not renderer:isResourcesReady())
		local ticket = assert(renderer:startLoadResources(context))
		local ready ---@type boolean?
		local load_error ---@type string?
		local co = coroutine.create(function()
			ready, load_error = renderer:finishLoadResourcesAsync(ticket)
		end)
		assert(coroutine.resume(co))
		deadline = love.timer.getTime() + 10
		while coroutine.status(co) ~= "dead" and love.timer.getTime() < deadline do
			thread.update()
			love.timer.sleep(0.001)
		end
		assert(coroutine.status(co) == "dead", "test renderer worker timed out")
		assert(ready, load_error)
		t:assert(renderer:isResourcesReady())
		t:eq(renderer.resources.assets.note, renderer.resources.assets.alias)
		local texture = renderer.resources.assets.note
		t:assert(texture:typeOf("Texture"))
		renderer:load()
		renderer:draw(32, 32, love.math.newTransform())
		renderer:drawPreview(nil, 32, 32)
		t:eq(renderer.draw_count, 2)
		renderer:unload()
		renderer:load()
		t:eq(renderer.resources.assets.note, texture)

		-- Exercise the actual local 320 skin through registry -> worker -> runtime.
		if love.filesystem.getInfo("userdata/dlc/skins_rizu/320/14key.skin.lua") then
			local registry = require("rizu.skin.SkinRegistry")(require("fs.LoveFilesystem")())
			registry:loadFile("userdata/dlc/skins_rizu/320/14key.skin.lua")
			registry:loadFile("userdata/dlc/skins_rizu/320/14key2scratch.skin.lua")
			for _, skin in ipairs(registry:getSkins()) do
				for _, screen in ipairs({"preview", "gameplay"}) do
					local skin_renderer, _, _, skin_context = registry:loadSkin(skin,
						{rhythm_engine = {visual_engine = {visible_notes = {}}}}, skin.metadata.input_modes[1], screen)
					local load_ok, load_err
					local task = coroutine.create(function()
						load_ok, load_err = skin_renderer:loadResourcesAsync(skin_context)
					end)
					assert(coroutine.resume(task))
					local until_time = love.timer.getTime() + 10
					while coroutine.status(task) ~= "dead" and love.timer.getTime() < until_time do
						thread.update()
						love.timer.sleep(0.001)
					end
					assert(coroutine.status(task) == "dead", "320 worker timed out")
					assert(load_ok, load_err)
					local runtime_ok, runtime_err = xpcall(function()
						skin_renderer:load()
						t:eq(#skin_renderer.conveyor.columns, skin.metadata.input_modes[1] == "14key" and 14 or 16)
						local player = {notes = require("rizu.preview.NotesPreview")("", #skin_renderer.conveyor.columns),
							input_mode = skin_renderer.input_mode, time = 0, rate = 1}
						skin_renderer:drawPreview(player, 640, 480)
						skin_renderer:draw(640, 480, love.math.newTransform())
						local owned = skin_renderer.resources
						skin_renderer:rebindRuntime()
						t:eq(skin_renderer.resources, owned)
						skin_renderer:unload()
						skin_renderer:unloadResources()
						local sync_ready, sync_error = skin_renderer:loadResources(skin_context)
						assert(sync_ready, sync_error)
						skin_renderer:load()
						skin_renderer:drawPreview(player, 640, 480)
					end, debug.traceback)
					skin_renderer:unload()
					skin_renderer:unloadResources()
					assert(runtime_ok, runtime_err)
				end
			end
		end
	end, debug.traceback)
	renderer:unload()
	renderer:unloadResources()
	renderer:unloadResources()
	Loader.releaseDecoded(decoded)
	Loader.releaseInstalled(installed)
	thread.stopThreads()
	local deadline = love.timer.getTime() + 10
	while thread.ThreadPool:isRunning() and love.timer.getTime() < deadline do
		thread.update()
		love.timer.sleep(0.001)
	end
	if not had_window then love.window.close() end
	assert(ok, err)
	t:assert(not thread.ThreadPool:isRunning(), "skin worker did not stop")
end

---@param t testing.T
function test.real_corrupt_image_returns_error(t)
	local context = require("rizu.skin.SkinResourceContext")(require("fs.LoveFilesystem")(), {
		skin_path = "bad-image", directory_path = "rizu/skin", files = {},
	})
	local ok, err = pcall(context.loadImageData, context, "SkinResourceLoader.lua")
	t:assert(not ok)
	t:assert(tostring(err):find("bad-image", 1, true))
	t:assert(tostring(err):find("rizu/skin/SkinResourceLoader.lua", 1, true))
end

return test
