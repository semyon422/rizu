local class = require("class")
local InputMode = require("chart.core.InputMode")

---@class sphere.InputView
---@operator call: sphere.InputView
local InputView = class()

function InputView:load()
	if self.pressed then
		self.pressed.hidden = true
	end
	self.count = 0

	local input_mode = self.input_mode
	if not input_mode and self.game then
		input_mode = self.game.noteSkinModel.noteSkin.inputMode
	end

	local im = InputMode(input_mode)
	self.input_map = im:getInputMap()
end

---@param event table
function InputView:receive(event)
	if not event.virtual then
		return
	end

	local key = event and event[1]

	local found
	for _, input in ipairs(self.inputs) do
		if key == input then
			found = true
			break
		end
	end
	if not found then
		return
	end

	if event.name == "keypressed" then
		self.count = self.count + 1
	elseif event.name == "keyreleased" then
		self.count = self.count - 1
	end

	self.count = math.max(self.count, 0)  -- first event can be release
	if self.count > 0 then
		self:switchPressed(true)
	else
		self:switchPressed(false)
	end
end

function InputView:draw()
	local re = self.game and self.game.rhythm_engine
	if not re or not self.column then
		return
	end

	local pressed = false
	for _, input in ipairs(self.inputs) do
		local col = self.input_map[input]
		if col and re:isColumnPressed(col) then
			pressed = true
			break
		end
	end
	self:switchPressed(pressed)
end

---@param value boolean
function InputView:switchPressed(value)
	if self.pressed then
		self.pressed.hidden = not value
	end
	if self.released then
		self.released.hidden = value
	end
end

return InputView
