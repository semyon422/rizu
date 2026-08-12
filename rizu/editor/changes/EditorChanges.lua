local class = require("class")
local Changes = require("Changes")

---@class rizu.editor.EditorChangesContext
---@field resetVisual fun()

---@class rizu.editor.EditorCommand: {[integer]: any}
---@field [1] table
---@field [2] string
---@field [3] table

---@class rizu.editor.EditorCommandPair
---@field redo rizu.editor.EditorCommand
---@field undo rizu.editor.EditorCommand

---@class rizu.editor.EditorChanges
---@operator call: rizu.editor.EditorChanges
---@field context rizu.editor.EditorChangesContext
---@field changes util.Changes
---@field commands {[integer]: rizu.editor.EditorCommandPair}
local EditorChanges = class()

function EditorChanges:new()
	self.changes = Changes()
	self.commands = {}
end

---@param context rizu.editor.EditorChangesContext
function EditorChanges:setContext(context)
	self.context = context
end

---@param command rizu.editor.EditorCommand
local function run(command)
	command[1][command[2]](unpack(command, 3))
end

function EditorChanges:undo()
	local iterator, state = self.changes:undo()
	---@cast iterator fun(changes: util.Changes, index: integer?): integer?
	for i in iterator, state do
		local cmd = self.commands[i].undo
		run(cmd)
	end
	self.context:resetVisual()
end

function EditorChanges:redo()
	local iterator, state = self.changes:redo()
	---@cast iterator fun(changes: util.Changes, index: integer?): integer?
	for i in iterator, state do
		local cmd = self.commands[i].redo
		run(cmd)
	end
	self.context:resetVisual()
end

function EditorChanges:reset()
	self.changes:reset()
end

---@param redo rizu.editor.EditorCommand
---@param undo rizu.editor.EditorCommand
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
---@return rizu.editor.EditorCommand
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
