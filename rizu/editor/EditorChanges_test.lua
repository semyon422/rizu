local EditorChanges = require("rizu.editor.EditorChanges")

local test = {}

local Target = {}

function Target:set(value)
	self.value = value
end

---@param t testing.T
function test.undo_redo_group(t)
	local target = {value = 0}
	setmetatable(target, {__index = Target})

	local resetCount = 0
	local changes = EditorChanges()
	changes.editorModel = {
		visualEngine = {
			reset = function()
				resetCount = resetCount + 1
			end,
		},
	}

	changes:reset()
	target:set(1)
	changes:add(
		{target, "set", target, 1},
		{target, "set", target, 0}
	)
	target:set(2)
	changes:add(
		{target, "set", target, 2},
		{target, "set", target, 1}
	)
	changes:next()

	changes:undo()
	t:eq(target.value, 0)
	t:eq(resetCount, 1)

	changes:redo()
	t:eq(target.value, 2)
	t:eq(resetCount, 2)
end

---@param t testing.T
function test.command_helper(t)
	local target = {value = 0}
	setmetatable(target, {__index = Target})

	local changes = EditorChanges()
	changes.editorModel = {
		visualEngine = {
			reset = function() end,
		},
	}

	target:set(3)
	changes:add(
		changes:command(target, "set", 3),
		changes:command(target, "set", 0)
	)
	changes:next()
	target:set(7)

	changes:undo()
	t:eq(target.value, 0)

	changes:redo()
	t:eq(target.value, 3)
end

return test
