local class = require("class")
local BgaView = require("rizu.skin.views.BgaView")

--[[
The play in progress: drawing it, pausing, retrying and the score so far.

	local gameplay = ui.api.gameplay
	gameplay:drawPlayfield(width, height, transform)
	if gameplay:getState() == "pause" then gameplay:resume() end
	local accuracy, text = gameplay:getAccuracy()

Lua skins get the same object and read the notes, the columns and the hits from it every frame.
Nothing here builds a table per call unless it says so.
]]

---What the play is doing. A held key moves through a "from-to" state; getStateProgress() says how far.
---@alias rizu.api.Gameplay.State
---| "play"
---| "pause"
---| "play-pause" # Pause is held. The play pauses at progress 1, resume() cancels.
---| "pause-play" # Resuming after the countdown. pause() cancels.
---| "play-retry" # Retry is held while playing. The chart restarts at progress 1, resume() cancels.
---| "pause-retry" # Retry is held while paused. pause() cancels.

---One note on screen, the engine's own table: read it, keep nothing from it between frames.
---@class rizu.api.Note
---@field type "short"|"long"
---@field start_dt number Seconds since the head crossed the judgement line, times the scroll speed. Negative while it is coming.
---@field end_dt number? The same for the tail of a long note.
---@field getColumn fun(self: rizu.api.Note): string One of getColumns().
---@field getState fun(self: rizu.api.Note): string "clear" until judged. Taps: "passed", "missed". Long notes: "startPassedPressed", "startMissed", "startMissedPressed", "endPassed", "endMissed", "endMissedPassed".

---A setting the skin offers in the gameplay skin editor.
---@class rizu.api.Gameplay.SkinProperty
---@field key string?
---@field label string?
---@field label_key string? Localization key, when there is no label.
---@field type "slider"|"checkbox"|"segmented"|"dropdown"? Defaults to "slider".
---@field min number?
---@field max number?
---@field step number?
---@field value_format (fun(value: number): string)?
---@field options any[]? Values for segmented and dropdown controls.
---@field format (fun(value: any): string)? Value label for segmented and dropdown controls.
---@field setting boolean? Stored in the game settings: do not call saveSkinConfig() after set().
---@field get fun(): any
---@field set fun(value: any)

---@class rizu.api.Gameplay
---@operator call: rizu.api.Gameplay
---@field private game sphere.GameController
---@field private bga_view rizu.skin.views.BgaView?
---@field private beat_chart table?
---@field private beat_points {time: number, beat_duration: number}[]
local Gameplay = class()

---@param game sphere.GameController
function Gameplay:new(game)
	self.game = game
end

local empty = {}

-- The play

---False before the chart has loaded and after close(). The rest needs a loaded play.
---@return boolean
function Gameplay:isLoaded() return self.game.gameplayInteractor:getPlayfield() ~= nil end

---False for the experimental gamemodes: no score, no result screen. See finish().
---@return boolean
function Gameplay:hasScoring() return not self.game.gameplayInteractor.playfield:isExperimental() end

---Call when the gameplay screen is left. Saves the score of a play that got far enough.
function Gameplay:close() self.game.gameplayInteractor:unloadGameplay() end

-- Pause and retry. These do nothing in multiplayer.

---@return rizu.api.Gameplay.State
function Gameplay:getState() return self.game.pauseModel.state end

---@return number progress 0..1 of a "from-to" state, 0 otherwise.
function Gameplay:getStateProgress() return self.game.pauseModel.progress end

---Starts pausing, or cancels a resume. Takes the hold time from the settings.
function Gameplay:pause() self.game.gameplayInteractor:changePlayState("pause") end

---Starts resuming, or cancels a pause or a retry that is being held.
function Gameplay:resume() self.game.gameplayInteractor:changePlayState("play") end

---Starts restarting the chart. Takes the hold time from the settings.
function Gameplay:retry() self.game.gameplayInteractor:changePlayState("retry") end

function Gameplay:skipIntro() self.game.gameplayInteractor:skipIntro() end

-- Adjustments, saved right away

---@param steps integer 1 is one step faster, -1 one step slower.
function Gameplay:changeScrollSpeed(steps) self.game.gameplayInteractor:increasePlaySpeed(steps) end

---The audio offset of this chart only, on top of the global one.
---@param seconds number Also the step it is rounded to: 0.001 for one millisecond.
function Gameplay:changeLocalOffset(seconds) self.game.offsetController:increaseLocalOffset(seconds) end

function Gameplay:resetLocalOffset() self.game.offsetController:resetLocalOffset() end

-- Time

---@return number progress 0..1 from the first note to the last. The play is over at 1.
function Gameplay:getProgress() return self.game.rhythm_engine:getProgress() end

---Seconds of chart time, the clock notes are drawn by.
---@return number
function Gameplay:getTime() return self.game.rhythm_engine.visual_info:getTime() end

-- The score so far. nil in gamemodes without scoring, see getHitCounts() for those.

---@return number? score
---@return string? text The way the judging system writes it.
function Gameplay:getScore()
	local score_engine = self.game.rhythm_engine.score_engine
	local source = score_engine and score_engine.scoreSource
	if source then return source:getScore(), source:getScoreString() end
end

---@return number? accuracy 0..1
---@return string? text "98.52%"
function Gameplay:getAccuracy()
	local score_engine = self.game.rhythm_engine.score_engine
	local source = score_engine and score_engine.accuracySource
	if source then return source:getAccuracy(), source:getAccuracyString() end
end

---@return integer? combo
---@return integer? max_combo
function Gameplay:getCombo()
	local score_engine = self.game.rhythm_engine.score_engine
	local source = score_engine and score_engine.comboSource
	if source then return source:getCombo(), source:getMaxCombo() end
end

---@return number[]? windows Seconds from the note, one per judge from the best. nil without scoring.
function Gameplay:getJudgeWindows()
	local score_engine = self.game.rhythm_engine.score_engine
	local source = score_engine and score_engine.judgesSource
	local windows = source and (source --[[@as any]]).judge_windows
	return windows and windows.windows
end

---Every gamemode has these.
---@return integer hits
---@return integer misses
function Gameplay:getHitCounts()
	local engine = self.game.rhythm_engine
	if engine.score_engine then
		local base = engine.score_engine.scores.base
		return base.hitCount, base.missCount
	end
	local rules = (engine --[[@as rizu.RulesEngine]]).rules
	return rules.hits, rules.misses
end

---@return string[] names From the best judge to the miss. Empty without scoring.
function Gameplay:getJudgeNames()
	local score_engine = self.game.rhythm_engine.score_engine
	local source = score_engine and score_engine.judgesSource
	return source and source:getJudgeNames() or empty
end

---How many judgements getJudgement() has. Grows during the play; it starts again from 0 on retry.
---@return integer
function Gameplay:getJudgementCount()
	local score_engine = self.game.rhythm_engine.score_engine
	return score_engine and #score_engine.sequence or 0
end

---Keep the count you read up to and ask for the new ones each frame, for a hit error meter.
---@param i integer 1..getJudgementCount()
---@return "hit"|"miss"|"early" kind "early" is a press too far before the note to be a hit.
---@return number delta Seconds off the note, negative is early. 0 unless kind is "hit".
---@return integer? judge Index in getJudgeNames().
function Gameplay:getJudgement(i)
	local score_engine = self.game.rhythm_engine.score_engine
	local slice = score_engine.sequence[i]
	local base = slice.base
	local source = score_engine.judgesSource
	local judges = source and slice[source:getKey()]
	local kind = base.isMiss and "miss" or base.isEarlyHit and "early" or "hit"
	return kind, kind == "hit" and slice.misc.deltaTime or 0, judges and (judges.visual_judge or judges.judge_index or judges.last_judge)
end

-- Notes, for skins. Mania only: other gamemodes have no notes or columns here.

---@return rizu.api.Note[] notes Sorted by time. The same table every frame, do not change it.
function Gameplay:getVisibleNotes()
	local visual_engine = self.game.rhythm_engine.visual_engine
	return visual_engine and visual_engine.visible_notes or empty
end

---Builds the list on every call: keep it.
---@return string[] columns "key1", "key2", "scratch1", in the order isColumnPressed() counts them.
function Gameplay:getColumns()
	local chart = self.game.rhythm_engine.chart
	return chart and chart.inputMode:getInputs() or empty
end

---@param column integer Index in getColumns().
---@return boolean
function Gameplay:isColumnPressed(column)
	local engine = self.game.rhythm_engine --[[@as rizu.gameplay.mania.Engine]]
	return engine.isColumnPressed ~= nil and engine:isColumnPressed(column)
end

---Where the play is inside the current beat, for something that pulses with the music.
---@return number? phase 0 on the beat up to 1 before the next one. nil without tempo data.
function Gameplay:getBeatPhase()
	local engine = self.game.rhythm_engine
	local chart = engine.chart
	if not chart then return end
	if self.beat_chart ~= chart then
		local points = {} ---@type {time: number, beat_duration: number}[]
		-- The chart's tempo layer is untyped.
		---@diagnostic disable: no-unknown
		local layer = (chart --[[@as any]]).layers.main ---@type any
		for _, point in ipairs(layer and layer:getPointList() or empty) do
			local tempo = point.tempo ---@type any
			local time = tempo and tempo.point.absoluteTime ---@type number?
			local last = points[#points]
			if time and (not last or last.time ~= time) then
				points[#points + 1] = {time = time, beat_duration = tempo:getBeatDuration()}
			end
		end
		---@diagnostic enable: no-unknown
		self.beat_chart, self.beat_points = chart, points
	end
	local points = self.beat_points
	if #points == 0 then return end
	local time = self:getTime()
	local low, high = 1, #points
	while low < high do
		local middle = math.ceil((low + high) / 2)
		if points[middle].time <= time then low = middle else high = middle - 1 end
	end
	local duration = points[low].beat_duration
	if not (duration > 0 and duration < math.huge) then return end
	local phase = (time - points[low].time) / duration
	return phase - math.floor(phase)
end

-- Drawing. Both take the viewport in drawable pixels, not in UI units.

---The skin's background layer and its playfield.
---@param width number
---@param height number
---@param transform love.Transform Maps viewport coordinates to drawable pixels.
function Gameplay:drawPlayfield(width, height, transform)
	local playfield = self.game.gameplayInteractor.playfield
	playfield:drawBackgroundHud(width, height, transform)
	playfield:draw(width, height, transform)
end

---The videos and images the chart shows behind the notes. Draws nothing when it has none.
---@param width number The area to fill, in the units of the current transform.
---@param height number
---@param brightness number? 0..1, defaults to 1.
---@param scale_mode "cover"|"height"? Fill the area, or fit the height. Defaults to "cover".
function Gameplay:drawBackgroundAnimation(width, height, brightness, scale_mode)
	local view = self.bga_view or BgaView(self.game)
	self.bga_view = view
	view.brightness, view.scale_mode = brightness, scale_mode or "cover"
	view:drawViewport(width, height)
end

---The skin's score, combo and judgements, drawn above the playfield.
---@param width number
---@param height number
---@param transform love.Transform
function Gameplay:drawHud(width, height, transform)
	self.game.gameplayInteractor.playfield:drawHud(width, height, transform)
end

-- Input

---Give it every input event while the gameplay screen is shown.
---@param event {name: string, time: number, [integer]: any}
function Gameplay:receive(event) self.game.gameplayInteractor:receive(event) end

---Call once per frame after the frame's events went to receive().
---@param dt number
function Gameplay:update(dt)
	local interactor = self.game.gameplayInteractor
	if interactor.loaded and interactor.gamemode.deferred_input then
		interactor:update(dt, true)
	end
end

---True when the gamemode is played with the mouse: give it movePointer().
---@return boolean
function Gameplay:usesPointer() return self.game.gameplayInteractor.playfield:usesPointer() end

---@param x number Window pixels.
---@param y number
---@param width number The viewport given to drawPlayfield().
---@param height number
---@param transform love.Transform
---@param time number? Of the event, defaults to now.
function Gameplay:movePointer(x, y, width, height, transform, time)
	local interactor = self.game.gameplayInteractor
	x, y = interactor.playfield:toChart(x, y, width, height, transform)
	interactor:movePointer(x, y, time or self.game.global_timer:getTime())
end

-- The end of a play in a gamemode without scoring. It has no result screen: show a summary instead.

---Call when getProgress() reaches 1. Stops taking input, pauses and keeps the replay of the attempt.
---@return string? status What happened to the replay, nil for autoplay and replays.
function Gameplay:finish()
	local interactor = self.game.gameplayInteractor
	interactor:saveLocalReplay()
	interactor.complete = true
	interactor:pause()
	return interactor.replay_status
end

---Plays the kept replay of this chart from the start.
---@return boolean ok
---@return string? err
function Gameplay:watchLocalReplay()
	local interactor = self.game.gameplayInteractor
	local meta = self.game.rhythm_engine.chartmeta
	local ok, err = interactor:loadLocalReplay(meta.hash, meta.index, meta.mode)
	if not ok then return false, err end
	interactor:retry()
	return true
end

-- Skin editor

---@return rizu.api.Gameplay.SkinProperty[]? properties nil when the skin offers none.
function Gameplay:getSkinProperties()
	local renderer = self.game.gameplayInteractor.playfield:getPlayfield()
	return renderer and renderer.getProperties and renderer:getProperties()
end

---Writes the skin's settings changed with set() to its config file.
---@return boolean ok
---@return string? err
function Gameplay:saveSkinConfig()
	local playfield = self.game.gameplayInteractor.playfield
	if not playfield.skin_config then
		return false, "Skin config is unavailable."
	end
	return playfield:saveSkinConfig()
end

return Gameplay
