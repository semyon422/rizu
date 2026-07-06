local TextboxModel = require("yi.helpers.TextboxModel")

local test = {}

---@param t testing.T
function test.new_starts_empty(t)
	local m = TextboxModel()
	t:eq(m:getText(), "")
	t:eq(m:getCursor(), 1)
	t:eq(m:getLength(), 0)
end

---@param t testing.T
function test.insert_appends_at_end(t)
	local m = TextboxModel()
	t:eq(m:insert("hello"), true)
	t:eq(m:getText(), "hello")
	t:eq(m:getCursor(), 6)
	t:eq(m:getLength(), 5)
end

---@param t testing.T
function test.insert_empty_string_is_noop(t)
	local m = TextboxModel()
	m:insert("ab")
	t:eq(m:insert(""), false)
	t:eq(m:getText(), "ab")
	t:eq(m:getCursor(), 3)
end

---@param t testing.T
function test.insert_multi_char_string_advances_cursor(t)
	local m = TextboxModel()
	m:insert("ab")
	m:moveToStart()
	t:eq(m:insert("XYZ"), true)
	t:eq(m:getText(), "XYZab")
	t:eq(m:getCursor(), 4)
end

---@param t testing.T
function test.insert_handles_multibyte_chars(t)
	local m = TextboxModel()
	m:insert("héllo")
	t:eq(m:getText(), "héllo")
	t:eq(m:getLength(), 5)
	t:eq(m:getCursor(), 6)
end

---@param t testing.T
function test.backspace_removes_char_before_cursor(t)
	local m = TextboxModel()
	m:insert("abc")
	t:eq(m:backspace(), true)
	t:eq(m:getText(), "ab")
	t:eq(m:getCursor(), 3)
end

---@param t testing.T
function test.backspace_at_start_is_noop(t)
	local m = TextboxModel()
	m:insert("abc")
	m:moveToStart()
	t:eq(m:backspace(), false)
	t:eq(m:getText(), "abc")
	t:eq(m:getCursor(), 1)
end

---@param t testing.T
function test.backspace_removes_full_multibyte_char(t)
	local m = TextboxModel()
	m:insert("café")
	m:moveToEnd()
	t:eq(m:backspace(), true)
	t:eq(m:getText(), "caf")
	t:eq(#m:getText(), 3)
end

---@param t testing.T
function test.delete_removes_char_after_cursor(t)
	local m = TextboxModel()
	m:insert("abc")
	m:moveToStart()
	t:eq(m:delete(), true)
	t:eq(m:getText(), "bc")
	t:eq(m:getCursor(), 1)
end

---@param t testing.T
function test.delete_at_end_is_noop(t)
	local m = TextboxModel()
	m:insert("abc")
	t:eq(m:delete(), false)
	t:eq(m:getText(), "abc")
	t:eq(m:getCursor(), 4)
end

---@param t testing.T
function test.delete_removes_full_multibyte_char(t)
	local m = TextboxModel()
	m:insert("éxc")
	m:moveToStart()
	t:eq(m:delete(), true)
	t:eq(m:getText(), "xc")
	t:eq(#m:getText(), 2)
end

---@param t testing.T
function test.move_left_right(t)
	local m = TextboxModel()
	m:insert("abc")
	t:eq(m:moveLeft(), true)
	t:eq(m:getCursor(), 3)
	t:eq(m:moveLeft(), true)
	t:eq(m:moveLeft(), true)
	t:eq(m:getCursor(), 1)
	t:eq(m:moveLeft(), false)
	t:eq(m:getCursor(), 1)
	t:eq(m:moveRight(), true)
	t:eq(m:getCursor(), 2)
end

---@param t testing.T
function test.move_right_at_end_is_noop(t)
	local m = TextboxModel()
	m:insert("a")
	t:eq(m:moveRight(), false)
	t:eq(m:getCursor(), 2)
end

---@param t testing.T
function test.move_to_start_and_end(t)
	local m = TextboxModel()
	m:insert("abc")
	t:eq(m:moveToStart(), true)
	t:eq(m:getCursor(), 1)
	t:eq(m:moveToStart(), false)
	t:eq(m:moveToEnd(), true)
	t:eq(m:getCursor(), 4)
	t:eq(m:moveToEnd(), false)
end

---@param t testing.T
function test.move_traverses_codepoints_not_bytes(t)
	local m = TextboxModel()
	m:insert("日本語")
	t:eq(m:getLength(), 3)
	m:moveToStart()
	t:eq(m:moveRight(), true)
	t:eq(m:getCursor(), 2)
	t:eq(m:moveRight(), true)
	t:eq(m:getCursor(), 3)
	t:eq(m:moveRight(), true)
	t:eq(m:getCursor(), 4)
	t:eq(m:moveRight(), false)
end

---@param t testing.T
function test.set_cursor_clamps_to_valid_range(t)
	local m = TextboxModel()
	m:insert("abc")
	m:setCursor(0)
	t:eq(m:getCursor(), 1)
	m:setCursor(100)
	t:eq(m:getCursor(), 4)
	m:setCursor(2)
	t:eq(m:getCursor(), 2)
end

---@param t testing.T
function test.set_text_replaces_and_moves_cursor_to_end(t)
	local m = TextboxModel()
	m:insert("old")
	m:setText("new")
	t:eq(m:getText(), "new")
	t:eq(m:getCursor(), 4)
end

---@param t testing.T
function test.clear_resets_state(t)
	local m = TextboxModel()
	m:insert("abc")
	m:clear()
	t:eq(m:getText(), "")
	t:eq(m:getCursor(), 1)
	t:eq(m:getLength(), 0)
end

---@param t testing.T
function test.get_split_returns_parts_around_cursor(t)
	local m = TextboxModel()
	m:insert("abcdef")
	m:setCursor(3)
	local left, right = m:getSplit()
	t:eq(left, "ab")
	t:eq(right, "cdef")
end

---@param t testing.T
function test.get_split_at_boundaries(t)
	local m = TextboxModel()
	m:insert("ab")
	m:moveToStart()
	local l1, r1 = m:getSplit()
	t:eq(l1, "")
	t:eq(r1, "ab")
	m:moveToEnd()
	local l2, r2 = m:getSplit()
	t:eq(l2, "ab")
	t:eq(r2, "")
end

---@param t testing.T
function test.get_split_with_multibyte(t)
	local m = TextboxModel()
	m:insert("héllo")
	m:setCursor(2)
	local left, right = m:getSplit()
	t:eq(left, "h")
	t:eq(right, "éllo")
end

---@param t testing.T
function test.typing_then_backspace_full_flow(t)
	local m = TextboxModel()
	for _, ch in ipairs({ "H", "e", "l", "l", "o" }) do
		m:insert(ch)
	end
	t:eq(m:getText(), "Hello")
	m:moveToStart()
	m:moveRight()
	m:moveRight()
	m:insert("XX")
	t:eq(m:getText(), "HeXXllo")
	t:eq(m:getCursor(), 5)
	m:backspace()
	t:eq(m:getText(), "HeXllo")
	m:moveToEnd()
	m:backspace()
	t:eq(m:getText(), "HeXll")
end

return test
