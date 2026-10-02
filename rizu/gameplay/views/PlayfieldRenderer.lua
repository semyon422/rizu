local class = require("class")
local Hud = require("rizu.skin.Hud")
local SkinResourceLoader = require("rizu.skin.SkinResourceLoader")

---@class rizu.gameplay.views.PlayfieldRenderer.ResourceLoad
---@field owner rizu.gameplay.views.PlayfieldRenderer
---@field generation integer
---@field future thread.Future
---@field loader rizu.skin.SkinResourceLoader
---@field consumed boolean

---@class rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.gameplay.views.PlayfieldRenderer
---@field background_hud rizu.skin.Hud
---@field foreground_hud rizu.skin.Hud
---@field resources rizu.skin.SkinInstalledResources? Owned textures; components only borrow them.
---@field private resource_generation integer
---@field private resources_ready boolean
---@field private resource_managed boolean
---@field private foreground_hud_transform love.Transform
local PlayfieldRenderer = class()

---@param game sphere.GameController
function PlayfieldRenderer:new(game)
	self.game = game
	self.background_hud = Hud({width = 1, height = 1})
	self.foreground_hud = Hud({width = 1, height = 1})
	self.foreground_hud_transform = love.math.newTransform()
	self.resource_generation = 0
	self.resources_ready = false
	self.resource_managed = self.getResourceRequests ~= PlayfieldRenderer.getResourceRequests
end

---Opt in by overriding this method. Runs on the main thread, without asset IO.
---Return nil for legacy loading through load(); an empty array opts in without textures.
---@param context rizu.skin.SkinResourceContext
---@return rizu.skin.SkinResourceRequest.Asset[]?
function PlayfieldRenderer:getResourceRequests(context) end

---Start decoding without waiting. Does not call load() or loadBackgroundHud().
---Unload runtime objects and resources before replacing an installed set.
---@param context rizu.skin.SkinResourceContext
---@param loader rizu.skin.SkinResourceLoader? Injectable transport for tests.
---@return rizu.gameplay.views.PlayfieldRenderer.ResourceLoad?
function PlayfieldRenderer:startLoadResources(context, loader)
	local assets = self:getResourceRequests(context)
	if not assets then
		self.resource_managed = false
		return
	end
	self.resource_managed = true
	assert(not self.resources, "unload skin resources before reloading")
	self.resource_generation = self.resource_generation + 1
	self.resources_ready = false
	loader = loader or SkinResourceLoader
	return {
		owner = self, generation = self.resource_generation,
		future = loader.startAsync(context:createRequest(assets)), loader = loader, consumed = false,
	}
end

---Consumes decoded ownership and installs textures only; runtime load() remains separate.
---@param decoded rizu.skin.SkinDecodedResources
---@param loader rizu.skin.SkinResourceLoader?
---@return boolean installed
---@return string? error
function PlayfieldRenderer:applyResources(decoded, loader)
	loader = loader or SkinResourceLoader
	if self.resources then
		loader.releaseDecoded(decoded)
		return false, "unload skin resources before installing another set"
	end
	self.resource_managed = true
	self.resources_ready = false
	local resources, err = loader.install(decoded)
	if not resources then return false, err end
	self.resources = resources
	self.resources_ready = true
	return true
end

---Wait in a main-thread coroutine. Always finish tickets, even after cancellation.
---Stale/foreign results are released without upload. Each ticket can be consumed once.
---@param ticket rizu.gameplay.views.PlayfieldRenderer.ResourceLoad
---@return boolean installed
---@return string? error
function PlayfieldRenderer:finishLoadResourcesAsync(ticket)
	assert(not ticket.consumed, "skin resource result already consumed")
	ticket.consumed = true
	local decoded, err = ticket.loader.waitAsync(ticket.future)
	if ticket.owner ~= self or ticket.generation ~= self.resource_generation then
		ticket.loader.releaseDecoded(decoded)
		return false, "skin resource request cancelled or replaced"
	end
	if not decoded then return false, err end
	return self:applyResources(decoded, ticket.loader)
end

---Convenience for callers that do not need to overlap other loading work.
---Legacy renderers are left alone; callers must still invoke their normal load().
---@param context rizu.skin.SkinResourceContext
---@param loader rizu.skin.SkinResourceLoader?
---@return boolean installed
---@return string? error
function PlayfieldRenderer:loadResourcesAsync(context, loader)
	local ticket = self:startLoadResources(context, loader)
	if not ticket then return true end
	return self:finishLoadResourcesAsync(ticket)
end

---Single-threaded counterpart: reads/decodes/uploads immediately on the main thread.
---Does not load runtime objects or either HUD. Legacy skins keep load() unchanged.
---@param context rizu.skin.SkinResourceContext
---@param loader rizu.skin.SkinResourceLoader? Injectable decoder/uploader for tests.
---@return boolean installed
---@return string? error
function PlayfieldRenderer:loadResources(context, loader)
	local assets = self:getResourceRequests(context)
	if not assets then
		self.resource_managed = false
		return true
	end
	assert(not self.resources, "unload skin resources before reloading")
	self.resource_managed = true
	self.resource_generation = self.resource_generation + 1
	self.resources_ready = false
	loader = loader or SkinResourceLoader
	local fs = assert(context.fs, "resource filesystem is required")
	local decoded, err = loader.decode(context:createRequest(assets), fs)
	if not decoded then return false, err end
	return self:applyResources(decoded, loader)
end

---Resource readiness only, not runtime/HUD readiness. Legacy draw behavior is unchanged.
---@return boolean
function PlayfieldRenderer:isResourcesReady()
	return not self.resource_managed or self.resources_ready
end

---Call after runtime unload(). Invalidates pending tickets; does not unload either HUD.
---Late results still need finishLoadResourcesAsync() to release their CPU data.
function PlayfieldRenderer:unloadResources()
	self.resource_generation = self.resource_generation + 1
	self.resources_ready = false
	SkinResourceLoader.releaseInstalled(self.resources)
	self.resources = nil
end

---@param dt number
function PlayfieldRenderer:update(dt) end

function PlayfieldRenderer:loadBackgroundHud()
	self.background_hud:load(self.game)
end

function PlayfieldRenderer:unloadBackgroundHud()
	self.background_hud:unload(self.game)
end

---@param dt number
function PlayfieldRenderer:updateBackgroundHud(dt)
	self.background_hud:update(dt, self.game)
end

---@param width number Viewport width in drawable pixels.
---@param height number Viewport height in drawable pixels.
---@param transform love.Transform Viewport-to-drawable transform.
function PlayfieldRenderer:drawBackgroundHud(width, height, transform)
	self.background_hud:draw(width, height, transform)
end

---@param dt number
function PlayfieldRenderer:updateHud(dt)
	if self.foreground_hud then self.foreground_hud:update(dt, self.game) end
end

---@param width number Viewport width in drawable pixels.
---@param height number Viewport height in drawable pixels.
---@param transform love.Transform Viewport-to-drawable transform.
function PlayfieldRenderer:drawHud(width, height, transform)
	if self.foreground_hud then self.foreground_hud:draw(width, height, transform) end
end

---Draws the HUD in native coordinates covering the complete viewport at the renderer's HUD scale.
---@param transform love.Transform Viewport-to-drawable transform.
---@param viewport_width number Viewport width in drawable pixels.
---@param viewport_height number Viewport height in drawable pixels.
---@param scale number Native-space scale used for rendering.
function PlayfieldRenderer:drawHudInViewport(transform, viewport_width, viewport_height, scale)
	if not self.foreground_hud or scale <= 0 then return end
	self:drawHudInNativeSpace(transform, viewport_width / scale, viewport_height / scale, scale, 0, 0)
end

---Draws the HUD in a renderer-selected native coordinate space.
---@param transform love.Transform Viewport-to-drawable transform.
---@param native_width number Renderer-selected native width.
---@param native_height number Renderer-selected native height.
---@param scale number Native-space scale used for rendering.
---@param offset_x number Native-space horizontal offset.
---@param offset_y number Native-space vertical offset.
function PlayfieldRenderer:drawHudInNativeSpace(transform, native_width, native_height, scale, offset_x, offset_y)
	if not self.foreground_hud or scale <= 0 then return end
	self.foreground_hud_transform:reset()
	self.foreground_hud_transform:apply(transform)
	self.foreground_hud_transform:translate(offset_x, offset_y)
	self.foreground_hud_transform:scale(scale)
	self.foreground_hud:draw(native_width, native_height, self.foreground_hud_transform)
end

function PlayfieldRenderer:load() end

---Optional runtime rebinding after an engine retry; legacy renderers remain unchanged.
function PlayfieldRenderer:rebindRuntime() end

function PlayfieldRenderer:unload() end

---@param x number Window x coordinate in drawable pixels
---@param y number Window y coordinate in drawable pixels
---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
---@return number
---@return number
function PlayfieldRenderer:toChart(x, y, width, height, transform)
	return x, y
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function PlayfieldRenderer:draw(width, height, transform) end

---@param player rizu.preview.NotesPreviewPlayer
---@param width number Preview width in drawable pixels
---@param height number Preview height in drawable pixels
function PlayfieldRenderer:drawPreview(player, width, height) end

return PlayfieldRenderer
