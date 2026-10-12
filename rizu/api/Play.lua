local Events = require("rizu.api.Events")

--[[
How the next play will go: the music speed, the mods, and starting it.

	local play = ui.api.play
	play:changeRate(1)
	label:setText(play:getRateText())
	play:on("rate_changed", function() ... end)
]]

---@alias rizu.api.Play.Event
---| "rate_changed" # The music speed or the way it is counted changed. No arguments.

---@class rizu.api.Play : rizu.api.Events
---@operator call: rizu.api.Play
---@field on fun(self: rizu.api.Play, event: rizu.api.Play.Event, f: function): fun()
---@field private game sphere.GameController
local Play = Events + {}

---@param game sphere.GameController
function Play:new(game)
	Events.new(self)
	self.game = game
	game.timeRateModel:onChanged(function()
		self:emit("rate_changed")
	end)
end

-- Music speed

---How many times faster than normal the music plays: 1 is normal, 1.5 is one and a half times as fast.
---@return number
function Play:getRate() return self.game.replayBase.rate end

---"linear" counts the speed in multipliers (1.05x), "exp" in steps of a tenth of an octave (+1).
---@return sea.RateType
function Play:getRateType() return self.game.replayBase.rate_type end

---The speed the way the player set it: "1.05x" or "+1".
---@return string
function Play:getRateText()
	local value = self.game.timeRateModel:get()
	if self.game.replayBase.rate_type == "exp" then
		return value > 0 and ("+%.0f"):format(value) or ("%.0f"):format(value)
	end
	return ("%.2fx"):format(value)
end

---@param steps integer 1 is one step faster, -1 one step slower.
function Play:changeRate(steps)
	self.game.timeRateModel:increase(steps)
	self.game.modifierSelectModel:change()
end

-- Mods

---How many of the play options that count as mods are on (constant scroll, taps only).
---@return integer
function Play:getModCount()
	local replay_base = self.game.replayBase
	return (replay_base.const and 1 or 0) + (replay_base.tap_only and 1 or 0)
end

---How many mutators will change the chart.
---@return integer
function Play:getMutatorCount() return #self.game.modifierSelectModel.replayBase.modifiers end

-- Starting

---Call before switching to the screen that loads the selected chart.
---@param autoplay boolean The game plays the chart by itself.
function Play:prepare(autoplay)
	local interactor = self.game.gameplayInteractor
	interactor.replaying = false
	interactor.autoplay = autoplay
end

return Play
