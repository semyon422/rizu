local Layout = require("ui.views.GameplayView.Layout")
local Background = require("ui.views.GameplayView.Background")
local Foreground = require("ui.views.GameplayView.Foreground")
local PauseSubscreen = require("ui.views.GameplayView.PauseSubscreen")
local ScreenView = require("ui.views.ScreenView")
local SequenceView = require("sphere.views.SequenceView")
local just = require("just")

---@class ui.GameplayView: ui.ScreenView
---@operator call: ui.GameplayView
local GameplayView = ScreenView + {}

---@param game sphere.GameController
function GameplayView:new(game)
	self.game = game
	self.sequenceView = SequenceView()
end

function GameplayView:load()
	-- self.game.rhythmModel.observable:add(self.sequenceView)
	self.game.gameInteractor:loadGameplaySelectedChart()

	self.subscreen = ""
	self.failed = false

	local sequenceView = self.sequenceView

	sequenceView.game = self.game
	sequenceView.subscreen = "gameplay"
	sequenceView:setSequenceConfig(self.game.noteSkinModel.noteSkin.playField)
	sequenceView:load()
end

function GameplayView:unload()
	self.game.gameplayInteractor:unloadGameplay()
	-- self.game.rhythmModel.observable:remove(self.sequenceView)
	self.sequenceView:unload()
end

function GameplayView:retry()
	self.game.gameplayInteractor:retry()
	self.sequenceView:unload()
	self.sequenceView:load()
end

function GameplayView:draw()
	just.container("screen container", true)
	self:keypressed()
	self:keyreleased()

	Layout:draw()
	Background(self)
	self.sequenceView:draw()
	if self.subscreen == "pause" then
		PauseSubscreen(self)
	end
	Foreground(self)
	just.container()

	---@type rizu.RhythmEngine
	local rhythm_engine = self.game.rhythm_engine

	local state = self.game.pauseModel.state
	local multiplayerModel = self.game.multiplayerModel
	local isPlaying = multiplayerModel.client:isInRoom() and multiplayerModel.client.is_playing
	if
		not love.window.hasFocus() and
		state == "play" and
		not self.game.gameplayInteractor.autoplay and
		not isPlaying
	-- self.game.rhythmModel.inputManager.mode ~= "internal"
	then
		self.game.gameplayInteractor:pause()
	end
end

---@param dt number
function GameplayView:update(dt)
	local state = self.game.pauseModel.state
	if state == "play" then
		self.subscreen = ""
	elseif state == "pause" then
		self.subscreen = "pause"
	end

	if self.game.pauseModel.needRetry then
		self.failed = false
		self:retry()
	end

	-- local rhythm_engine = self.game.rhythm_engine
	-- if rhythm_engine.time_engine.time >= rhythm_engine:getEndTime() + 1 then
	-- 	self:quit()
	-- end

	local actionOnFail = self.game.configModel.configs.settings.gameplay.actionOnFail
	local failed = self.game.rhythm_engine.score_engine.healthsSource:isFailed()
	if failed and not self.failed then
		if actionOnFail == "pause" then
			self.game.gameplayInteractor:changePlayState("pause")
			self.failed = true
		elseif actionOnFail == "quit" then
			self:quit()
		end
	end

	local multiplayerModel = self.game.multiplayerModel
	if multiplayerModel.client:isInRoom() and not multiplayerModel.client.is_playing then
		self:quit()
	end

	self.sequenceView:update(dt)
end

---@param event table
function GameplayView:receive(event)
	self.game.gameplayInteractor:receive(event)
	self.sequenceView:receive(event)
end

function GameplayView:quit()
	if self.game.gameplayInteractor:hasResult() then
		self:changeScreen("resultView")
	elseif self.game.multiplayerModel.client:isInRoom() then
		self:changeScreen("multiplayerView")
	else
		self:changeScreen("selectView")
	end
end

function GameplayView:keypressed()
	local input = self.game.configModel.configs.settings.input
	local offsetController = self.game.offsetController
	local gameplayInteractor = self.game.gameplayInteractor

	local kp = just.keypressed
	if kp(input.skipIntro) then
		gameplayInteractor:skipIntro()
	elseif kp(input.offset.decrease) then
		offsetController:increaseLocalOffset(-0.001)
	elseif kp(input.offset.increase) then
		offsetController:increaseLocalOffset(0.001)
	elseif kp(input.offset.reset) then
		offsetController:resetLocalOffset()
		-- elseif kp(input.timeRate.decrease) then gameplayInteractor:increaseTimeRate(-0.05)
		-- elseif kp(input.timeRate.increase) then gameplayInteractor:increaseTimeRate(0.05)
	elseif kp(input.playSpeed.decrease) then
		gameplayInteractor:increasePlaySpeed(-1)
	elseif kp(input.playSpeed.increase) then
		gameplayInteractor:increasePlaySpeed(1)
	end

	local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
	local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
	local state = self.game.pauseModel.state
	if state == "play" then
		if kp(input.pause) and not shift then
			gameplayInteractor:changePlayState("pause")
		elseif kp(input.pause) and ctrl then
			self:quit()
		elseif kp(input.quickRestart) then
			gameplayInteractor:changePlayState("retry")
		end
	elseif state == "pause" then
		if kp(input.pause) and not shift then
			gameplayInteractor:changePlayState("play")
		elseif kp(input.pause) and ctrl then
			self:quit()
		elseif kp(input.quickRestart) then
			gameplayInteractor:changePlayState("retry")
		end
	elseif state == "pause-play" and kp(input.pause) then
		gameplayInteractor:changePlayState("pause")
	end
end

function GameplayView:keyreleased()
	local state = self.game.pauseModel.state
	local input = self.game.configModel.configs.settings.input
	local gameplayInteractor = self.game.gameplayInteractor

	local kr = just.keyreleased
	if state == "play-pause" and kr(input.pause) then
		gameplayInteractor:changePlayState("play")
	elseif state == "pause-retry" and kr(input.quickRestart) then
		gameplayInteractor:changePlayState("pause")
	elseif state == "play-retry" and kr(input.quickRestart) then
		gameplayInteractor:changePlayState("play")
	end
end

return GameplayView
