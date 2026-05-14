local class = require("class")
local Changes = require("Changes")

---@class rizu.editor.EditorChanges
---@operator call: rizu.editor.EditorChanges
local EditorChanges = class()

function EditorChanges:new()
	self.changes = Changes()
	self.commands = {}
end

function EditorChanges:undo()
	for i in self.changes:undo() do
		local cmd = self.commands[i].undo
		cmd[1][cmd[2]](unpack(cmd, 3))
		print("undo i", i - 1)
	end
	self.editorModel.visualEngine:reset()
	print("undo", self.changes)
end

function EditorChanges:redo()
	for i in self.changes:redo() do
		local cmd = self.commands[i].redo
		cmd[1][cmd[2]](unpack(cmd, 3))
		print("redo i", i)
	end
	self.editorModel.visualEngine:reset()
	print("redo", self.changes)
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
	print("add i", i)
end

function EditorChanges:next()
	self.changes:next()
	print("next", self.changes)
end

return EditorChanges
