local Events = require("rizu.api.Events")

--[[
Gameplay skins: which ones exist for a chart, and which one draws it.

	local skins = ui.api.skins
	local gamemode, input_mode = skins:getContext()
	for _, skin in ipairs(skins:getList(gamemode, input_mode)) do ... end
	skins:select(gamemode, input_mode, skin)
	skins:on("skins_changed", function() ... end)

A skin is chosen per gamemode, and for mania per input mode ("4key", "7key", ...).
]]

---@alias rizu.api.Skins.Event
---| "skins_changed" # The list of skins or the chosen ones changed. No arguments.

---@class rizu.api.Skin
---@field path string Unique id.
---@field name string
---@field author string?
---@field version string?
---@field format "builtin"|"osu"|"lua"

---@class rizu.api.Skins : rizu.api.Events
---@operator call: rizu.api.Skins
---@field on fun(self: rizu.api.Skins, event: rizu.api.Skins.Event, f: function): fun()
---@field private game sphere.GameController
local Skins = Events + {}

---@param game sphere.GameController
function Skins:new(game)
	Events.new(self)
	self.game = game
	game.skinRegistry:onChanged(function()
		self:emit("skins_changed")
	end)
end

---The gamemode and input mode of the selected chart, as the next play will have them.
---@return string? gamemode nil when no playable chart is selected
---@return string? input_mode
function Skins:getContext()
	local selector = self.game.chartSelector
	local chartview = selector.chartview
	local input_mode = tostring(self.game.modifierCoordinator.state.inputMode or "")
	if not chartview or not selector:isPlayableChartview(chartview) or input_mode == "" then
		return
	end
	return chartview.chartmeta_mode, input_mode
end

---Skins that can draw this gamemode, in display order. Empty if there are none.
---@param gamemode string
---@param input_mode string
---@return rizu.api.Skin[]
function Skins:getList(gamemode, input_mode)
	return self.game.skinRegistry:getSkinsFor(gamemode, input_mode) --[[@as rizu.api.Skin[] ]]
end

---The skin that will draw this gamemode: the chosen one, or the default when the choice is gone.
---@param gamemode string
---@param input_mode string
---@return rizu.api.Skin?
function Skins:getSelected(gamemode, input_mode)
	return self.game.skinRegistry:resolve(gamemode, input_mode) --[[@as rizu.api.Skin?]]
end

---@param gamemode string
---@param input_mode string
---@param skin rizu.api.Skin One of getList().
function Skins:select(gamemode, input_mode, skin)
	self.game.skinRegistry:select(gamemode, input_mode, skin --[[@as rizu.skin.Skin]])
end

return Skins
