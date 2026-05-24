local class = require("class")
local EventsRenderer = require("sphere.models.RhythmModel.GraphicEngine.EventsRenderer")
local ColumnsRenderer = require("sphere.models.RhythmModel.GraphicEngine.ColumnsRenderer")
local flux = require("flux")

---@class sphere.GraphicEngine
---@operator call: sphere.GraphicEngine
local GraphicEngine = class()

GraphicEngine.visualOffset = 0
GraphicEngine.longNoteShortening = 0
GraphicEngine.scaleSpeed = false
GraphicEngine.constant = false
GraphicEngine.eventBasedRender = false
GraphicEngine.range = {-1, 1}

---@param visualTimeInfo sphere.VisualTimeInfo
---@param logicEngine sphere.LogicEngine?
function GraphicEngine:new(visualTimeInfo, logicEngine)
	self.visualTimeInfo = visualTimeInfo
	self.logicEngine = logicEngine
end

---@param chart chart.Chart
function GraphicEngine:setChart(chart)
	self.chart = chart
end

function GraphicEngine:load()
	if self.eventBasedRender then
		self.renderer = EventsRenderer(self.chart, self)
	else
		self.renderer = ColumnsRenderer(self.chart, self)
	end
	self.renderer:load()
end

function GraphicEngine:unload()
	self.renderer = nil
end

function GraphicEngine:update()
	if self.renderer then
		self.renderer:update()
	end
end

---@generic T
---@param f fun(obj: T, note: sphere.GraphicalNote)
---@param obj T
function GraphicEngine:iterNotes(f, obj)
	if self.renderer then
		self.renderer:iterNotes(f, obj)
	end
end

function GraphicEngine:setVisualTimeRate(visualTimeRate)
	if math.abs(visualTimeRate) <= 0.001 then
		visualTimeRate = 0
	end
	self.targetVisualTimeRate = visualTimeRate
	if self.tween then
		self.tween:stop()
	end
	if visualTimeRate * self.visualTimeRate < 0 then
		self.visualTimeRate = visualTimeRate
	else
		self.tween = flux.to(self, 0.25, {visualTimeRate = visualTimeRate}):ease("quadinout")
	end
end

---@return number
function GraphicEngine:getVisualTimeRate()
	local timeRate = self.visualTimeInfo.rate
	local visualTimeRate = self.visualTimeRate
	if not self.scaleSpeed then
		visualTimeRate = visualTimeRate / timeRate
	end
	return visualTimeRate
end

---@return number
function GraphicEngine:getCurrentTime()
	return self.visualTimeInfo.time
end

---@return number
function GraphicEngine:getInputOffset()
	local logicEngine = self.logicEngine
	return logicEngine and logicEngine.inputOffset or 0
end

---@param note chart.Note
---@return sphere.LogicalNote?
function GraphicEngine:getLogicalNote(note)
	local logicEngine = self.logicEngine
	return logicEngine and logicEngine:getLogicalNote(note)
end

---@return number
function GraphicEngine:getVisualOffset()
	return self.visualOffset
end

return GraphicEngine
