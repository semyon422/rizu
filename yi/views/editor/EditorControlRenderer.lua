local class = require("class")
local EditorControls = require("yi.views.editor.EditorControls")

---@class yi.views.editor.EditorControlRenderer
---@operator call: yi.views.editor.EditorControlRenderer
local EditorControlRenderer = class()

---@param active boolean
---@param hovered boolean
function EditorControlRenderer:setButtonColor(active, hovered)
	if active then
		love.graphics.setColor(0.5, 0.65, 1, 0.9)
	elseif hovered then
		love.graphics.setColor(0.35, 0.42, 0.55, 0.95)
	else
		love.graphics.setColor(0.18, 0.2, 0.24, 0.95)
	end
end

---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@param align string?
function EditorControlRenderer:label(text, x, y, w, h, align)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(text, x, y + math.max((h - love.graphics.getFont():getHeight()) / 2, 0), w, align or "left")
end

---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@param active boolean
---@param hovered boolean
function EditorControlRenderer:button(text, x, y, w, h, active, hovered)
	self:setButtonColor(active, hovered)
	love.graphics.rectangle("fill", x, y, w, h, 4, 4)
	self:label(text, x, y, w, h, "center")
end

---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@param active boolean
---@param hovered boolean
---@param normalized number
function EditorControlRenderer:slider(text, x, y, w, h, active, hovered, normalized)
	self:setButtonColor(active, hovered)
	love.graphics.rectangle("fill", x, y, w, h, 4, 4)
	love.graphics.setColor(0.7, 0.78, 1, 0.9)
	love.graphics.rectangle("fill", x, y, w * EditorControls.clamp01(normalized), h, 4, 4)
	self:label(text, x, y, w, h, "center")
end

---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@param focused boolean
---@param hovered boolean
function EditorControlRenderer:input(text, x, y, w, h, focused, hovered)
	self:setButtonColor(focused, hovered)
	love.graphics.rectangle("fill", x, y, w, h, 4, 4)
	self:label(text, x + 8, y, w - 16, h)
end

---@param x number
---@param y number
---@param w number
function EditorControlRenderer:separator(x, y, w)
	love.graphics.setColor(1, 1, 1, 0.25)
	love.graphics.line(x, y, x + w, y)
end

---@param x number
---@param y number
---@param w number
---@param h number
function EditorControlRenderer:panelBackground(x, y, w, h)
	love.graphics.setColor(0, 0, 0, 0.35)
	love.graphics.rectangle("fill", x, y, w, h)
end

return EditorControlRenderer
