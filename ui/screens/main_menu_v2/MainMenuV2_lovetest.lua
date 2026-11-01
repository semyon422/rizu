local MainMenuV2 = require("ui.screens.main_menu_v2.MainMenuV2")
local PlayButton = require("ui.screens.main_menu_v2.PlayButton")
local MenuButton = require("ui.screens.main_menu_v2.MenuButton")
local Localization = require("ui.localization.Localization")
local Resources = require("ui.Resources")
local FakeGameApi = require("rizu.api.fake.FakeGameApi")

local test = {}

---@param online {[string]: function}? Overrides for the fake online api
---@return ui.screens.main_menu_v2.MainMenuV2
local function newScreen(online)
	local api = FakeGameApi()
	api.scores.session_start = os.time() - 3725
	for k, v in pairs(online or {}) do api.online[k] = v end
	local ui = {localization = Localization(), api = api}
	local screen = MainMenuV2(ui --[[@as ui.UserInterface]]) ---@diagnostic disable-line: missing-fields
	screen:load()
	screen:resize(1600, 900)
	screen:enter() -- as setScreen() does
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
	t:eq(card.name.text, "Player")
	t:eq(card.msd.text, "25.30")
	-- Refitted to the new MSD, so the card hugs its content.
	t:eq(card.width, card.msd_column.x + card.msd_column.width)
	screen:update(0)
	screen:draw()
end

---@param t testing.T
function test.player_card_offers_login_until_logged_in(t)
	setup()
	local logged_in = false
	local listeners = {} ---@type fun()[]
	local function on_account_changed() for _, f in ipairs(listeners) do f() end end
	local screen = newScreen({
		isLoggedIn = function() return logged_in end,
		getUsername = function() return logged_in and "nimue" or nil end,
		on = function(_, event, f)
			if event == "account_changed" then listeners[#listeners + 1] = f end
			return function() end
		end,
	})
	local card = screen.player_card
	t:eq(card.children[1], card.account)
	t:assert(not card.profile.parent, "profile hidden")
	t:eq(card.msd.text, "25.30")

	logged_in = true
	on_account_changed()
	t:eq(card.children[1], card.profile)
	t:assert(not card.account.parent, "buttons hidden")
	t:eq(card.name.text, "nimue")
	t:eq(card.width, card.msd_column.x + card.msd_column.width)
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
function test.session_panel_and_buttons_stack_above_play(t)
	setup()
	local screen = newScreen()
	screen:update(0)
	screen:flush()
	local play, buttons, panel = screen.play_button, screen.buttons, screen.session_panel
	t:eq(buttons.y + buttons.height, play.y - 20)
	t:eq(panel.y + panel.height, buttons.y - 16)
	t:eq(buttons.x + buttons.width, play.x + play.width)
	t:eq(#buttons.children, 5)

	t:eq(panel.stats.firsts, 2)
	t:eq(panel.time_text, "1:02:05")
	screen:draw()
end

---@param t testing.T
function test.online_panel_lists_players_in_the_bottom_left(t)
	setup()
	local players = {
		{name = "nimue", avatar_url = "n.png", role = "admin", chartplays_count = 1234, play_time = 3 * 3600 + 25 * 60},
		{name = "aqua", chartplays_count = 0, play_time = 0},
	}
	local on_players_changed ---@type fun()
	local screen = newScreen({
		getOnlinePlayers = function() return players end,
		on = function(_, event, f)
			if event == "online_players_changed" then on_players_changed = f end
			return function() end
		end,
	})
	screen:update(0)
	screen:flush()
	local panel, content = screen.online_panel, screen.content
	t:eq(panel.x, 40)
	t:eq(panel.y + panel.height, content.height - 40)
	t:eq(panel.title, "ONLINE: 42")
	t:eq(panel.grid:getRowCount(), 21) -- 2 real and 40 fake players
	screen.root:finishTransforms() -- past the fade-in, which starts at opacity 0
	screen:draw()
	t:eq(panel.grid.fitted[1].stats, "1234 plays · 3h 25m")

	players = {}
	for i = 1, 100 do
		players[i] = {name = ("player_with_a_very_long_name_%d"):format(i), chartplays_count = i, play_time = i}
	end
	on_players_changed()
	t:eq(panel.grid:getRowCount(), 70)
	local first, last = panel.grid:getVisibleRowRange()
	t:eq(first, 1)
	t:assert(last < 70, "only the rows on screen are drawn")
	screen:draw()
	t:assert(panel.grid.fitted[1].name:sub(-3) == "…", "long names are cut to the card")
	t:eq(panel.grid.fitted[2 * last + 1], nil)
end

---@param t testing.T
function test.entering_again_counts_plays_made_since(t)
	setup()
	local screen = newScreen()
	local scores = screen.ui.api.scores
	scores.getSessionStats = function(_, f) f({plays = 3, firsts = 2}) end
	scores.getTotalRatings = function(_, f) f({pp = 4900, msd = 24.5}) end

	-- Off to song select and gameplay, then back: the screen is not loaded again.
	screen:exit()
	screen:enter()

	t:eq(screen.session_panel.stats.plays, 3)
	t:eq(screen.player_card.msd.text, "24.50")
end

return test
