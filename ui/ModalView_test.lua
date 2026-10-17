local CompositeView = require("gui.CompositeView")
local Screen = require("gui.Screen")
local ModalView = require("ui.ModalView")

local test = {}

---@param t testing.T
function test.modal_draws_its_own_background_inside_its_composite_boundary(t)
	local screen = Screen()
	local modal = ModalView()
	function modal:draw() end
	screen.root:add(modal)
	screen:relayout()

	t:assert(CompositeView * modal)
	local commands = screen.renderer.commands
	t:tdeq({commands[2], commands[5]}, {modal, modal})
	t:eq(screen.renderer.command_count, 7)
end

return test
