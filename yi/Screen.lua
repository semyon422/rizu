local Layer = require("ui.Layer")
local SpringValue = require("ui.anim.SpringValue")

---@class yi.Screen : ui.Layer
---@operator call: yi.Screen
local Screen = Layer + {}

Screen.States = {
	Visible = 1,
	Entering = 2,
	Exiting = 3,
	Hidden = 4
}

function Screen:new()
	Layer.new(self)
	self.transition = SpringValue({value = 0})
	self.state = Screen.States.Hidden
end

function Screen:onEnter() end

function Screen:onExit() end

function Screen:enter()
	if self.state == Screen.States.Visible or self.state == Screen.States.Entering then
		return
	end
	self.state = Screen.States.Entering
	self.transition:set(1)
	self:onEnter()
end

function Screen:exit()
	if self.state == Screen.States.Hidden or self.state == Screen.States.Exiting then
		return
	end
	self.state = Screen.States.Exiting
	self.transition:set(0)
	self:onExit()
end

---@return boolean
function Screen:isVisible()
	return self.state ~= Screen.States.Hidden
end

function Screen:update(dt)
	Layer.update(self, dt)
	self.transition:update(dt)

	if self.state == Screen.States.Entering then
		if not self.transition:isAnimating() then
			self.state = Screen.States.Visible
		end
	elseif self.state == Screen.States.Exiting then
		if not self.transition:isAnimating() then
			self.state = Screen.States.Hidden
		end
	end
end

---@param key string
function Screen:handleKeyDown(key) end

function Screen:receive(event)
	if event.name == "keypressed" then
		local key = event[1] ---@type string
		self:handleKeyDown(key)
	end
end

return Screen
