local View = require("gui.View")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local BgaRenderer = require("ui.views.BgaRenderer")
local Settings = require("rizu.config.Settings")
local thread = require("thread")

local lg = love.graphics

---@class ui.screens.song_select.ChartPreviewView.CachedRenderer
---@field skin rizu.skin.LoadableSkin
---@field renderer rizu.gameplay.views.PlayfieldRenderer
---@field alive boolean
---@field ready boolean
---@field error string?

---@class ui.screens.song_select.ChartPreviewView : gui.View
---@operator call: ui.screens.song_select.ChartPreviewView
---@field bg_model sphere.BackgroundModel
---@field game sphere.GameController
---@field preview_canvas love.Canvas?
---@field bga_renderer ui.views.BgaRenderer
---@field playfield_renderer rizu.gameplay.views.PlayfieldRenderer?
---@field preview_renderer_cache {[string]: {[string]: ui.screens.song_select.ChartPreviewView.CachedRenderer}}
---@field chartview_formatter ui.formatters.ChartviewFormatter?
---@field unsubscribe_skins fun()
local ChartPreviewView = View + {}

---@param bg_model sphere.BackgroundModel
---@param game sphere.GameController
function ChartPreviewView:new(bg_model, game)
	View.new(self)
	self.bg_model = bg_model
	self.game = game
	self.bga_renderer = BgaRenderer()
	self.preview_renderer_cache = {mania = {}}
	self.unsubscribe_skins = game.settings:subscribeStringMap(Settings.keys.gameplay.skins, function(value, old_value)
		self:invalidateChangedPreviewRenderers(value, old_value)
		if self.chartview_formatter then self:bind(self.chartview_formatter) end
	end)
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function ChartPreviewView:onLayoutChanged(old_x, old_y, old_width, old_height)
	local canvas_width = math.max(1, math.floor(self.width))
	local canvas_height = math.max(1, math.floor(self.height))
	if self.preview_canvas then
		local old_canvas_width, old_canvas_height = self.preview_canvas:getDimensions()
		if old_canvas_width == canvas_width and old_canvas_height == canvas_height then
			return
		end
		self.preview_canvas:release()
	end
	self.preview_canvas = lg.newCanvas(canvas_width, canvas_height)
end

---@param input_mode string
---@param skin_paths rizu.config.StringMap
---@return rizu.skin.SkinInfo|rizu.skin.OsuSkinDiscovery?
function ChartPreviewView:getPreviewSkin(input_mode, skin_paths)
	local registry = self.game.skinRegistry
	if not registry then return nil end
	local selected_path = skin_paths["mania/" .. input_mode]
	return registry:getSkinForInputMode("mania", input_mode, selected_path)
end

---@param cached ui.screens.song_select.ChartPreviewView.CachedRenderer
function ChartPreviewView:releasePreviewRenderer(cached)
	if cached.alive == false then return end
	cached.alive = false
	cached.ready = false
	local renderer = cached.renderer
	if self.playfield_renderer == renderer then self.playfield_renderer = nil end
	if renderer.unload then renderer:unload() end
	if renderer.unloadResources then renderer:unloadResources() end
end

---@param cached ui.screens.song_select.ChartPreviewView.CachedRenderer
---@param context rizu.skin.SkinLoadContext
function ChartPreviewView:preparePreviewRenderer(cached, context)
	local renderer = cached.renderer
	-- Legacy renderers retain their existing deferred/main-thread behavior.
	if not renderer.isResourcesReady or renderer:isResourcesReady() then return end
	cached.ready = false
	local started, ticket = pcall(renderer.startLoadResources, renderer, context)
	if not started then
		cached.error = tostring(ticket)
		self:releasePreviewRenderer(cached)
		print("Chart preview skin load failed: " .. cached.error)
		return
	end
	if not ticket then cached.ready = true; return end
	thread.coro(function()
		local ok, err = renderer:finishLoadResourcesAsync(ticket)
		if not cached.alive then return end
		if ok then
			ok, err = xpcall(function() renderer:load() end, debug.traceback)
		end
		if not ok then
			cached.error = tostring(err)
			self:releasePreviewRenderer(cached)
			print("Chart preview skin load failed: " .. cached.error)
			return
		end
		cached.ready = true
	end)()
end

---@param skin_paths rizu.config.StringMap
---@param old_skin_paths rizu.config.StringMap
function ChartPreviewView:invalidateChangedPreviewRenderers(skin_paths, old_skin_paths)
	local mode_cache = self.preview_renderer_cache.mania
	for input_mode, cached in pairs(mode_cache) do
		local old_skin = self:getPreviewSkin(input_mode, old_skin_paths)
		local new_skin = self:getPreviewSkin(input_mode, skin_paths)
		if old_skin ~= new_skin then
			self:releasePreviewRenderer(cached)
			mode_cache[input_mode] = nil
		end
	end
end

---@param input_mode string
---@param skin rizu.skin.SkinInfo|rizu.skin.OsuSkinDiscovery
---@return rizu.gameplay.views.PlayfieldRenderer?
function ChartPreviewView:getPreviewRenderer(input_mode, skin)
	local mode_cache = self.preview_renderer_cache.mania
	local cached = mode_cache[input_mode]
	if cached and cached.skin == skin then
		return cached.alive and cached.renderer or nil
	end
	if cached then self:releasePreviewRenderer(cached) end

	---@diagnostic disable-next-line: no-unknown
	local loaded_renderer, config, config_path, context = self.game.skinRegistry:loadSkin(skin, self.game, input_mode, "preview")
	local renderer = loaded_renderer --[[@as rizu.gameplay.views.PlayfieldRenderer?]]
	if renderer then
		local entry = {skin = skin, renderer = renderer, alive = true, ready = true}
		mode_cache[input_mode] = entry
		self:preparePreviewRenderer(entry, context)
	else
		mode_cache[input_mode] = nil
	end
	return renderer and mode_cache[input_mode].alive and renderer or nil
end

function ChartPreviewView:clearPreviewRendererCache()
	for _, mode_cache in pairs(self.preview_renderer_cache) do
		for _, cached in pairs(mode_cache) do
			self:releasePreviewRenderer(cached)
		end
	end
	self.preview_renderer_cache = {mania = {}}
	self.playfield_renderer = nil
end

---@param cvf ui.formatters.ChartviewFormatter
function ChartPreviewView:bind(cvf)
	self.chartview_formatter = cvf
	self.playfield_renderer = nil
	local input_mode = cvf.chartview.chartdiff_inputmode
	if input_mode and cvf.chartview.chartmeta_mode == "mania" then
		local skin_paths = self.game.settings:getStringMap(Settings.keys.gameplay.skins)
		local skin = self:getPreviewSkin(input_mode, skin_paths)
		if skin then
			self.playfield_renderer = self:getPreviewRenderer(input_mode, skin)
		end
	end
end

function ChartPreviewView:unload()
	self.unsubscribe_skins()
	self:clearPreviewRendererCache()
	if self.preview_canvas then
		self.preview_canvas:release()
		self.preview_canvas = nil
	end
end

---@param dt number
function ChartPreviewView:update(dt)
	local renderer = self.playfield_renderer
	if renderer and renderer.isResourcesReady and renderer:isResourcesReady() then
		for _, entry in pairs(self.preview_renderer_cache.mania) do
			if entry.renderer == renderer and entry.alive and entry.ready then
				renderer:update(dt)
				break
			end
		end
	end
end

function ChartPreviewView:draw()
	local canvas = self.preview_canvas
	if not canvas then return end
	local images = self.bg_model.images
	local alpha = self.bg_model.alpha
	local w, h = canvas:getDimensions()

	lg.push("all")
	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)
	lg.origin()
	-- The view's screen-space clip does not apply while drawing to this canvas.
	lg.setScissor()

	for i = 1, 2 do
		if not images[i] then break end
		love.graphics.setColor(1, 1, 1, i == 1 and 1 or alpha)
		local image = images[i]
		local image_width, image_height = image:getDimensions()
		local scale = math.max(h / image_height, w / image_width)
		lg.draw(image, (w - image_width * scale) * 0.5, (h - image_height * scale) * 0.5, 0, scale, scale)
	end

	Painter.setColorRgb(1, 1, 1)
	Painter.setOpacity(1)
	local preview_model = self.game.previewModel
	local bga_engine = preview_model and preview_model.bgaPreviewPlayer
	if bga_engine then
		self.bga_renderer:draw(bga_engine, preview_model:getTime(), w, h)
	end
	local player = self.game.previewModel.chartPreview
	if self.playfield_renderer and (not self.playfield_renderer.isResourcesReady or
			self.playfield_renderer:isResourcesReady()) then
		self.playfield_renderer:drawPreview(player, w, h)
	end
	lg.pop()

	lg.draw(canvas)
	Resources.sprites.select_bg_overlay:draw(0, 0, 0, self.width / Resources.sprites.select_bg_overlay:getWidth(),
		self.height / Resources.sprites.select_bg_overlay:getHeight())
end

return ChartPreviewView
