local Layer = require("ui.Layer")
local SpringValue = require("ui.anim.SpringValue")

---@class yi.Layer : ui.Layer
---@operator call: yi.Layer
local YiLayer = Layer + {}

YiLayer.States = {
	Visible = 1,
	Entering = 2,
	Exiting = 3,
	Hidden = 4
}

function YiLayer:new()
	Layer.new(self)
	self.transition = SpringValue({value = 0})
	self.state = YiLayer.States.Hidden
end

function YiLayer:onEnter() end

function YiLayer:onExit() end

function YiLayer:enter()
	if self.state == YiLayer.States.Visible or self.state == YiLayer.States.Entering then
		return
	end
	self.state = YiLayer.States.Entering
	self.transition:set(1)
	self:onEnter()
end

function YiLayer:exit()
	if self.state == YiLayer.States.Hidden or self.state == YiLayer.States.Exiting then
		return
	end
	self.state = YiLayer.States.Exiting
	self.transition:set(0)
	self:onExit()
end

---@return boolean
function YiLayer:isVisible()
	return self.state ~= YiLayer.States.Hidden
end

---@return boolean
function YiLayer:isTakingInputs()
	return self.state == YiLayer.States.Entering or self.state == YiLayer.States.Visible
end

function YiLayer:update(dt)
	Layer.update(self, dt)
	self.transition:update(dt)

	if self.state == YiLayer.States.Entering then
		if not self.transition:isAnimating() then
			self.state = YiLayer.States.Visible
		end
	elseif self.state == YiLayer.States.Exiting then
		if not self.transition:isAnimating() then
			self.state = YiLayer.States.Hidden
		end
	end
end

---@param key string
function YiLayer:handleKeyDown(key) end

function YiLayer:receive(event)
	if event.name == "keypressed" then
		local key = event[1] ---@type string
		self:handleKeyDown(key)
	end
end

return YiLayer
