local class = require("class")

---@class rizu.GameInteractor
---@operator call: rizu.GameInteractor
local GameInteractor = class()

---@param game sphere.GameController
function GameInteractor:new(game)
	self.game = game
end

---@return boolean loaded
function GameInteractor:loadGameplaySelectedChartAsync()
	local game = self.game
	return game.gameplayInteractor:loadGameplayAsync(game.chartSelector.chartview)
end

---@param itemIndex integer?
function GameInteractor:loadScoreAsync(itemIndex)
	local game = self.game

	local scoreEntry = game.scoreSelector.chartplay
	if itemIndex then
		scoreEntry = game.scoreSelector.store.items[itemIndex]
	end

	game.resultController:replayNoteChartAsync("result", scoreEntry)

	if itemIndex then
		game.scoreSelector:scrollScore(nil, itemIndex)
	end
end

return GameInteractor
