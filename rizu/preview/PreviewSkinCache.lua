local class = require("class")
local Settings = require("rizu.config.Settings")
local PlayfieldPreparation = require("rizu.skin.PlayfieldPreparation")

---@alias rizu.preview.PreviewSkinCache.State "empty"|"loading"|"ready"|"failed"

---@class rizu.preview.PreviewSkinCache.Entry
---@field skin rizu.skin.Skin
---@field preparation rizu.skin.PlayfieldPreparation?
---@field error string?

---Owns preview skin selection and renderer lifetimes. It deliberately has no
---reference to PreviewModel so preview and gameplay renderers remain separate.
---@class rizu.preview.PreviewSkinCache
---@operator call: rizu.preview.PreviewSkinCache
---@field game sphere.GameController
---@field settings rizu.config.Config
---@field cache {[string]: rizu.preview.PreviewSkinCache.Entry}
---@field current rizu.preview.PreviewSkinCache.Entry?
---@field unsubscribe (fun())?
---@field active boolean
---@field released boolean
---@field chartview rizu.preview.PreviewChartview?
local PreviewSkinCache = class()

---@param game sphere.GameController
---@param settings rizu.config.Config
function PreviewSkinCache:new(game, settings)
	self.game = game
	self.settings = settings
	self.cache = {}
	self.active = false
	self.released = false
end

function PreviewSkinCache:load()
	self.released = false
	self.active = true
	local registry = self.game.skinRegistry
	if registry and not self.unsubscribe then
		self.unsubscribe = registry:onChanged(function() self:invalidate() end)
	end
end

---@param chartview rizu.preview.PreviewChartview?
function PreviewSkinCache:bind(chartview)
	self.chartview = chartview
	if self.released or not self.active then return end
	local registry = self.game.skinRegistry
	local input_mode = chartview and chartview.chartdiff_inputmode
	local skin ---@type rizu.skin.Skin?
	if registry and chartview and input_mode and chartview.chartmeta_mode == "mania"
		and self.settings:getBoolean(Settings.keys.select.chart_preview) then
		skin = registry:resolve("mania", input_mode)
	end
	if not skin then
		self.current = nil
		return
	end
	if self.current and self.current.skin == skin and self.cache[input_mode] == self.current then
		return
	end
	local mode = assert(input_mode)
	local entry = self.cache[mode] ---@type rizu.preview.PreviewSkinCache.Entry?
	if entry and entry.skin ~= skin then self:evict(mode); entry = nil end
	if not entry then
		entry = {skin = skin}
		self.cache[mode] = entry
		self.current = entry
		local captured = entry
		local ok, err = xpcall(function()
			---@diagnostic disable-next-line: no-unknown
			local loaded = registry:createRenderer(skin, self.game, "mania", mode, "preview")
			local renderer = assert(loaded) --[[@as rizu.gameplay.views.PlayfieldRenderer]]
			if self.cache[mode] ~= captured or self.released then
				pcall(renderer.unload, renderer)
				return
			end
			local preparation = PlayfieldPreparation(renderer)
			captured.preparation = preparation
			preparation:load(false)
		end, debug.traceback)
		if not ok then
			entry.error = tostring(err)
			if entry.preparation then entry.preparation:release() end
		end
		if self.current ~= entry then return end
	end
	self.current = entry
end

---@param input_mode string
function PreviewSkinCache:evict(input_mode)
	local entry = self.cache[input_mode]
	if not entry then return end
	if self.current == entry then self.current = nil end
	self.cache[input_mode] = nil
	if entry.preparation then entry.preparation:release() end
end

function PreviewSkinCache:invalidate()
	local registry = self.game.skinRegistry
	if not registry then return end
	for mode, entry in pairs(self.cache) do
		if entry.skin ~= registry:resolve("mania", mode) then
			self:evict(mode)
		end
	end
	if self.active then self:bind(self.chartview) end
end

---@param dt number
---@param chartview rizu.preview.PreviewChartview?
function PreviewSkinCache:update(dt, chartview)
	self:bind(chartview)
	local renderer = self:getPlayfield()
	if renderer then renderer:update(dt) end
end

---@return rizu.gameplay.views.PlayfieldRenderer?
function PreviewSkinCache:getPlayfield()
	if self.released or not self.active then return end
	local current = self.current
	return current and current.preparation and current.preparation:getPlayfield() or nil
end

---@return rizu.preview.PreviewSkinCache.State
function PreviewSkinCache:getState()
	local current = self.current
	local preparation = current and current.preparation
	if not current then return "empty" end
	if current.error or preparation and preparation.state == "failed" then return "failed" end
	if preparation and preparation:getPlayfield() then return "ready" end
	return "loading"
end

---@return string?
function PreviewSkinCache:getError()
	local current = self.current
	return current and (current.error or current.preparation and current.preparation.error) or nil
end

---Stop drops only the active binding; cached renderers are reusable.
function PreviewSkinCache:stop()
	self.active = false
	self.current = nil
	self.chartview = nil
end

function PreviewSkinCache:release()
	if self.released then return end
	self:stop()
	self.released = true
	if self.unsubscribe then self.unsubscribe(); self.unsubscribe = nil end
	local cache = self.cache
	self.cache = {}
	for _, entry in pairs(cache) do
		if entry.preparation then entry.preparation:release() end
	end
end

return PreviewSkinCache
