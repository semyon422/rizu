local Input = require("rizu.gameplay.aim.Input")
local test = {}

---@param t testing.T
function test.independent_sources_and_position(t)
	local input = Input()
	local move = input:move(100, 200)
	t:eq(move.value, nil)
	t:eq(move.id, 0)
	local key = input:transform({name = "inputchanged", "keyboard", 1, "z", true})
	local mouse = input:transform({name = "mousepressed", 0, 0, 1})
	t:ne(key.id, mouse.id)
	t:tdeq(key.pos, {100, 200})
	t:eq(input:transform({name = "keypressed", "z"}), nil)
	t:eq(input:transform({name = "inputchanged", "keyboard", 1, "escape", true}), nil)
	t:eq(input:transform({name = "mousereleased", 0, 0, 1}).value, false)
end

return test
