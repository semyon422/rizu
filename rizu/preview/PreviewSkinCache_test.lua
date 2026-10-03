local PreviewSkinCache = require("rizu.preview.PreviewSkinCache")
local Settings = require("rizu.config.Settings")
local FakeFilesystem = require("fs.FakeFilesystem")
local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")

---@class rizu.preview.PreviewSkinCacheTest.Renderer : rizu.gameplay.views.PlayfieldRenderer
---@field loads integer
---@field unloads integer
---@field updates integer

local test = {}

---@param on_load (fun(renderer: rizu.preview.PreviewSkinCacheTest.Renderer))?
local function create(on_load)
	local settings = Settings.createConfig(FakeFilesystem())
	local renderers = {} ---@type rizu.preview.PreviewSkinCacheTest.Renderer[]
	local skins = {a = {path = "a"}, b = {path = "b"}}
	local game = {settings = settings}
	game.skinRegistry = {
		getSkinForInputMode = function(_, _, _, path) return skins[path or "a"] end,
		loadSkin = function()
			local renderer = PlayfieldRenderer({})
			---@cast renderer rizu.preview.PreviewSkinCacheTest.Renderer
			renderer.loads, renderer.unloads, renderer.updates = 0, 0, 0
			renderer.load = function(self)
				self.loads = self.loads + 1
				if on_load then on_load(self) end
			end
			renderer.unload = function(self) self.unloads = self.unloads + 1 end
			renderer.update = function(self) self.updates = self.updates + 1 end
			renderers[#renderers + 1] = renderer
			return renderer
		end,
	}
	local model = {active = true, settings = settings, game = game}
	local skinCache = PreviewSkinCache(game, settings)
	model.skinCache = skinCache
	skinCache:load()
	return skinCache, model, renderers
end

local function chart(name)
	return {name = name, chartmeta_mode = "mania", chartdiff_inputmode = "14key"}
end

---@param t testing.T
function test.core_cache_ready_update_and_rebinding(t)
	local _, model, renderers = create()
	model.chartview = chart("A")
	model.skinCache:bind(model.chartview)
	t:eq(model.skinCache:getPlayfield(), renderers[1])
	t:eq(model.skinCache:getState(), "ready")
	model.chartview = chart("B")
	model.skinCache:update(0.1, model.chartview)
	t:eq(#renderers, 1)
	t:eq(renderers[1].loads, 1)
	t:eq(renderers[1].updates, 1)
	model.skinCache:stop()
	model.active = false
	t:eq(model.skinCache:getPlayfield(), nil)
	t:eq(renderers[1].unloads, 0)
	model.active = true
	model.skinCache:load()
	model.skinCache:bind(model.chartview)
	t:eq(model.skinCache:getPlayfield(), renderers[1])
	model.skinCache:release()
	model.skinCache:release()
	t:eq(renderers[1].unloads, 1)
end

---@param t testing.T
function test.settings_change_evicts_and_loads_replacement(t)
	local _, model, renderers = create()
	model.chartview = chart("A")
	model.skinCache:bind(model.chartview)
	model.settings:setStringMap(Settings.keys.gameplay.skins, {["mania/14key"] = "b"})
	t:eq(#renderers, 2)
	t:eq(renderers[1].unloads, 1)
	t:eq(model.skinCache:getPlayfield(), renderers[2])
	model.skinCache:release()
end

---@param t testing.T
function test.failure_is_retained_until_eviction(t)
	local _, model, renderers = create(function() error("broken skin load") end)
	model.chartview = chart("A")
	model.skinCache:bind(model.chartview)
	t:eq(model.skinCache:getState(), "failed")
	t:assert(model.skinCache:getError():find("broken skin load", 1, true))
	model.skinCache:update(0.1, model.chartview)
	t:eq(#renderers, 1)
	t:eq(renderers[1].unloads, 1)
	model.skinCache:release()
	t:eq(renderers[1].unloads, 1)
end

---@param t testing.T
function test.skin_controls_loading_and_stale_load_cannot_replace_current(t)
	local first = true
	local _, model, renderers = create(function()
		if first then first = false; coroutine.yield() end
	end)
	model.chartview = chart("A")
	local co = coroutine.create(function() model.skinCache:bind(model.chartview) end)
	assert(coroutine.resume(co))
	t:eq(model.skinCache:getState(), "loading")
	t:eq(model.skinCache:getPlayfield(), nil)
	model.settings:setStringMap(Settings.keys.gameplay.skins, {["mania/14key"] = "b"})
	t:eq(model.skinCache:getPlayfield(), renderers[2])
	assert(coroutine.resume(co))
	t:eq(model.skinCache:getPlayfield(), renderers[2])
	t:eq(model.skinCache:getState(), "ready")
	model.skinCache:release()
end

---@param t testing.T
function test.release_during_skin_load_does_not_revive(t)
	local _, model = create(function() coroutine.yield() end)
	model.chartview = chart("A")
	local co = coroutine.create(function() model.skinCache:bind(model.chartview) end)
	assert(coroutine.resume(co))
	model.skinCache:release()
	assert(coroutine.resume(co))
	t:eq(model.skinCache:getPlayfield(), nil)
	t:eq(model.skinCache:getState(), "empty")
end

---@param t testing.T
function test.steady_state_skin_binding_does_not_copy_settings_maps(t)
	local _, model, renderers = create()
	model.chartview = chart("A")
	model.skinCache:bind(model.chartview)
	model.settings.getStringMap = function() error("steady-state map copy") end
	model.skinCache:update(0.1, model.chartview)
	model.skinCache:update(0.1, model.chartview)
	t:eq(renderers[1].updates, 2)
	model.skinCache:release()
end

---@param t testing.T
function test.registry_replacement_and_preview_toggle(t)
	local cache, model, renderers = create()
	local cv = chart("A")
	cache:update(0.1, cv)
	model.settings:setBoolean(Settings.keys.select.chart_preview, false)
	cache:update(0.1, cv)
	t:eq(cache:getState(), "empty")
	t:eq(renderers[1].updates, 1)
	model.settings:setBoolean(Settings.keys.select.chart_preview, true)
	cache:update(0.1, cv)
	t:eq(#renderers, 1)
	model.game.skinRegistry.getSkinForInputMode = function() return {path = "replacement"} end
	cache:bind(cv)
	t:eq(#renderers, 2)
	t:eq(renderers[1].unloads, 1)
	cache:release()
end

---@param t testing.T
function test.stop_during_construction_retains_reusable_load(t)
	local cache, model, renderers = create()
	local loadSkin = model.game.skinRegistry.loadSkin
	model.game.skinRegistry.loadSkin = function(...)
		coroutine.yield()
		return loadSkin(...)
	end
	local cv = chart("A")
	local co = coroutine.create(function() cache:bind(cv) end)
	assert(coroutine.resume(co))
	cache:stop()
	assert(coroutine.resume(co))
	t:eq(cache:getPlayfield(), nil)
	cache:load()
	cache:bind(cv)
	t:eq(cache:getState(), "ready")
	t:eq(renderers[1].loads, 1)
	cache:release()
end

---@param t testing.T
function test.release_during_construction_unloads_late_renderer(t)
	local cache, model, renderers = create()
	local loadSkin = model.game.skinRegistry.loadSkin
	model.game.skinRegistry.loadSkin = function(...)
		coroutine.yield()
		return loadSkin(...)
	end
	local co = coroutine.create(function() cache:bind(chart("A")) end)
	assert(coroutine.resume(co))
	cache:release()
	assert(coroutine.resume(co))
	t:eq(renderers[1].unloads, 1)
	t:eq(renderers[1].loads, 0)
	t:eq(cache:getState(), "empty")
	t:eq(cache.unsubscribe, nil)
end

return test
