local ChartPreviewView = require("ui.screens.song_select.ChartPreviewView")

local test = {}
local skins_by_path = {}

local function newPanel()
	local loads = {}
	local registry = {
		loadSkin = function(_, skin, game, input_mode, screen)
			loads[#loads + 1] = {skin = skin, input_mode = input_mode, screen = screen}
			local renderer = {unload_count = 0}
			function renderer:unload()
				self.unload_count = self.unload_count + 1
			end
			return renderer
		end,
		getSkinForInputMode = function(_, _, _, path)
			return path and skins_by_path[path]
		end,
	}
	local panel = setmetatable({
		game = {skinRegistry = registry},
		preview_renderer_cache = {mania = {}},
	}, {__index = ChartPreviewView})
	return panel, loads
end

---@param t testing.T
function test.reuses_preview_renderer_per_keymode_and_skin(t)
	local panel, loads = newPanel()
	local skin = {path = "skin-a", format = "lua"}
	local four_key = panel:getPreviewRenderer("4key", skin)
	t:eq(panel:getPreviewRenderer("4key", skin), four_key)
	t:eq(#loads, 1)
	t:eq(loads[1].screen, "preview")

	local seven_key = panel:getPreviewRenderer("7key", skin)
	t:assert(seven_key ~= four_key)
	t:eq(#loads, 2)

	local other_skin = {path = "skin-b", format = "lua"}
	local replacement = panel:getPreviewRenderer("4key", other_skin)
	t:assert(replacement ~= four_key)
	t:eq(four_key.unload_count, 1)
	t:eq(#loads, 3)

	panel:clearPreviewRendererCache()
	t:eq(replacement.unload_count, 1)
	t:eq(seven_key.unload_count, 1)
	t:eq(panel.playfield_renderer, nil)
	t:tdeq(panel.preview_renderer_cache, {mania = {}})
end

---@param t testing.T
function test.invalidates_only_the_keymode_whose_resolved_skin_changed(t)
	local panel, loads = newPanel()
	local skin_four = {path = "skin-four", format = "lua"}
	local skin_seven_a = {path = "skin-seven-a", format = "lua"}
	local skin_seven_b = {path = "skin-seven-b", format = "lua"}
	skins_by_path = {
		[skin_four.path] = skin_four,
		[skin_seven_a.path] = skin_seven_a,
		[skin_seven_b.path] = skin_seven_b,
	}
	local four_renderer = panel:getPreviewRenderer("4key", skin_four)
	local seven_renderer = panel:getPreviewRenderer("7key", skin_seven_a)

	panel:invalidateChangedPreviewRenderers({
		["mania/4key"] = skin_four.path,
		["mania/7key"] = skin_seven_b.path,
	}, {
		["mania/4key"] = skin_four.path,
		["mania/7key"] = skin_seven_a.path,
	})

	t:eq(four_renderer.unload_count, 0)
	t:eq(seven_renderer.unload_count, 1)
	t:eq(panel.preview_renderer_cache.mania["4key"].renderer, four_renderer)
	t:eq(panel.preview_renderer_cache.mania["7key"], nil)
	t:eq(#loads, 2)
end

---@param t testing.T
function test.loads_osu_skin_renderer_through_registry_for_preview(t)
	local panel, loads = newPanel()
	local skin = {path = "osu-skin", format = "osu"}
	skins_by_path[skin.path] = skin
	local renderer = panel:getPreviewRenderer("4key", skin)
	t:eq(renderer, loads[1] and panel.preview_renderer_cache.mania["4key"].renderer)
	t:eq(#loads, 1)
	t:eq(loads[1].skin, skin)
	t:eq(loads[1].input_mode, "4key")
	t:eq(loads[1].screen, "preview")
end

---@param t testing.T
function test.prepares_once_and_releases_evicted_pending_result(t)
	local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
	local ResourceRenderer = require("rizu.skin.test.ResourceRenderer")
	local context = require("rizu.skin.SkinResourceContext")(nil, {skin_path = "test", directory_path = "skin"})
	local function makeRenderer()
		local renderer = ResourceRenderer({})
		local loads, releases, decoded_releases = 0, 0, 0
		local ticket
		local waiting
		local loader = {
			startAsync = function() return {done = false} end,
			waitAsync = function()
				waiting = coroutine.running()
				coroutine.yield()
				return {images = {}, assets = {}, errors = {}}
			end,
			releaseDecoded = function() decoded_releases = decoded_releases + 1 end,
			install = function() return {images = {}, assets = {}, errors = {}} end,
		}
		local start = PlayfieldRenderer.startLoadResources
		renderer.startLoadResources = function(self, ctx)
			ticket = start(self, ctx, loader)
			return ticket
		end
		renderer.load = function() loads = loads + 1 end
		renderer.unload = function() releases = releases + 1 end
		return renderer, function() return loads, releases, decoded_releases end, function() return waiting end
	end
	local panel = newPanel()
	local renderer, counts, getWaiting = makeRenderer()
	panel.game.skinRegistry.loadSkin = function() return renderer, nil, nil, context end
	local skin = {path = "async", format = "lua"}
	panel:getPreviewRenderer("14key", skin)
	panel:getPreviewRenderer("14key", skin)
	local thread = require("thread")
	local co = assert(getWaiting())
	panel:clearPreviewRendererCache()
	assert(coroutine.resume(co))
	local loads, releases, decoded_releases = counts()
	t:eq(loads, 0)
	t:eq(releases, 1)
	t:eq(decoded_releases, 1)
	t:assert(not renderer:isResourcesReady())
	thread.coroutines[co] = nil
	thread.current = thread.current - 1
end

---@param t testing.T
function test.runtime_failure_releases_resources_and_does_not_retry_from_draw(t)
	local panel = newPanel()
	local ResourceRenderer = require("rizu.skin.test.ResourceRenderer")
	local renderer = ResourceRenderer({})
	local released = 0
	renderer.startLoadResources = function() return {} end
	renderer.finishLoadResourcesAsync = function(self)
		self.resources = {images = {}, assets = {}, errors = {}}
		return true
	end
	renderer.load = function() error("bad runtime") end
	renderer.unloadResources = function(self) released = released + 1; self.resources = nil end
	panel.game.skinRegistry.loadSkin = function() return renderer end
	local skin = {path = "broken", format = "lua"}
	panel:getPreviewRenderer("14key", skin)
	t:eq(released, 1)
	t:eq(panel.preview_renderer_cache.mania["14key"].alive, false)
	t:assert(panel.preview_renderer_cache.mania["14key"].error:find("bad runtime", 1, true))
	panel:clearPreviewRendererCache()
	t:eq(released, 1)
end

---@param t testing.T
function test.completed_preview_resources_are_reused_across_chart_bindings(t)
	local panel = newPanel()
	local ResourceRenderer = require("rizu.skin.test.ResourceRenderer")
	local renderer = ResourceRenderer({})
	local starts, loads = 0, 0
	renderer.startLoadResources = function() starts = starts + 1; return {} end
	renderer.finishLoadResourcesAsync = function(self)
		self.isResourcesReady = function() return true end
		return true
	end
	renderer.load = function() loads = loads + 1 end
	panel.game.skinRegistry.loadSkin = function() return renderer end
	local skin = {path = "ready", format = "lua"}
	skins_by_path.ready = skin
	panel.game.settings = {getStringMap = function() return {["mania/14key"] = "ready"} end}
	panel:bind({chartview = {chartdiff_inputmode = "14key", chartmeta_mode = "mania", name = "A"}})
	panel:bind({chartview = {chartdiff_inputmode = "14key", chartmeta_mode = "mania", name = "B"}})
	t:eq(panel.playfield_renderer, renderer)
	t:eq(starts, 1)
	t:eq(loads, 1)
	t:assert(panel.preview_renderer_cache.mania["14key"].ready)
	panel:clearPreviewRendererCache()
end

return test
