local MainMenuV2 = require("ui.screens.main_menu_v2.MainMenuV2")
local PlayButton = require("ui.screens.main_menu_v2.PlayButton")
local MenuButton = require("ui.screens.main_menu_v2.MenuButton")
local Localization = require("ui.localization.Localization")
local Resources = require("ui.Resources")
local FakeGameApi = require("rizu.api.fake.FakeGameApi")
local PopupContainer = require("ui.views.PopupContainer")
local BackgroundLayers = require("ui.screens.main_menu_v2.BackgroundLayers")
local LayerRow = require("ui.screens.main_menu_v2.LayerRow")
local FakeFilesystem = require("fs.FakeFilesystem")
local UiConfig = require("ui.UiConfig")

local test = {}

---@param online {[string]: function}? Overrides for the fake online api
---@return ui.screens.main_menu_v2.MainMenuV2
local function newScreen(online)
	local api = FakeGameApi()
	api.scores.session_start = os.time() - 3725
	for k, v in pairs(online or {}) do api.online[k] = v end
	local popup_container = PopupContainer()
	local ui = {localization = Localization(), api = api, overlay = {popup_container = popup_container},
		config = UiConfig(FakeFilesystem(), "ui.json")}
	local screen = MainMenuV2(ui --[[@as ui.UserInterface]]) ---@diagnostic disable-line: missing-fields
	screen.root:add(popup_container) -- the overlay's, over the screen
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
function test.status_line_spans_the_bottom_under_the_music_strip_and_play(t)
	setup()
	local screen = newScreen()
	screen:update(0)
	screen:flush()
	local strip, line, play, content = screen.music_strip, screen.status_line, screen.play_button, screen.content
	t:eq(line.x, 0)
	t:eq(line.width, content.width)
	t:eq(line.y + line.height, content.height)
	t:eq(strip.x, 40)
	t:eq(strip.y + strip.height, line.y - 20)
	t:eq(play.y + play.height, line.y - 20)
	screen.root:finishTransforms() -- past the fade-in, which starts at opacity 0
	screen:draw()
end

---@param t testing.T
function test.music_strip_follows_the_selection_and_the_pause(t)
	setup()
	local screen = newScreen()
	local strip, api = screen.music_strip, screen.ui.api
	screen:flush()
	local next_button, pause, previous = strip.children[1], strip.children[2], strip.children[3]
	t:eq(next_button.x + next_button.width, strip.width - 8)
	t:eq(pause.x + pause.width, next_button.x)
	t:eq(previous.x + previous.width, pause.x)
	t:eq(strip.buttons_x, previous.x)
	local chart = assert(api.charts:getSelectedChart())
	t:eq(strip.title, chart.title)
	t:eq(strip.artist, chart.artist)
	t:eq(strip.pause_button.icon, Resources.sprites.icon_pause)

	api.media:togglePreview()
	strip:update(0)
	t:eq(strip.pause_button.icon, Resources.sprites.icon_play)

	strip:bind({title = ("very long title "):rep(20), artist = ""} --[[@as rizu.api.Chart]]) ---@diagnostic disable-line: missing-fields
	t:assert(strip.title:sub(-3) == "…", "a long title is cut before the buttons")
	t:eq(strip.artist, screen.ui.localization:get("music_player.unknown_artist"))
	strip:bind(nil)
	t:eq(strip.title, screen.ui.localization:get("music_player.no_song"))
	screen:draw()
end

---@param t testing.T
function test.status_line_scrolls_recent_scores(t)
	setup()
	local scores = {{player_name = "aqua", title = "Song", difficulty = "4K Hard", accuracy = 0.9784}}
	local listeners = {} ---@type {[string]: fun()}
	local screen = newScreen({
		getRecentScores = function() return scores end,
		on = function(_, event, f)
			listeners[event] = f
			return function() end
		end,
	})
	local line = screen.status_line
	t:eq(#line.items, 1)
	t:eq(line.items[1].parts[1].text, "aqua")
	t:eq(line.items[1].parts[2].text, "97.84%")
	t:eq(line.items[1].parts[3].text, "Song [4K Hard]")
	line:update(1)
	t:eq(line.offset, -60)
	screen.root:finishTransforms()
	screen:draw()

	scores = {{player_name = "ren", title = "Untitled", difficulty = "", accuracy = 1}}
	listeners.recent_scores_changed()
	t:eq(line.items[1].parts[3].text, "Untitled", "no brackets without a difficulty name")

	scores = {}
	listeners.recent_scores_changed()
	t:eq(#line.items, 0)
	line:update(1)
	screen:draw()
end

---@param t testing.T
function test.players_coming_online_pass_by_once_after_what_is_on_screen(t)
	setup()
	local scores = {} ---@type rizu.api.Online.RecentScore[]
	for i = 1, 10 do
		scores[i] = {player_name = "p" .. i, title = "A song with a fairly long title " .. i, difficulty = "4K", accuracy = 0.95}
	end
	local listeners = {} ---@type {[string]: function[]}
	local function emit(event, ...) for _, f in ipairs(listeners[event] or {}) do f(...) end end
	local screen = newScreen({
		getRecentScores = function() return scores end,
		on = function(_, event, f)
			listeners[event] = listeners[event] or {}
			table.insert(listeners[event], f)
			return function() end
		end,
	})
	screen:update(0)
	screen:flush()
	local line = screen.status_line
	local x = line:getItemsX()
	local visible = 0
	while x < line.width do
		visible = visible + 1
		x = x + line.items[visible].width + 32
	end

	emit("player_joined", {name = "kaede", avatar_url = "k.png", chartplays_count = 0, play_time = 0})
	local join = line.items[visible + 1]
	t:assert(join.once, "goes right after the items on screen")
	t:eq(join.parts[2].text, "kaede")
	t:eq(join.parts[3].text, "is online")
	emit("recent_scores_changed")
	t:eq(#line.items, 11, "new scores keep it")

	for _ = 1, 200 do line:update(1) end
	t:eq(#line.items, 10, "gone once it has passed")
	t:assert(line.offset <= 0)
	screen:draw()
end

---@param t testing.T
function test.presence_shows_the_latest_players_and_lists_everyone(t)
	setup()
	local listeners = {} ---@type {[string]: function[]}
	local function emit(event, ...) for _, f in ipairs(listeners[event] or {}) do f(...) end end
	local screen = newScreen({
		on = function(_, event, f)
			listeners[event] = listeners[event] or {}
			table.insert(listeners[event], f)
			return function() end
		end,
	})
	screen:update(0)
	screen:flush()
	local presence, bar, clock, content = screen.presence, screen.top_bar, screen.clock, screen.content
	t:eq(presence.text, "42 online")
	t:eq(#presence.players, 42)
	t:assert(presence.x + presence.width < clock.x, "left of the clock")
	t:eq(bar.x + bar.width, content.width - 40)
	screen.root:finishTransforms()
	screen:draw()

	emit("player_joined", {name = "kaede", chartplays_count = 0, play_time = 0})
	t:eq(presence.joined, 0, "the newest avatar grows in")
	presence:update(1)
	t:eq(presence.joined, 0.4)

	screen.ui.api.online.getOnlineCount = function() return 1234 end
	emit("online_count_changed")
	screen:flush()
	t:eq(presence.text, "1234 online")
	t:eq(bar.x + bar.width, content.width - 40, "the bar refits to the wider count")

	t:assert(presence:open())
	local list = assert(presence.popup)
	screen:flush()
	t:eq(screen.ui.overlay.popup_container.popup, list)
	t:eq(list.list:getRowCount(), 42)
	t:eq(list.height, 520, "a long list scrolls")
	screen:draw()
	t:assert(presence:close())
	t:eq(screen.ui.overlay.popup_container.popup, nil)

	presence:open()
	screen.ui.overlay.popup_container:onMouseDown()
	t:eq(presence.popup, nil, "a click outside closes it")
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

---@param t testing.T
function test.a_picked_image_becomes_a_parallax_layer(t)
	setup()
	local directory = BackgroundLayers.directory
	BackgroundLayers.directory = "test_main_menu_background"
	local screen = newScreen()
	local layers, panel = screen.background_layers, screen.background_panel
	love.filesystem.write("test_bg_source.png", love.image.newImageData(4, 2):encode("png"):getString())
	love.filesystem.write("test_bg_source.txt", "not an image")
	local save = love.filesystem.getRealDirectory("test_bg_source.png") -- an absolute path, as the dialog gives
	t:eq(#screen.background.layers, 3, "the default art")
	t:eq(screen.background.layers[3].image, Resources.images.main_menu_petals)

	-- The panel picks the front layer through the file dialog.
	panel.file_picker = {open = function(_, _, _, callback) callback(save .. "/test_bg_source.png") end} ---@diagnostic disable-line: assign-type-mismatch
	panel:open()
	panel:pick("front") ---@diagnostic disable-line: invisible
	local path = "test_main_menu_background/front/test_bg_source.png"
	t:eq(layers:getPath("front"), path)
	t:assert(love.filesystem.getInfo(path), "copied into the save directory")
	t:eq(#screen.background.layers, 3)
	t:eq(screen.background.layers[3].image:getWidth(), 4)
	screen:update(0)
	local front_row ---@type ui.screens.main_menu_v2.LayerRow?
	for _, row in ipairs(panel.form.rows.children) do
		---@cast row ui.screens.main_menu_v2.LayerRow
		if LayerRow * row and row.file_name == "test_bg_source.png" then front_row = row end
	end
	t:assert(front_row and #front_row.buttons == 3, "a picked layer can go back to the default or be removed")
	screen:flush()
	screen:draw()
	love.graphics.present()

	local ok, err = layers:import("front", save .. "/test_bg_source.txt")
	t:assert(not ok and err, "a file that is not an image is refused")
	t:eq(layers:getPath("front"), path, "and keeps the working image")

	layers:remove("front")
	t:assert(not love.filesystem.getInfo(path), "the copy is deleted")
	t:eq(#screen.background.layers, 2, "an empty layer is not drawn")
	layers:reset("front")
	t:eq(screen.background.layers[3].image, Resources.images.main_menu_petals)

	panel:close()
	t:eq(panel.is_open, false)
	love.filesystem.remove("test_bg_source.png")
	love.filesystem.remove("test_bg_source.txt")
	love.filesystem.remove("test_main_menu_background/front")
	love.filesystem.remove("test_main_menu_background")
	BackgroundLayers.directory = directory
end

return test
