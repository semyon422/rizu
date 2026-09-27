local class = require("class")

---@class rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.gameplay.views.PlayfieldRenderer
---@field hud rizu.skin.Hud?
---@field _hud_transform love.Transform
local PlayfieldRenderer = class()

---@param game sphere.GameController
function PlayfieldRenderer:new(game)
	self.game = game
	self._hud_transform = love.math.newTransform()
end

---@param dt number
function PlayfieldRenderer:update(dt) end

---@param dt number
function PlayfieldRenderer:updateHud(dt)
	if self.hud then self.hud:update(dt, self.game) end
end

---@param width number Viewport width in drawable pixels.
---@param height number Viewport height in drawable pixels.
---@param transform love.Transform Viewport-to-drawable transform.
function PlayfieldRenderer:drawHud(width, height, transform)
	if self.hud then self.hud:draw(width, height, transform) end
end

---Draws the HUD in a renderer-selected native coordinate space.
---@param transform love.Transform Viewport-to-drawable transform.
---@param native_width number Renderer-selected native width.
---@param native_height number Renderer-selected native height.
---@param scale number Native-space scale used for rendering.
---@param offset_x number Native-space horizontal offset.
---@param offset_y number Native-space vertical offset.
function PlayfieldRenderer:drawHudInNativeSpace(transform, native_width, native_height, scale, offset_x, offset_y)
	if not self.hud or scale <= 0 then return end
	self._hud_transform:reset()
	self._hud_transform:apply(transform)
	self._hud_transform:translate(offset_x, offset_y)
	self._hud_transform:scale(scale)
	self.hud:draw(native_width, native_height, self._hud_transform)
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
