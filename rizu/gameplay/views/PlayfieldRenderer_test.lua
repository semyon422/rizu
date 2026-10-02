local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local ResourceRenderer = require("rizu.skin.test.ResourceRenderer")
local SkinResourceContext = require("rizu.skin.SkinResourceContext")
local Loader = require("rizu.skin.SkinResourceLoader")

local test = {}

---@class rizu.gameplay.views.PlayfieldRendererTest.Image : love.ImageData, love.Image
---@field releases integer
local Image = {}
Image.__index = Image
function Image:release() self.releases = self.releases + 1 end
function Image:getDimensions() return 8, 8 end
function Image:getWidth() return 8 end
function Image:getHeight() return 8 end

---@return rizu.gameplay.views.PlayfieldRendererTest.Image
local function image()
	return setmetatable({releases = 0}, Image)
end

local function context()
	return SkinResourceContext(nil, {
		skin_path = "test-renderer", directory_path = "resources/yi/batch", files = {"icon_x.png"},
	})
end

---@return rizu.skin.SkinDecodedResources
---@return rizu.gameplay.views.PlayfieldRendererTest.Image
local function decoded()
	local data = image()
	return {images = {path = data}, assets = {note = "path", alias = "path"}, errors = {}}, data
end

---@class rizu.gameplay.views.PlayfieldRendererTest.Future : thread.Future
---@field decoded rizu.skin.SkinDecodedResources?
---@field err string?

---@return rizu.skin.SkinResourceLoader
---@return rizu.skin.SkinResourceRequest[]
---@return rizu.gameplay.views.PlayfieldRendererTest.Future[]
---@return rizu.gameplay.views.PlayfieldRendererTest.Image[]
local function transport()
	local requests = {} ---@type rizu.skin.SkinResourceRequest[]
	local futures = {} ---@type rizu.gameplay.views.PlayfieldRendererTest.Future[]
	local uploaded = {} ---@type rizu.gameplay.views.PlayfieldRendererTest.Image[]
	local loader = {
		startAsync = function(request)
			requests[#requests + 1] = request
			local future = {done = false}
			futures[#futures + 1] = future
			return future
		end,
		waitAsync = function(future)
			if not future.done then coroutine.yield() end
			return future.decoded, future.err
		end,
		install = function(resources)
			return Loader.install(resources, function()
				local gpu = image()
				uploaded[#uploaded + 1] = gpu
				return gpu
			end)
		end,
		releaseDecoded = Loader.releaseDecoded,
		releaseInstalled = Loader.releaseInstalled,
	}
	return loader, requests, futures, uploaded
end

---@param t testing.T
function test.test_renderer_declares_installs_and_builds_runtime(t)
	local renderer = ResourceRenderer({})
	local loader, requests, futures, uploaded = transport()
	t:assert(not renderer:isResourcesReady())
	renderer:drawPreview(nil, 32, 32)
	t:eq(renderer.draw_count, 0)
	local ticket = assert(renderer:startLoadResources(context(), loader))
	t:eq(#requests, 1)
	t:eq(requests[1].assets[1].name, "note")
	t:eq(getmetatable(requests[1]), nil)
	t:eq(rawget(requests[1], "game"), nil)
	t:eq(#uploaded, 0)
	local resources, data = decoded()
	futures[1].decoded, futures[1].done = resources, true
	t:assert(renderer:finishLoadResourcesAsync(ticket))
	t:eq(data.releases, 1)
	t:eq(#uploaded, 1)
	t:assert(renderer:isResourcesReady())
	t:assert(not renderer.runtime_loaded)
	t:eq(renderer.resources.assets.note, renderer.resources.assets.alias)
	renderer:load()
	renderer:load()
	local sprite = assert(renderer.sprite)
	-- Real GPU drawing is covered by SkinResourceWorker_test; these textures are fake.
	sprite.draw = function() end
	renderer:drawPreview(nil, 32, 32)
	renderer:drawPreview(nil, 32, 32)
	t:eq(renderer.draw_count, 2)
	t:eq(renderer.sprite, sprite)
	t:eq(#requests, 1)
	t:eq(#uploaded, 1)
	renderer:unload()
	t:eq(uploaded[1].releases, 0)
	t:assert(renderer:isResourcesReady())
	renderer:load() -- Chart/runtime rebind reuses installed textures.
	t:eq(#uploaded, 1)
	renderer:unload()
	renderer:unloadResources()
	renderer:unloadResources()
	t:eq(uploaded[1].releases, 1)
	t:assert(not renderer:isResourcesReady())
	t:assert(not pcall(renderer.finishLoadResourcesAsync, renderer, ticket))
end

---@param t testing.T
function test.cancellation_while_waiting_releases_late_result(t)
	local renderer = ResourceRenderer({})
	local loader, _, futures, uploaded = transport()
	local ticket = assert(renderer:startLoadResources(context(), loader))
	local installed ---@type boolean?
	local co = coroutine.create(function() installed = renderer:finishLoadResourcesAsync(ticket) end)
	assert(coroutine.resume(co))
	t:eq(coroutine.status(co), "suspended")
	renderer:unloadResources()
	local resources, data = decoded()
	futures[1].decoded, futures[1].done = resources, true
	assert(coroutine.resume(co))
	t:eq(installed, false)
	t:eq(data.releases, 1)
	t:eq(#uploaded, 0)
	t:assert(not renderer:isResourcesReady())
end

---@param t testing.T
function test.replacement_and_foreign_owner_reject_results(t)
	local a, b = ResourceRenderer({}), ResourceRenderer({})
	local loader, _, futures, uploaded = transport()
	local old = assert(a:startLoadResources(context(), loader))
	local current = assert(a:startLoadResources(context(), loader))
	local old_resources, old_data = decoded()
	futures[1].decoded, futures[1].done = old_resources, true
	t:eq(a:finishLoadResourcesAsync(old), false)
	t:eq(old_data.releases, 1)
	local foreign_resources, foreign_data = decoded()
	futures[2].decoded, futures[2].done = foreign_resources, true
	t:eq(b:finishLoadResourcesAsync(current), false)
	t:eq(foreign_data.releases, 1)
	t:eq(#uploaded, 0)
	local retry = assert(a:startLoadResources(context(), loader))
	futures[3].decoded, futures[3].done = decoded(), true
	t:assert(a:finishLoadResourcesAsync(retry))
	a:unloadResources()
	t:eq(uploaded[1].releases, 1)
end

---@param t testing.T
function test.errors_leave_renderer_not_ready_and_allow_retry(t)
	local renderer = ResourceRenderer({})
	local loader, _, futures, uploaded = transport()
	local ticket = assert(renderer:startLoadResources(context(), loader))
	futures[1].err, futures[1].done = "decode failed", true
	local ok, err = renderer:finishLoadResourcesAsync(ticket)
	t:eq(ok, false)
	t:eq(err, "decode failed")
	t:assert(not renderer:isResourcesReady())
	t:eq(#uploaded, 0)
	local resources, data = decoded()
	loader.install = function(value)
		Loader.releaseDecoded(value)
		return nil, "upload failed"
	end
	local retry = assert(renderer:startLoadResources(context(), loader))
	futures[2].decoded, futures[2].done = resources, true
	ok, err = renderer:finishLoadResourcesAsync(retry)
	t:eq(ok, false)
	t:eq(err, "upload failed")
	t:eq(data.releases, 1)
	t:assert(not renderer:isResourcesReady())
	t:eq(renderer.resources, nil)
end

---@param t testing.T
function test.legacy_renderer_keeps_main_thread_load_unload(t)
	---@class rizu.gameplay.views.PlayfieldRendererTest.Legacy : rizu.gameplay.views.PlayfieldRenderer
	---@field loaded boolean?
	---@operator call: rizu.gameplay.views.PlayfieldRendererTest.Legacy
	local Legacy = PlayfieldRenderer + {}
	function Legacy:load() self.loaded = true end
	function Legacy:unload() self.loaded = false end
	local renderer = Legacy({})
	local loader = transport()
	t:assert(renderer:isResourcesReady())
	t:eq(renderer:startLoadResources(context(), loader), nil)
	t:assert(renderer:loadResourcesAsync(context(), loader))
	t:eq(renderer.loaded, nil)
	renderer:load()
	t:eq(renderer.loaded, true)
	renderer:unloadResources()
	t:eq(renderer.loaded, true)
	renderer:unload()
	t:eq(renderer.loaded, false)
end

---@param t testing.T
function test.refuses_to_replace_installed_resources(t)
	local renderer = ResourceRenderer({})
	local loader, _, futures, uploaded = transport()
	local ticket = assert(renderer:startLoadResources(context(), loader))
	futures[1].decoded, futures[1].done = decoded(), true
	t:assert(renderer:finishLoadResourcesAsync(ticket))
	local original = renderer.resources
	t:assert(not pcall(renderer.startLoadResources, renderer, context(), loader))
	local replacement, data = decoded()
	t:eq(renderer:applyResources(replacement, loader), false)
	t:eq(data.releases, 1)
	t:eq(renderer.resources, original)
	t:eq(#uploaded, 1)
	t:assert(renderer:isResourcesReady())
	renderer:unloadResources()
	t:eq(uploaded[1].releases, 1)
end

---@param t testing.T
function test.empty_requests_opt_in_without_touching_background_hud(t)
	---@class rizu.gameplay.views.PlayfieldRendererTest.Empty : rizu.gameplay.views.PlayfieldRenderer
	---@operator call: rizu.gameplay.views.PlayfieldRendererTest.Empty
	local Empty = PlayfieldRenderer + {}
	function Empty:getResourceRequests() return {} end
	local renderer = Empty({})
	local background_loads, background_unloads = 0, 0
	renderer.background_hud.load = function() background_loads = background_loads + 1 end
	renderer.background_hud.unload = function() background_unloads = background_unloads + 1 end
	local loader, requests, futures, uploaded = transport()
	t:assert(not renderer:isResourcesReady())
	local ticket = assert(renderer:startLoadResources(context(), loader))
	t:eq(#requests[1].assets, 0)
	futures[1].decoded, futures[1].done = {images = {}, assets = {}, errors = {}}, true
	t:assert(renderer:finishLoadResourcesAsync(ticket))
	t:assert(renderer:isResourcesReady())
	t:eq(#uploaded, 0)
	renderer:unloadResources()
	t:eq(background_loads, 0)
	t:eq(background_unloads, 0)
end

---@param t testing.T
function test.owner_cleans_up_after_runtime_construction_failure(t)
	---@class rizu.gameplay.views.PlayfieldRendererTest.Broken : rizu.skin.test.ResourceRenderer
	---@operator call: rizu.gameplay.views.PlayfieldRendererTest.Broken
	local Broken = ResourceRenderer + {}
	function Broken:load()
		ResourceRenderer.load(self)
		error("runtime construction failed")
	end
	local renderer = Broken({})
	local loader, _, futures, uploaded = transport()
	local ticket = assert(renderer:startLoadResources(context(), loader))
	futures[1].decoded, futures[1].done = decoded(), true
	t:assert(renderer:finishLoadResourcesAsync(ticket))
	t:assert(not pcall(renderer.load, renderer))
	renderer:unload()
	renderer:unloadResources()
	t:eq(renderer.sprite, nil)
	t:eq(renderer.resources, nil)
	t:eq(uploaded[1].releases, 1)
end

---@param t testing.T
function test.synchronous_resources_do_not_start_workers(t)
	local renderer = ResourceRenderer({})
	local ctx = context()
	ctx.fs = require("fs.FakeFilesystem")()
	local data, gpu = image(), image()
	local decodes = 0
	local loader = {
		decode = function(request, fs)
			decodes = decodes + 1
			t:eq(fs, ctx.fs)
			t:eq(#request.assets, 2)
			return {images = {path = data}, assets = {note = "path", alias = "path"}, errors = {}}
		end,
		install = function(value) return Loader.install(value, function() return gpu end) end,
		releaseDecoded = Loader.releaseDecoded,
		startAsync = function() error("synchronous loading must not start a worker") end,
	}
	t:assert(renderer:loadResources(ctx, loader))
	t:eq(decodes, 1)
	t:eq(data.releases, 1)
	t:assert(renderer:isResourcesReady())
	t:assert(not renderer.runtime_loaded)
	renderer:load()
	renderer:unload()
	renderer:unloadResources()
	t:eq(gpu.releases, 1)
end

return test
