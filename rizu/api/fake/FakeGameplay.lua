local class = require("class")

---`rizu.api.Gameplay` with nothing loaded: the preview has no gameplay screen.
---@class rizu.api.fake.FakeGameplay
---@operator call: rizu.api.fake.FakeGameplay
local FakeGameplay = class()

local empty = {}

function FakeGameplay:isLoaded() return false end
function FakeGameplay:hasScoring() return true end
function FakeGameplay:close() end
function FakeGameplay:getState() return "play" end
function FakeGameplay:getStateProgress() return 0 end
function FakeGameplay:pause() end
function FakeGameplay:resume() end
function FakeGameplay:retry() end
function FakeGameplay:isFailStopped() return false end
function FakeGameplay:skipIntro() end
function FakeGameplay:changeScrollSpeed(steps) end
function FakeGameplay:changeLocalOffset(seconds) end
function FakeGameplay:resetLocalOffset() end
function FakeGameplay:getScrollSpeedText() return "" end
function FakeGameplay:getLocalOffset() return 0 end
function FakeGameplay:getProgress() return 0 end
function FakeGameplay:getTime() return 0 end
function FakeGameplay:getScore() end
function FakeGameplay:getAccuracy() end
function FakeGameplay:getCombo() end
function FakeGameplay:getHitCounts() return 0, 0 end
function FakeGameplay:getJudgeNames() return empty end
function FakeGameplay:getJudgeWindows() end
function FakeGameplay:getBeatPhase() end
function FakeGameplay:drawBackgroundAnimation(width, height, brightness, scale_mode) end
function FakeGameplay:getJudgementCount() return 0 end
function FakeGameplay:getJudgement(i) error("no judgements") end
function FakeGameplay:getVisibleNotes() return empty end
function FakeGameplay:getColumns() return {} end
function FakeGameplay:isColumnPressed(column) return false end
function FakeGameplay:drawPlayfield(width, height, transform) end
function FakeGameplay:drawHud(width, height, transform) end
function FakeGameplay:receive(event) end
function FakeGameplay:update(dt) end
function FakeGameplay:usesPointer() return false end
function FakeGameplay:movePointer(x, y, width, height, transform, time) end
function FakeGameplay:finish() end
function FakeGameplay:watchLocalReplay() return false, "There is no game in the preview." end
function FakeGameplay:getSkinSections() end
function FakeGameplay:getSkinProperties() end
function FakeGameplay:getHudLayers() return {} end
function FakeGameplay:getHudElementTypes() return {} end
function FakeGameplay:addHudElement(name, layer) error("There is no game in the preview.") end
function FakeGameplay:resetHudLayout() end
function FakeGameplay:saveSkinConfig() return false, "There is no game in the preview." end

return FakeGameplay
