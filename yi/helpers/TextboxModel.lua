local class = require("class")
local utf8 = require("utf8")

---Returns the byte offset of a codepoint cursor position.
---Cursor 1 points before the first character; `len + 1` points after the last.
---@param text string
---@param cursor integer
---@return integer byte_offset
local function byteOffset(text, cursor)
	return utf8.offset(text, cursor) or 1
end

---Model holding UTF-8 aware text editing state for textbox views.
---The cursor is a 1-based codepoint position: `1` is before the first character
---and `getLength() + 1` is after the last character.
---@class yi.helpers.TextboxModel
---@operator call: yi.helpers.TextboxModel
---@field text string
---@field cursor integer
local TextboxModel = class()

function TextboxModel:new()
	self.text = ""
	self.cursor = 1
end

---@return string
function TextboxModel:getText()
	return self.text
end

---@return integer
function TextboxModel:getCursor()
	return self.cursor
end

---@return integer length
function TextboxModel:getLength()
	return utf8.len(self.text)
end

---Replaces the text and moves the cursor to the end.
---@param text string
function TextboxModel:setText(text)
	self.text = text
	self.cursor = utf8.len(text) + 1
end

---Moves the cursor to a codepoint position, clamped to the valid range.
---@param position integer
function TextboxModel:setCursor(position)
	self.cursor = math.min(math.max(position, 1), utf8.len(self.text) + 1)
end

---Splits the text into the part before and after the cursor.
---@return string left
---@return string right
function TextboxModel:getSplit()
	local bo = byteOffset(self.text, self.cursor)
	return self.text:sub(1, bo - 1), self.text:sub(bo)
end

---Inserts a string at the cursor position and advances the cursor.
---@param str string
---@return boolean changed
function TextboxModel:insert(str)
	if str == "" then
		return false
	end
	local bo = byteOffset(self.text, self.cursor)
	self.text = self.text:sub(1, bo - 1) .. str .. self.text:sub(bo)
	self.cursor = self.cursor + utf8.len(str)
	return true
end

---Deletes the character before the cursor (backspace behavior).
---@return boolean changed
function TextboxModel:backspace()
	if self.cursor <= 1 then
		return false
	end
	self.cursor = self.cursor - 1
	return self:delete()
end

---Deletes the character after the cursor (delete key behavior).
---@return boolean changed
function TextboxModel:delete()
	local left, right = self:getSplit()
	if right == "" then
		return false
	end
	local bo = byteOffset(right, 2)
	self.text = left .. right:sub(bo)
	return true
end

---@return boolean changed
function TextboxModel:moveLeft()
	if self.cursor <= 1 then
		return false
	end
	self.cursor = self.cursor - 1
	return true
end

---@return boolean changed
function TextboxModel:moveRight()
	if self.cursor > utf8.len(self.text) then
		return false
	end
	self.cursor = self.cursor + 1
	return true
end

---@return boolean changed
function TextboxModel:moveToStart()
	if self.cursor == 1 then
		return false
	end
	self.cursor = 1
	return true
end

---@return boolean changed
function TextboxModel:moveToEnd()
	local target = utf8.len(self.text) + 1
	if self.cursor == target then
		return false
	end
	self.cursor = target
	return true
end

---Clears all text and resets the cursor.
function TextboxModel:clear()
	self.text = ""
	self.cursor = 1
end

return TextboxModel
