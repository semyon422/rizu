local class = require("class")
local Changes = require("Changes")

---@class rizu.editor.EditorChangesContext
---@field resetVisual fun()

---@class rizu.editor.EditorChanges
---@operator call: rizu.editor.EditorChanges
---@field context rizu.editor.EditorChangesContext
local EditorChanges = class()

function EditorChanges:new()
	self.changes = Changes()
	self.commands = {}
end

---@param context rizu.editor.EditorChangesContext
function EditorChanges:setContext(context)
	self.context = context
end

---@param command table
local function run(command)
	command[1][command[2]](unpack(command, 3))
end

function EditorChanges:undo()
	for i in self.changes:undo() do
		local cmd = self.commands[i].undo
		run(cmd)
	end
	self.context:resetVisual()
end

function EditorChanges:redo()
	for i in self.changes:redo() do
		local cmd = self.commands[i].redo
		run(cmd)
	end
	self.context:resetVisual()
end

function EditorChanges:reset()
	self.changes:reset()
end

function EditorChanges:add(redo, undo)
	local i = self.changes:add()
	self.commands[i] = {
		redo = redo,
		undo = undo,
	}
end

---@param target table
---@param method string
---@param ... any
---@return table
function EditorChanges:command(target, method, ...)
	return {target, method, target, ...}
end

---@param noteStorage chartedit.Notes
---@param note chart.Note
function EditorChanges:addNoteAdd(noteStorage, note)
	self:add(
		self:command(noteStorage, "addNote", note),
		self:command(noteStorage, "removeNote", note)
	)
end

---@param noteStorage chartedit.Notes
---@param note chart.Note
function EditorChanges:addNoteRemove(noteStorage, note)
	self:add(
		self:command(noteStorage, "removeNote", note),
		self:command(noteStorage, "addNote", note)
	)
end

function EditorChanges:next()
	self.changes:next()
end

return EditorChanges
