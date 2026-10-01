local class = require("class")
local Hud = require("rizu.skin.Hud")

---@class rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.gameplay.views.PlayfieldRenderer
---@field background_hud rizu.skin.Hud
---@field foreground_hud rizu.skin.Hud
---@field private foreground_hud_transform love.Transform
local PlayfieldRenderer = class()

---@param game sphere.GameController
function PlayfieldRenderer:new(game)
	self.game = game
	self.background_hud = Hud({width = 1, height = 1})
	self.foreground_hud = Hud({width = 1, height = 1})
	self.foreground_hud_transform = love.math.newTransform()
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
