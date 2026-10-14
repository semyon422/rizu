local class = require("class")
local Gamemodes = require("rizu.gameplay.Gamemodes")
local PlayfieldPreparation = require("rizu.skin.PlayfieldPreparation")

---@class rizu.gameplay.Playfield
---@operator call: rizu.gameplay.Playfield
---@field preparation rizu.skin.PlayfieldPreparation?
---@field renderer rizu.gameplay.views.PlayfieldRenderer?
---@field skin rizu.skin.Skin?
---@field skin_key string? "gamemode/input_mode" the skin was loaded for.
---@field skin_renderer rizu.gameplay.views.PlayfieldRenderer?
---@field skin_config rizu.skin.SkinConfig?
---@field skin_config_path string?
---@field load_generation integer
local Playfield = class()

---@param game sphere.GameController
function Playfield:new(game)
	self.game = game
	self.load_generation = 0
end

---Every gamemode gets its renderer from the registry, which falls back to the built-in skin of the mode.
---@param gamemode sea.Gamemode
---@param input_mode string
---@param generation integer
---@return rizu.gameplay.views.PlayfieldRenderer?
function Playfield:loadSkin(gamemode, input_mode, generation)
	local key = gamemode .. "/" .. input_mode
	local registry = self.game.skinRegistry
	local skin = registry:resolve(gamemode, input_mode)
	if self.skin == skin and self.skin_key == key and self.skin_renderer then
		return self.skin_renderer
	end
	-- Do not discard dirty configuration if saving a replacement fails.
	assert(self:saveSkinConfig(), "could not save previous skin config")
	---@diagnostic disable-next-line: no-unknown
	local loaded, config, config_path = registry:createRenderer(skin, self.game, gamemode, input_mode, "gameplay")
	local renderer = assert(loaded) --[[@as rizu.gameplay.views.PlayfieldRenderer]]
	if generation ~= self.load_generation then
		pcall(renderer.unload, renderer)
		return
	end
	self.skin = skin
	self.skin_key = key
	self.skin_renderer = renderer
	self.skin_config = config
	self.skin_config_path = config_path
	return renderer
end

-- Selects and loads the renderer in core code; UI consumers only draw it.
function Playfield:load()
	if self.preparation then return end
	self.load_generation = self.load_generation + 1
	local generation = self.load_generation
	local engine = self.game.rhythm_engine
	local mode = engine and engine.chartmeta and engine.chartmeta.mode
	local renderer ---@type rizu.gameplay.views.PlayfieldRenderer?
	if mode then
		local input_mode = assert(engine.chart and engine.chart.inputMode, "Chart input mode is required")
		renderer = self:loadSkin(mode, tostring(input_mode), generation)
	end
	if generation ~= self.load_generation then return end
	if renderer then
		local preparation = PlayfieldPreparation(renderer)
		self.preparation = preparation
		local ready = preparation:load(true)
		if self.preparation ~= preparation then return end
		if not ready then
			self.preparation = nil
			error(preparation.error)
		end
		self.renderer = preparation:getPlayfield()
	end
end

---@return rizu.gameplay.views.PlayfieldRenderer?
function Playfield:getPlayfield()
	return self.preparation and self.preparation:getPlayfield() or nil
end

---@return boolean
function Playfield:usesDirectRenderer()
	return self.renderer ~= nil
end

---@return rizu.gameplay.Gamemode?
function Playfield:getGamemode()
	local engine = self.game.rhythm_engine
	return engine and engine.chartmeta and Gamemodes[engine.chartmeta.mode]
end

---@return boolean
function Playfield:isExperimental()
	local gamemode = self:getGamemode()
	return not not (gamemode and not gamemode.saves_scores)
end

function Playfield:unload()
	self.load_generation = self.load_generation + 1
	local preparation = self.preparation
	self.preparation = nil
	self.renderer = nil
	if preparation then preparation:release() end
end

---@return boolean
---@return string?
function Playfield:saveSkinConfig()
	if self.skin_config and self.skin_config.has_unsaved_changes and self.skin_config_path then
		local saved, save_error = self.skin_config:save(self.game.fs, self.skin_config_path)
		if not saved then
			print(("could not save skin config %s: %s"):format(self.skin_config_path, tostring(save_error)))
			return false, tostring(save_error)
		end
	end
	return true
end

---@return boolean
function Playfield:clearSkin()
	if not self:saveSkinConfig() then return false end
	self.skin = nil
	self.skin_key = nil
	self.skin_renderer = nil
	self.skin_config = nil
	self.skin_config_path = nil
	return true
end

function Playfield:updateBackgroundHud(dt)
	if self.renderer then
		self.renderer:updateBackgroundHud(dt)
	end
end

function Playfield:drawBackgroundHud(width, height, transform)
	if self.renderer then
		self.renderer:drawBackgroundHud(width, height, transform)
	end
end

---@param dt number
function Playfield:update(dt)
	if self.renderer then
		self.renderer:update(dt)
	end
end


---@return boolean
function Playfield:usesPointer()
	local gamemode = self:getGamemode()
	return not not (gamemode and gamemode.uses_pointer)
end

function Playfield:updateHud(dt)
	if self.renderer then self.renderer:updateHud(dt) end
end

---@param width number Gameplay viewport width in drawable pixels.
---@param height number Gameplay viewport height in drawable pixels.
---@param transform love.Transform Maps viewport coordinates to drawable pixels.
function Playfield:drawHud(width, height, transform)
	if self.renderer then self.renderer:drawHud(width, height, transform) end
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function Playfield:draw(width, height, transform)
	if self.renderer then
		self.renderer:draw(width, height, transform)
	end
end

---@param x number Window x coordinate in drawable pixels
---@param y number Window y coordinate in drawable pixels
---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
---@return number
---@return number
function Playfield:toChart(x, y, width, height, transform)
	assert(self:usesPointer(), "Gameplay playfield does not use pointer input")
	return self.renderer:toChart(x, y, width, height, transform)
end

return Playfield
