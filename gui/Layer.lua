local class = require("class")
local Composition = require("gui.composition.Composition")

---@class gui.Layer
---@operator call: gui.Layer
---@field composition? gui.Composition
---@field views gui.View[]
local Layer = class()

function Layer:new()
	self.views = {}
	self.width = 0
	self.height = 0
	self.layout_scale = 0
	self.composition = Composition()
end

---@param w number
---@param h number
function Layer:setDimensions(w, h)
	self.composition:setDimensions(w, h)
end

function Layer:load()
	self.composition:update()
	self.views = self.composition:getViews()

	for _, v in ipairs(self.views) do
		if not v._constructed then
			error("Call View.new()")
		end
		v:load()
		v:updateTransform()
	end
end

---@param dt number
function Layer:update(dt)
	for _, v in ipairs(self.views) do
		v:update(dt)
	end
end

---@param inputs gui.Inputs
function Layer:acceptInputs(inputs)
	for i = #self.views, 1, -1 do
		local v = self.views[i]
		v:acceptInputs(inputs)
	end
end

function Layer:draw()
	for _, v in ipairs(self.views) do
		if v.visible then
			love.graphics.push("all")
			love.graphics.applyTransform(v.transform)
			v:draw()
			love.graphics.pop()
		end
	end
end

---@param key string
function Layer:handleKeyDown(key) end

---@param event table
function Layer:receive(event)
	if event.name == "keypressed" then
		local key = event[1] ---@type string
		self:handleKeyDown(key)
	end
end

return Layer
