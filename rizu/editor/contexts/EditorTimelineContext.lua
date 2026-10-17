local class = require("class")

---@class rizu.editor.EditorTimelineContext: rizu.editor.EditorPlaybackContext, rizu.editor.ScrollerContext, rizu.editor.MetronomeContext
---@operator call: rizu.editor.EditorTimelineContext
---@field model rizu.editor.EditorModel
local EditorTimelineContext = class()

---@param model rizu.editor.EditorModel
function EditorTimelineContext:new(model)
	self.model = model
end

---@return rizu.editor.TimeManager
function EditorTimelineContext:getTimer()
	return self.model.timer
end

---@return rizu.engine.audio.Engine
function EditorTimelineContext:getAudioEngine()
	return self.model.audio_engine
end

---@return chart.Chart
function EditorTimelineContext:getChart()
	return self.model.chart
end

---@return rizu.editor.IntervalManager
function EditorTimelineContext:getIntervalManager()
	return self.model.intervalManager
end

---@param absoluteTime number
---@return chartedit.Point?
function EditorTimelineContext:getDtpAbsolute(absoluteTime)
	return self.model:getDtpAbsolute(absoluteTime)
end

---@return number
function EditorTimelineContext:getSessionTime()
	return self.model:getSessionTime()
end

---@return chartedit.Point
function EditorTimelineContext:getPoint()
	return self.model:getPoint()
end

---@param point chartedit.Point
function EditorTimelineContext:setSessionPoint(point)
	self.model:setSessionPoint(point)
end

---@param time number
function EditorTimelineContext:setTime(time)
	self.model:setTime(time)
end

---@return boolean
function EditorTimelineContext:isIntervalGrabbed()
	return self.model.intervalManager:isGrabbed()
end

---@param vertex chartedit.Vertex
---@param time chart.Fraction
---@return chartedit.Point
function EditorTimelineContext:interpolateFraction(vertex, time)
	return self.model.layer.points:interpolateFraction(vertex, time)
end

---@return table
function EditorTimelineContext:getSettings()
	return self.model:getSettings()
end

---@param point chartedit.Point
---@param delta number
---@return chartedit.Vertex
---@return chart.Fraction
function EditorTimelineContext:getNextSnapIntervalTime(point, delta)
	return self.model.scroller:getNextSnapIntervalTime(point, delta)
end

---@return number
function EditorTimelineContext:getCurrentTime()
	return self.model.timer:getTime()
end

return EditorTimelineContext
