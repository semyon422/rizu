local class = require("class")
local math_util = require("math_util")
local VisualInterpolator = require("ncdk2.visual.VisualInterpolator")
local FullEventScroller = require("ncdk2.visual.FullEventScroller")
local Point = require("ncdk2.tp.Point")
local VisualPoint = require("ncdk2.visual.VisualPoint")

---@class ncdk2.Visual
---@operator call: ncdk2.Visual
---@field points ncdk2.VisualPoint[]
---@field points_map {[ncdk2.VisualPoint]: true}
---@field p2vp {[ncdk2.Point]: ncdk2.VisualPoint}
local Visual = class()

function Visual:new()
	self.interpolator = VisualInterpolator()
	self.points = {}
	self.points_map = {}
	self.p2vp = {}
end

---@type number
Visual.primaryTempo = 0

---@type "none"|"current"|"local"|"global"
Visual.tempoMultiplyTarget = "current"

---@param point ncdk2.Point
---@return ncdk2.VisualPoint
function Visual:getPoint(point)
	local p2vp = self.p2vp
	local vp = p2vp[point]
	if vp then
		return vp
	end
	return self:newPoint(point)
end

---@param point ncdk2.Point
---@return ncdk2.VisualPoint
function Visual:newPoint(point)
	local vp = VisualPoint(point)
	self.p2vp[point] = vp
	table.insert(self.points, vp)
	vp.compare_index = #self.points
	self.points_map[vp] = true
	return vp
end

---@return ncdk2.Velocity?
function Visual:getFirstVelocity()
	for _, vp in ipairs(self.points) do
		if vp._velocity then
			return vp._velocity
		end
	end
end

function Visual:sort()
	table.sort(self.points)
	for i, vp in ipairs(self.points) do
		vp.compare_index = i
	end
end

function Visual:compute()
	local points = self.points
	if #points == 0 then
		return
	end

	self:sort()

	---@type {[ncdk2.Point]: integer}
	local point_index = {}
	for i, vp in ipairs(points) do
		if not point_index[vp.point] then
			point_index[vp.point] = i
		end
	end
	self.point_index = point_index

	local velocity = self:getFirstVelocity()

	---@type {[number]: number}
	local section_time = {}
	local section = 0

	local _tempo = self.primaryTempo  -- ok for first point

	local visualTime = 0
	local monotonicVisualTime = 0
	local absoluteTime = points[1].point.absoluteTime
	for _, visualPoint in ipairs(points) do
		---@type ncdk2.Point|ncdk2.AbsolutePoint|ncdk2.MeasurePoint|ncdk2.IntervalPoint
		local point = visualPoint.point

		local _currentSpeed = self:multiply(velocity, _tempo)

		local vertex = point.vertex
		local tempo = point.tempo
		if tempo then
			_tempo = tempo.tempo
		end
		if point._stop then
			_tempo = 0
		end

		local _absoluteTime = point.absoluteTime

		local visualDeltaTime = (_absoluteTime - absoluteTime) * _currentSpeed
		visualTime = visualTime + visualDeltaTime
		monotonicVisualTime = monotonicVisualTime + math.abs(visualDeltaTime)

		absoluteTime = _absoluteTime

		local _velocity = visualPoint._velocity
		if _velocity then
			velocity = _velocity
		end
		visualPoint:setSpeeds(self:multiply(velocity, _tempo))

		visualPoint.visualTime = visualTime
		visualPoint.monotonicVisualTime = monotonicVisualTime
		visualPoint.section = section

		local expand = visualPoint._expand
		if expand then
			local duration = expand.duration
			if tempo then
				duration = duration * tempo:getBeatDuration()
			elseif vertex then
				duration = duration * vertex:getBeatDuration()
			end
			if math.abs(duration) == math.huge then
				section_time[section] = visualTime
				section = section + math_util.sign(duration)
				visualTime = section_time[section] or visualTime
			else
				visualTime = visualTime + duration
			end
		end
	end

	local zero_vp = VisualPoint(Point(0))
	self.interpolator:interpolate(points, zero_vp, "absolute")

	for _, vp in ipairs(points) do
		vp.visualTime = vp.visualTime - zero_vp.visualTime
		vp.monotonicVisualTime = vp.monotonicVisualTime - zero_vp.monotonicVisualTime
	end
end

---@param velocity ncdk2.Velocity?
---@param tempo number
---@return number
---@return number
---@return number
function Visual:multiply(velocity, tempo)
	local currentSpeed, localSpeed, globalSpeed = 1, 1, 1
	if velocity then
		currentSpeed = velocity.currentSpeed
		localSpeed = velocity.localSpeed
		globalSpeed = velocity.globalSpeed
	end

	if self.primaryTempo == 0 then
		return currentSpeed, localSpeed, globalSpeed
	end

	local tempoMultiplier = tempo / self.primaryTempo

	local target = self.tempoMultiplyTarget
	if target == "current" then
		currentSpeed = currentSpeed * tempoMultiplier
	elseif target == "local" then
		localSpeed = localSpeed * tempoMultiplier
	elseif target == "global" then
		globalSpeed = globalSpeed * tempoMultiplier
	end

	return currentSpeed, localSpeed, globalSpeed
end

function Visual:isForwardOnly()
	for _, vp in ipairs(self.points) do
		if vp.currentSpeed < 0 then
			return false
		end
	end
	return true
end

local MonotonicEventScroller = require("ncdk2.visual.MonotonicEventScroller")

---@param lazy boolean?
function Visual:generateEvents(lazy)
	if self:isForwardOnly() then
		local scroller = MonotonicEventScroller(self)
		self.scroller = scroller
	else
		local fes = FullEventScroller()
		fes:generate(self.points, lazy)
		self.scroller = fes
	end
end

return Visual
