local MainMenuV2 = require("ui.screens.main_menu_v2.MainMenuV2")
local PlayButton = require("ui.screens.main_menu_v2.PlayButton")
local MenuButton = require("ui.screens.main_menu_v2.MenuButton")
local Localization = require("ui.localization.Localization")
local Resources = require("ui.Resources")
local Screen = require("gui.Screen")
local MenuRow = require("ui.screens.main_menu_v2.MenuRow")

local test = {}

---@return ui.screens.main_menu_v2.MainMenuV2
local function newScreen()
	local ui = {localization = Localization(), api = {
		notifications = {getTaskCount = function() return 0 end, getUnreadCount = function() return 0 end},
		media = {getBeat = function() end},
		charts = {getSelectedChart = function() end},
		online = {
			on = function() return function() end end,
			getUsername = function() return "nimue" end,
			getAvatarUrl = function() end,
			getAvatar = function() end,
			getOnlineCount = function() return 128 end,
		},
		scores = {getTotalRatings = function(_, f) f({pp = 4812, msd = 24.371}) end},
	}}
	local screen = MainMenuV2(ui --[[@as ui.UserInterface]]) ---@diagnostic disable-line: missing-fields
	screen:load()
	screen:resize(1600, 900)
	return screen
end

local function setup()
	if not love.graphics.isActive() then assert(love.window.setMode(1600, 900)) end
	Resources.load()
end

---@param t testing.T
function test.enter_animates_again_after_an_exit_that_never_stepped(t)
	setup()
	local screen = newScreen()
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
function test.top_bar_stays_at_the_right_edge_when_the_clock_changes_width(t)
	setup()
	local screen = newScreen()
	screen.clock:setText("88:88:88:88")
	screen.top_bar:fitContent()
	screen:update(0)
	screen:flush()
	local bar, content = screen.top_bar, screen.content

	t:eq(screen.clock.text, os.date("%H:%M"))
	t:eq(bar.x + bar.width, content.width - 40)
	local quit = bar.children[#bar.children]
	t:eq(quit.x + quit.width, bar.width)
end

---@param t testing.T
function test.icon_copy_pulses_with_the_beat(t)
	setup()
	local beat = 3.25 ---@type number?
	local button = PlayButton("PLAY", function() end, function() return beat end)
	button:update(0)
	t:eq(button.pulse.scale_x, 1.1)
	t:eq(button.pulse.opacity, 0.75)

	beat = nil
	button:update(0.5) -- no beat and no bpm: one pulse a second
	t:eq(button.pulse_phase, 0.75)
end

---@param t testing.T
function test.player_card_shows_the_name_and_local_msd(t)
	setup()
	local screen = newScreen()
	local card = screen.player_card
	t:eq(card.name.text, "nimue")
	t:eq(card.msd.text, "24.37")
	-- Refitted to the new MSD, so the card hugs its content.
	t:eq(card.width, card.msd_column.x + card.msd_column.width)
	screen:update(0)
	screen:draw()
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

---@param t testing.T
function test.long_labels_shrink_then_truncate(t)
	setup()
	local short_font, short = MenuButton.fit("Editor", 110)
	t:eq(short, "Editor")
	t:eq(short_font, Resources.getFont("bold", 19))

	local long = "Configuración avanzada"
	local font, text = MenuButton.fit(long, 110)
	t:assert(font:getWidth(text) <= 110, "fits")
	t:assert(text ~= long and text:sub(-3) == "…", "truncated")
	t:eq(font, Resources.getFont("bold", 14))
end

---@param t testing.T
function test.hover_reveals_a_label_inside_a_fixed_row(t)
	setup()
	local screen = Screen()
	local row = screen.root:add(MenuRow(10))
	local buttons = {} ---@type ui.screens.main_menu_v2.MenuButton[]
	for i, text in ipairs({"Multiplayer", "Editor", "DLC", "Library"}) do
		buttons[i] = row:add(MenuButton(text, Resources.sprites.icon_gear, {1, 1, 1, 1}, function() end))
	end
	row:setSize(520, MenuButton.SIZE):setAlignment(1, 1)
	screen:load()
	screen:resize(1600, 900)

	---@return number left, number right edges of the buttons, in the row
	local function edges()
		return buttons[1].x, buttons[4].x + buttons[4].width
	end
	-- Rounded edges make equal shares differ by a pixel.
	t:assert(math.abs(buttons[1].width - buttons[2].width) <= 1, "equal at rest")
	t:eq(select(2, edges()), 520)

	buttons[1].mouse_over = true
	for _ = 1, 60 do screen:update(1 / 60) end
	screen:flush()

	t:assert(math.abs(buttons[1].width - buttons[1].full_width) <= 1, "revealed to its label")
	t:assert(buttons[2].width < buttons[1].width and buttons[2].width >= MenuButton.SIZE, "others narrow")
	local left, right = edges()
	t:eq(left, 0)
	t:eq(right, 520)

	buttons[1].mouse_over = false
	for _ = 1, 60 do screen:update(1 / 60) end
	screen:flush()
	t:assert(math.abs(buttons[1].width - buttons[2].width) <= 1, "equal again")
end

return test
