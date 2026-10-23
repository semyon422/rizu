local class = require("class")
local Hud = require("rizu.skin.Hud")
local HudLayout = require("rizu.skin.hud.HudLayout")
local HudElements = require("rizu.skin.hud.HudElements")
local HudEditor = require("rizu.skin.hud.HudEditor")

---Base of gameplay skins. It owns three HUDs: the background (BGA) loaded with the game, and the
---"screen" and "conveyor" layers of HUD elements loaded with the game api. A renderer that sets
---`textures` gets its elements from a layout: the one saved in `config`, or `getDefaultHudLayout()`.
---It requests `getHudAssets()` with its own textures, then calls `loadHud()`.
---@class rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.gameplay.views.PlayfieldRenderer
---@field game sphere.GameController
---@field api rizu.api.GameApi
---@field background_hud rizu.skin.Hud
---@field foreground_hud rizu.skin.Hud The "screen" layer.
---@field conveyor_hud rizu.skin.Hud The "conveyor" layer.
---@field textures rizu.skin.SkinTextures? HUD textures. nil when the renderer has no HUD layout.
---@field config rizu.skin.SkinConfig?
---@field input_mode string?
---@field gamemode string? Config key of the saved layout. nil keeps the layout unsaved.
---@field hud_layers rizu.skin.hud.HudLayout.Layer[] Layers this renderer draws.
---@field getProperties (fun(self: rizu.gameplay.views.PlayfieldRenderer): rizu.api.Gameplay.SkinProperty[])? Settings for the gameplay skin editor.
---@field private foreground_hud_transform love.Transform
---@field private conveyor_hud_transform love.Transform
local PlayfieldRenderer = class()

PlayfieldRenderer.hud_layers = {"screen"}

---@param game sphere.GameController Lua skins pass the game api instead.
function PlayfieldRenderer:new(game)
	self.game = game
	self.api = game and game.api or game
	self.background_hud = Hud({width = 1, height = 1})
	self.foreground_hud = Hud({width = 1, height = 1})
	self.conveyor_hud = Hud({width = 1, height = 1})
	self.foreground_hud_transform = love.math.newTransform()
	self.conveyor_hud_transform = love.math.newTransform()
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
	self.foreground_hud:update(dt, self.api)
	self.conveyor_hud:update(dt, self.api)
end

---Drawable pixels per HUD unit.
---@param width number Viewport width in drawable pixels.
---@param height number Viewport height in drawable pixels.
---@return number
function PlayfieldRenderer:getHudScale(width, height)
	return 1
end

---Where the columns are, in screen layer units. nil without a conveyor layer.
---@param width number Viewport width in drawable pixels.
---@param height number Viewport height in drawable pixels.
---@return number? x
---@return number? y
---@return number? width
---@return number? height
function PlayfieldRenderer:getConveyorRect(width, height) end

---@param width number Viewport width in drawable pixels.
---@param height number Viewport height in drawable pixels.
---@param transform love.Transform Viewport-to-drawable transform.
function PlayfieldRenderer:drawHud(width, height, transform)
	local scale = self:getHudScale(width, height)
	if scale <= 0 then return end
	self:drawHudInViewport(transform, width, height, scale)
	local x, y, conveyor_width, conveyor_height = self:getConveyorRect(width, height)
	if not (x and y and conveyor_width and conveyor_height) then return end
	local conveyor_transform = self.conveyor_hud_transform
	conveyor_transform:reset()
	conveyor_transform:apply(transform)
	conveyor_transform:scale(scale)
	conveyor_transform:translate(x, y)
	self.conveyor_hud:draw(conveyor_width, conveyor_height, conveyor_transform)
end

---Draws the HUD in native coordinates covering the complete viewport at the renderer's HUD scale.
---@param transform love.Transform Viewport-to-drawable transform.
---@param viewport_width number Viewport width in drawable pixels.
---@param viewport_height number Viewport height in drawable pixels.
---@param scale number Native-space scale used for rendering.
function PlayfieldRenderer:drawHudInViewport(transform, viewport_width, viewport_height, scale)
	if scale <= 0 then return end
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
	if scale <= 0 then return end
	self.foreground_hud_transform:reset()
	self.foreground_hud_transform:apply(transform)
	self.foreground_hud_transform:translate(offset_x, offset_y)
	self.foreground_hud_transform:scale(scale)
	self.foreground_hud:draw(native_width, native_height, self.foreground_hud_transform)
end

---@return rizu.skin.hud.HudLayout.Data
function PlayfieldRenderer:getDefaultHudLayout()
	return {}
end

---@return rizu.skin.hud.HudLayout.Data
function PlayfieldRenderer:getHudLayout()
	local saved = self.config and self.gamemode and self.config:getHud(self.gamemode, self.input_mode or "")
	return saved or self:getDefaultHudLayout()
end

---Replaces the HUD elements with the layout's, unloaded. Load their textures, then call loadHud().
function PlayfieldRenderer:buildHud()
	self:unloadHud()
	self.foreground_hud = Hud({width = 1, height = 1})
	self.conveyor_hud = Hud({width = 1, height = 1})
	if not self.textures then return end
	local elements = HudLayout.build(self:getHudLayout(), self.textures, self.hud_layers)
	for _, element in ipairs(elements.screen or {}) do self.foreground_hud:add(element) end
	for _, element in ipairs(elements.conveyor or {}) do self.conveyor_hud:add(element) end
end

---@param layer rizu.skin.hud.HudLayout.Layer
---@return rizu.skin.hud.HudElement[]
function PlayfieldRenderer:getHudElements(layer)
	local hud = layer == "conveyor" and self.conveyor_hud or self.foreground_hud
	return hud.children --[=[@as rizu.skin.hud.HudElement[]]=]
end

---@return rizu.skin.hud.HudLayout.Elements
function PlayfieldRenderer:getHudElementsByLayer()
	return {screen = self:getHudElements("screen"), conveyor = self:getHudElements("conveyor")}
end

---@return rizu.skin.SkinTextures.Asset[]
function PlayfieldRenderer:getHudAssets()
	return HudLayout.getAssets(self:getHudElementsByLayer())
end

function PlayfieldRenderer:loadHud()
	self.foreground_hud:load(self.api)
	self.conveyor_hud:load(self.api)
end

function PlayfieldRenderer:unloadHud()
	self.foreground_hud:unload(self.api)
	self.conveyor_hud:unload(self.api)
end

---Stores the current elements as the player's layout. The caller saves the config file.
function PlayfieldRenderer:saveHudLayout()
	if not (self.config and self.gamemode) then return end
	self.config:setHud(self.gamemode, self.input_mode or "", HudLayout.serialize(self:getHudElementsByLayer()))
end

---Loads again after a change of the layout or of the textures it needs.
function PlayfieldRenderer:reloadHud()
	self:unload()
	self:load()
end

---@param name string Element type.
---@param layer rizu.skin.hud.HudLayout.Layer
---@return string id Editor section id of the new element.
function PlayfieldRenderer:addHudElement(name, layer)
	local Element = assert(HudElements.get(name), "unknown hud element " .. tostring(name))
	local hud = layer == "conveyor" and self.conveyor_hud or self.foreground_hud
	hud:add(Element(nil, assert(self.textures, "renderer has no hud textures")))
	local id = HudEditor.getId(layer, #hud.children)
	self:saveHudLayout()
	self:reloadHud()
	return id
end

---@param layer rizu.skin.hud.HudLayout.Layer
---@param index integer
function PlayfieldRenderer:removeHudElement(layer, index)
	local hud = layer == "conveyor" and self.conveyor_hud or self.foreground_hud
	local element = hud.children[index]
	if not element then return end
	hud:remove(element)
	self:saveHudLayout()
end

---Goes back to the skin's default layout.
function PlayfieldRenderer:resetHudLayout()
	if self.config and self.gamemode then self.config:setHud(self.gamemode, self.input_mode or "", nil) end
	self:reloadHud()
end

---@return rizu.api.Gameplay.SkinSection[]
function PlayfieldRenderer:getHudSections()
	if not self.textures then return {} end
	return HudEditor.getSections(self)
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
