local class = require("class")
local AimRenderer = require("rizu.skin.base.AimRenderer")
local OsuAimRenderer = require("rizu.skin.osu.OsuAimRenderer")
local FruitsRenderer = require("rizu.skin.base.FruitsRenderer")
local OsuFruitsRenderer = require("rizu.skin.osu.OsuFruitsRenderer")
local TaikoRenderer = require("rizu.skin.base.TaikoRenderer")
local OsuTaikoRenderer = require("rizu.skin.osu.OsuTaikoRenderer")
local PlayfieldPreparation = require("rizu.skin.PlayfieldPreparation")

local Settings = require("rizu.config.Settings")
local SdvxPlayfield = require("rizu.gameplay.views.SdvxPlayfield")

---@class rizu.gameplay.Playfield
---@operator call: rizu.gameplay.Playfield
---@field aim rizu.skin.base.AimRenderer
---@field osu_aim rizu.skin.osu.OsuAimRenderer
---@field catch rizu.skin.base.FruitsRenderer
---@field osu_catch rizu.skin.osu.OsuFruitsRenderer
---@field taiko rizu.skin.osu.OsuTaikoRenderer
---@field sdvx rizu.gameplay.views.SdvxPlayfield
---@field preparation rizu.skin.PlayfieldPreparation?
---@field renderer rizu.gameplay.views.PlayfieldRenderer?
---@field mania_skin rizu.skin.LoadableSkin?
---@field mania_input_mode string?
---@field mania_renderer rizu.gameplay.views.PlayfieldRenderer?
---@field mania_skin_config rizu.skin.SkinConfig?
---@field mania_skin_config_path string?
---@field load_generation integer
local Playfield = class()

---@param game sphere.GameController
function Playfield:new(game)
	self.game = game
	self.load_generation = 0
	self.aim = AimRenderer(game)
	self.osu_aim = OsuAimRenderer(game)
	self.catch = FruitsRenderer(game)
	self.osu_catch = OsuFruitsRenderer(game)
	self.taiko = OsuTaikoRenderer(game)
	self.sdvx = SdvxPlayfield(game)
end

---@param input_mode string
---@param generation integer
---@return rizu.gameplay.views.PlayfieldRenderer?
function Playfield:loadManiaSkin(input_mode, generation)
	local paths = self.game.settings:getStringMap(Settings.keys.gameplay.skins)
	local skin = self.game.skinRegistry:getSkinForInputMode("mania", input_mode, paths["mania/" .. input_mode])
	assert(skin, "no Mania skin available for " .. input_mode)
	if self.mania_skin == skin and self.mania_input_mode == input_mode and self.mania_renderer then
		return self.mania_renderer
	end
	-- Do not discard dirty configuration if saving a replacement fails.
	assert(self:saveSkinConfig(), "could not save previous Mania skin config")
	---@diagnostic disable-next-line: no-unknown
	local loaded, config, config_path = self.game.skinRegistry:loadSkin(skin, self.game, input_mode, "gameplay")
	local renderer = assert(loaded) --[[@as rizu.gameplay.views.PlayfieldRenderer]]
	if generation ~= self.load_generation then
		pcall(renderer.unload, renderer)
		return
	end
	self.mania_skin = skin
	self.mania_input_mode = input_mode
	self.mania_renderer = renderer
	self.mania_skin_config = config
	self.mania_skin_config_path = config_path
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
	if engine and mode == "osu" then renderer = self.osu_aim
	elseif engine and engine.aim_rules then renderer = self.aim
	elseif engine and mode == "catch" then renderer = self.osu_catch
	elseif engine and engine.catch_rules then renderer = self.catch
	elseif engine and (engine.taiko_rules or mode == "taiko") then renderer = self.taiko
	elseif engine and (engine.sdvx_rules or mode == "sdvx") then renderer = self.sdvx
	elseif mode == "mania" then
		local input_mode = assert(engine.chart and engine.chart.inputMode, "Chart input mode is required")
		renderer = self:loadManiaSkin(tostring(input_mode), generation)
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

---@return boolean
function Playfield:isExperimental()
	local engine = self.game.rhythm_engine
	if not engine then return false end
	local mode = engine.chartmeta and engine.chartmeta.mode
	return not not (
		engine.aim_rules or engine.catch_rules or engine.taiko_rules or engine.sdvx_rules
		or mode == "osu" or mode == "catch" or mode == "taiko" or mode == "sdvx"
	)
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
	if self.mania_skin_config and self.mania_skin_config.has_unsaved_changes and self.mania_skin_config_path then
		local saved, save_error = self.mania_skin_config:save(self.game.fs, self.mania_skin_config_path)
		if not saved then
			print(("could not save skin config %s: %s"):format(self.mania_skin_config_path, tostring(save_error)))
			return false, tostring(save_error)
		end
	end
	return true
end

---@return boolean
function Playfield:clearManiaSkin()
	if not self:saveSkinConfig() then return false end
	self.mania_skin = nil
	self.mania_renderer = nil
	self.mania_input_mode = nil
	self.mania_skin_config = nil
	self.mania_skin_config_path = nil
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
	local engine = self.game.rhythm_engine
	return not not (engine and (engine.aim_rules or engine.chartmeta and engine.chartmeta.mode == "osu"))
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
