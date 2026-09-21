local class = require("class")
local Spinner = require("rizu.gameplay.aim.Spinner")
local CircleRenderer = require("rizu.gameplay.views.aim.CircleRenderer")
local SliderRenderer = require("rizu.gameplay.views.aim.SliderRenderer")
local SpinnerRenderer = require("rizu.gameplay.views.aim.SpinnerRenderer")

---@class rizu.gameplay.views.AimPlayfield
---@operator call: rizu.gameplay.views.AimPlayfield
local AimPlayfield = class()

---@param game sphere.GameController
function AimPlayfield:new(game)
	self.game = game
end

---@param width number
---@param height number
---@return number scale
---@return number x
---@return number y
function AimPlayfield:getField(width, height)
	local scale = math.max(0.001, math.min(width / 640, height / 480))
	return scale, (width - 512 * scale) / 2, (height - 384 * scale) / 2
end

---@param x number Window x coordinate in drawable pixels
---@param y number Window y coordinate in drawable pixels
---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
---@return number
---@return number
function AimPlayfield:toChart(x, y, width, height, transform)
	x, y = transform:inverseTransformPoint(x, y)
	local scale, ox, oy = self:getField(width, height)
	return (x - ox) / scale, (y - oy) / scale
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function AimPlayfield:draw(width, height, transform)
	local re = self.game.rhythm_engine
	local rules = re and re.aim_rules
	if not rules then return end
	local scale, ox, oy = self:getField(width, height)
	local time = re.visual_info.time
	love.graphics.push("all")
	love.graphics.applyTransform(transform)
	love.graphics.setColor(0.04, 0.05, 0.08, 0.95)
	love.graphics.rectangle("fill", 0, 0, width, height)
	love.graphics.translate(ox, oy)
	love.graphics.scale(scale)
	-- Use the active Love font; gameplay rendering must not depend on UI resources.
	love.graphics.setLineWidth(2)
	local objects = rules.objects
	local last_visible = 0
	for i, object in ipairs(objects) do
		if object.time - time > rules.preempt then break end
		last_visible = i
	end
	-- Earlier heads must remain on top of later members of a stack.
	for i = last_visible, 1, -1 do
		local object = objects[i]
		local spinner = rules.spinners[i]
		if spinner and not rules.states[i] then
			SpinnerRenderer.draw(spinner, time)
		end
		local slider = rules.sliders[i]
		if slider and not rules.states[i] then
			SliderRenderer.draw(object, slider, rules.radius, time, rules.preempt)
		end
		if not spinner and not rules.heads[i] then
			CircleRenderer.draw(object, rules.radius, time, rules.preempt)
		end
	end
	for i = #rules.events, math.max(1, #rules.events - 20), -1 do
		local event = rules.events[i]
		local age = re.logic_info.time - event.time
		if age > 0.4 then break end
		local object = objects[event.index]
		local x, y = object.x, object.y
		if object.kind == "spinner" then x, y = Spinner.center_x, Spinner.center_y end
		if event.hit then love.graphics.setColor(0.3, 1, 0.5, 1 - age / 0.4)
		else love.graphics.setColor(1, 0.3, 0.3, 1 - age / 0.4) end
	end
	love.graphics.setColor(1, 0.85, 0.2)
	love.graphics.circle("line", rules.x, rules.y, 9)
	love.graphics.circle("fill", rules.x, rules.y, 3)
	love.graphics.pop()
end

return AimPlayfield
