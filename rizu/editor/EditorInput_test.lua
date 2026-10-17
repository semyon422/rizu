local EditorInput = require("rizu.editor.EditorInput")

local test = {}

local function withKeyboard(downKeys, f)
	local oldLove = love
	love = {
		keyboard = {
			isDown = function(key)
				return downKeys[key] == true
			end,
		},
	}
	local ok, err = xpcall(f, debug.traceback)
	love = oldLove
	if not ok then
		error(err)
	end
end

---@param t testing.T
function test.modifiers_accept_left_and_right_keys(t)
	withKeyboard({
		rshift = true,
		rctrl = true,
		ralt = true,
	}, function()
		local input = EditorInput()

		t:eq(input:isSnapChangeRequested(), true)
		t:eq(input:isModifierApplyRequested(), true)
		t:eq(input:isMultiSelectRequested(), true)
		t:eq(input:isEditorCommandRequested(), true)
		t:eq(input:isSpeedChangeRequested(), true)
		t:eq(input:isFineScrollRequested(), true)
	end)
end

---@param t testing.T
function test.modifiers_return_false_when_not_pressed(t)
	withKeyboard({}, function()
		local input = EditorInput()

		t:eq(input:isSnapChangeRequested(), false)
		t:eq(input:isModifierApplyRequested(), false)
		t:eq(input:isMultiSelectRequested(), false)
		t:eq(input:isEditorCommandRequested(), false)
		t:eq(input:isSpeedChangeRequested(), false)
		t:eq(input:isFineScrollRequested(), false)
	end)
end

return test
