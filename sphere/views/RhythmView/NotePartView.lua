local class = require("class")

---@class sphere.NotePartView
---@operator call: sphere.NotePartView
local NotePartView = class()

---@return {dt: number}
function NotePartView:getTimeState()
	return self.noteView:getStartTimeState()
end

---@param key string
---@param timeState table?
---@return any?
function NotePartView:get(key, timeState)
	local noteSkin = self.noteView.noteSkin
	return noteSkin:get(self.noteView, self.name, key, timeState or self:getTimeState())
end

---@param key string?
---@param timeState table?
---@return love.SpriteBatch?
function NotePartView:getSpriteBatch(key, timeState)
	return self.noteView.noteSkin.data:getSpriteBatch(self.noteView, self.name, key or "image", timeState or self:getTimeState())
end

---@param key string?
---@param timeState table?
---@return love.Quad?
function NotePartView:getQuad(key, timeState)
	return self.noteView.noteSkin.data:getQuad(self.noteView, self.name, key or "image", timeState or self:getTimeState())
end

---@param key string?
---@param timeState table?
---@return number
---@return number
function NotePartView:getDimensions(key, timeState)
	return self.noteView.noteSkin.data:getDimensions(self.noteView, self.name, key or "image", timeState or self:getTimeState())
end

---@return table
function NotePartView:getColor()
	local noteSkin = self.noteView.noteSkin
	local color = noteSkin:get(self.noteView, self.name, "color", self:getTimeState())
	local imageName, frame = noteSkin:get(self.noteView, self.name, "image", self:getTimeState())
	local image = noteSkin.images[imageName]
	if not image then
		return color
	end
	if not image.color then
		return color
	end
	return noteSkin:multiplyColors(color, image.color)
end

return NotePartView
