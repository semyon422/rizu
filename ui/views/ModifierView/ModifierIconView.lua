local class = require("class")
local spherefonts = require("sphere.assets.fonts")

---@class sphere.ModifierIconView
---@operator call: sphere.ModifierIconView
local ModifierIconView = class()

local shapes = {
	empty = {false, false, false, false, false, false, false, false},
	full = {true, true, true, true, 0.25, 0.25, 0.25, 0.25},
	topBottom = {false, true, true, false, 0.25, 0.25, 0.25, 0.25},
	bottomArcs = {false, false, false, false, nil, nil, 0.25, 0.25},
	fillCircle = {false, false, false, false, 0.5, 0.5, 0.5, 0.5},
	circleBottomRight = {false, true, false, true, 0.5, 0.5, 0.5, 0.15},
	circleTopRight = {false, false, true, true, 0.5, 0.15, 0.5, 0.5},
	allArcs = {false, false, false, false, 0.15, 0.15, 0.15, 0.15},
}

local mod_lines = {
	{10 / 64},
	{-6 / 64, 24 / 64},
}

---@param size number
---@param shape string?
---@param str string?
---@param substr string?
function ModifierIconView:draw(size, shape, str, substr)
	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.setLineStyle("smooth")
	love.graphics.setLineWidth(size / 40)

	self:drawSquareBorder(size, shapes[shape] or shapes.allArcs)
	local lines = mod_lines[substr and 2 or 1] or mod_lines[1]
	self:drawText(lines, size, str, substr)
end

---@param lines table
---@param size number
---@param ... string?
function ModifierIconView:drawText(lines, size, ...)
	local fx = size / 8
	local fy = size / 8
	local fs = size * 3 / 4

	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 32))

	for i = 1, #lines do
		love.graphics.printf(select(i, ...), fx, fy + lines[i] * fs, 64, "center", 0, fs / 64, fs / 64)
	end
end

---@param size number
---@param shape table
function ModifierIconView:drawSquareBorder(size, shape)
	local fx = size / 8
	local fy = size / 8
	local fs = size * 3 / 4
	local fr = fs / 4

	local fr1 = shape[5] and fs * shape[5] or fr
	local fr2 = shape[6] and fs * shape[6] or fr
	local fr3 = shape[7] and fs * shape[7] or fr
	local fr4 = shape[8] and fs * shape[8] or fr

	if shape[1] then
		love.graphics.line(fx, fy + fr1, fx, fy + fs - fr3)
	end
	if shape[2] then
		love.graphics.line(fx + fr3, fy + fs, fx + fs - fr4, fy + fs)
	end
	if shape[3] then
		love.graphics.line(fx + fr1, fy, fx + fs - fr2, fy)
	end
	if shape[4] then
		love.graphics.line(fx + fs, fy + fr2, fx + fs, fy + fs - fr4)
	end

	if shape[5] then
		love.graphics.arc("line", "open", fx + fr1, fy + fr1, fr1, -math.pi, -math.pi / 2, 8)
	end
	if shape[6] then
		love.graphics.arc("line", "open", fx + fs - fr2, fy + fr2, fr2, -math.pi / 2, 0, 8)
	end
	if shape[7] then
		love.graphics.arc("line", "open", fx + fr3, fy + fs - fr3, fr3, math.pi, math.pi / 2, 8)
	end
	if shape[8] then
		love.graphics.arc("line", "open", fx + fs - fr4, fy + fs - fr4, fr4, math.pi / 2, 0, 8)
	end
end

return ModifierIconView
