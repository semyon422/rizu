local MainMenuV2 = require("ui.screens.main_menu_v2.MainMenuV2")
local PlayButton = require("ui.screens.main_menu_v2.PlayButton")
local Localization = require("ui.localization.Localization")
local Resources = require("ui.Resources")

local test = {}

local function setup()
	if not love.graphics.isActive() then assert(love.window.setMode(1600, 900)) end
	Resources.load()
end

---@param t testing.T
function test.enter_animates_again_after_an_exit_that_never_stepped(t)
	setup()
	local screen = MainMenuV2({localization = Localization()} --[[@as ui.UserInterface]]) ---@diagnostic disable-line: missing-fields
	screen:load()
	screen:resize(1600, 900)
	screen:enter()
	screen.root:finishTransforms()

	-- Hidden at once, as the welcome transition does: exit() starts but is never stepped.
	screen:exit()
	screen:enter()

	t:eq(screen.root.scale_x, 0.95)
	t:eq(screen.root.opacity, 0)
	screen.root:finishTransforms()
	t:eq(screen.root.scale_x, 1)
	t:eq(screen.root.opacity, 1)
end

---@param t testing.T
function test.click_releases_the_press_without_a_mouse_up(t)
	setup()
	local button = PlayButton("PLAY", function() end)
	button:onMouseDown({button = 1} --[[@as gui.MouseDownEvent]]) ---@diagnostic disable-line: missing-fields
	button:finishTransforms()
	t:eq(button.scale_x, 0.975)

	button:onMouseClick({button = 1} --[[@as gui.MouseClickEvent]]) ---@diagnostic disable-line: missing-fields
	button:finishTransforms()

	t:eq(button.scale_x, 1)
end

return test
