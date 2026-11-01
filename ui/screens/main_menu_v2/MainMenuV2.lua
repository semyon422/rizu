local Screen = require("gui.Screen")
local ShadowCompositeView = require("gui.ShadowCompositeView")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local UiActions = require("ui.UiActions")
local MainMenuBackground = require("ui.screens.main_menu.MainMenuBackground")
local WelcomeTransition = require("ui.screens.main_menu.WelcomeTransition")
local PlayButton = require("ui.screens.main_menu_v2.PlayButton")
local MenuButton = require("ui.screens.main_menu_v2.MenuButton")
local SessionPanel = require("ui.screens.main_menu_v2.SessionPanel")
local PlayerCard = require("ui.screens.main_menu_v2.PlayerCard")
local Scrim = require("ui.screens.song_select_v2.Scrim")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Painter = require("gui.Painter")
local Label = require("ui.views.Label")
local HeaderButton = require("ui.screens.song_select_v2.HeaderButton")
local NotificationsButton = require("ui.screens.song_select_v2.NotificationsButton")

-- Layout follows build/main-menu-mockups/6g-scrim.html, the right column 6h-full.html (1920x1080 logical).
local EDGE = 40
local PLAY_WIDTH, PLAY_HEIGHT = 560, 160
local PLAY_SLANT = 40
local COLUMN_WIDTH = PLAY_WIDTH - PLAY_SLANT -- spans Play without its slant
local BUTTON_GAP = 8
local COLUMN_GAP = 16
local ABOVE_PLAY = 20
local TOP = 36
local SEPARATOR_HEIGHT = 26
local MULTIPLAYER_COLOR = {0x3E / 255, 0xAE / 255, 0xCB / 255, 1}
local LOCATIONS_COLOR = {0xD4 / 255, 0x87 / 255, 0x3E / 255, 1}
local SETTINGS_COLOR = {0x6B / 255, 0x68 / 255, 0x80 / 255, 1}
-- Darkens the top so the player card and top bar read on any background.
local TOP_SCRIM = {{0, 0.85}, {0.1, 0.7}, {0.24, 0}, {1, 0}}

---@class ui.screens.main_menu_v2.MainMenuV2 : gui.Screen
---@operator call: ui.screens.main_menu_v2.MainMenuV2
---@field ui ui.UserInterface
---@field content gui.ShadowCompositeView
---@field play_button ui.screens.main_menu_v2.PlayButton
---@field top_bar gui.layout.FlowContainer
---@field player_card ui.screens.main_menu_v2.PlayerCard
---@field clock ui.views.Label
---@field buttons gui.layout.FlowContainer
---@field session_panel ui.screens.main_menu_v2.SessionPanel
local MainMenuV2 = Screen + {}

---@param ui ui.UserInterface
function MainMenuV2:new(ui)
	Screen.new(self)
	self.ui = ui

	self.root:setPivot(0.5, 0.5)

	local background = self.root:add(MainMenuBackground(Resources.images.main_menu_bg))
	background:anchorFill(0, 0, 0, 0)
	self.root:add(Scrim(TOP_SCRIM)):anchorFill(0, 0, 0, 0)

	-- Everything above the background casts a soft shadow, like on the result screen.
	self.content = self.root:add(ShadowCompositeView({blur = 6, opacity = 0.85}))
	self.content:anchorFill(0, 0, 0, 0)

	self.play_button = self.content:add(PlayButton(ui.localization:get("main_menu.play"):upper(), function()
		self:play()
	end, function()
		return ui.api.media:getBeat()
	end, function()
		local chartview = ui.api.charts:getSelectedChart()
		return chartview and chartview.tempo
	end))
	self.play_button:setSize(PLAY_WIDTH, PLAY_HEIGHT):setAlignment(1, 1):addPosition(-EDGE, -EDGE)
	self:createColumn()
	self:createTopBar()
	self.player_card = self.content:add(PlayerCard(ui))
	self.player_card:setAlignment(0, 0):addPosition(EDGE, EDGE)
end

---@private
function MainMenuV2:createTopBar()
	local ui = self.ui
	local bar = self.content:add(FlowContainer({direction = "row", gap = 4, align = 0.5}))
	self.top_bar = bar
	local clock = bar:add(Label({font_name = "medium", font_size = 17}))
	self.clock = clock
	-- The bar is aligned by its right edge, so it refits when the time changes width.
	clock:setUpdate(function()
		local time = os.date("%H:%M") --[[@as string]]
		if time == clock.text then return end
		clock:setText(time)
		bar:fitContent()
	end)
	bar:add(self:separator())
	local sprites = Resources.sprites
	bar:add(HeaderButton(sprites.icon_music, function()
		ui:setScreen(ui.music_player, true)
	end))
	bar:add(NotificationsButton(ui.api.notifications, function()
		ui.modal_manager:attachNotifications()
	end))
	bar:add(self:separator())
	local quit = bar:add(HeaderButton(Resources.sprites.icon_power, function()
		love.event.quit()
	end))
	quit.color = Colors.danger
	bar:fitContent()
	bar:setAlignment(1, 0):addPosition(-EDGE, TOP)
end

---@private
---@return gui.View
function MainMenuV2:separator()
	local separator = View():setSize(13, SEPARATOR_HEIGHT)
	separator:setDraw(function(view)
		Painter.setColorRgb(0.95, 0.95, 1, 0.3)
		Resources.sprites.pixel:draw(math.floor(view.width / 2), 0, 0, 1, view.height)
	end)
	return separator
end

---Above Play: the session panel, then a full-width row per button.
---@private
function MainMenuV2:createColumn()
	local ui = self.ui
	local localization = ui.localization
	local sprites = Resources.sprites
	local buttons = self.content:add(FlowContainer({direction = "column", gap = BUTTON_GAP}))
	self.buttons = buttons
	---@param key string
	---@param icon gui.Sprite
	---@param color gui.Color
	---@param on_click fun()
	local function add(key, icon, color, on_click)
		buttons:add(MenuButton(localization:get(key), icon, color, on_click)):setSize(COLUMN_WIDTH, MenuButton.HEIGHT)
	end
	add("main_menu.multiplayer", sprites.icon_gamepad, MULTIPLAYER_COLOR, function()
		ui:setScreen(ui.lobby_list, true)
	end)
	add("main_menu.editor", sprites.icon_pen, Colors.magenta, function()
		ui.api.notifications:post("info", "editor_not_implemented", "The editor is not implemented yet")
	end)
	add("main_menu.dlc", sprites.icon_download, Colors.success, function()
		ui:setScreen(ui.dlc, true)
	end)
	add("main_menu.locations", sprites.icon_folder, LOCATIONS_COLOR, function()
		ui:setScreen(ui.locations, true)
	end)
	add("main_menu.settings", sprites.icon_gear, SETTINGS_COLOR, function()
		ui.modal_manager:attachConfig()
	end)
	buttons:fitContent()
	local buttons_bottom = -EDGE - PLAY_HEIGHT - ABOVE_PLAY
	buttons:setAlignment(1, 1):addPosition(-EDGE, buttons_bottom)

	local _, buttons_height = buttons:getAuthoredSize() -- height is only resolved by the layout pass
	self.session_panel = self.content:add(SessionPanel(ui))
	self.session_panel:setAlignment(1, 1):addPosition(-EDGE, buttons_bottom - buttons_height - COLUMN_GAP)
end

function MainMenuV2:enter()
	-- Screens are loaded once, so a play made since the last visit is fetched here.
	self.player_card:refreshRatings()
	self.session_panel:refresh()
	-- Starts from where exit() would leave it: a screen hidden right away never steps its exit animation.
	self.root:setOpacity(0):setScale(0.95, 0.95)
	self.root:scaleTo(1, 1, 0.4, "OutQuart")
	self.root:fadeIn(0.4, "OutQuart")
end

function MainMenuV2:exit()
	Screen.exit(self)
	self.root:scaleTo(0.95, 0.95, 0.2)
	self.root:fadeOut(0.3, "OutCubic")
	return true
end

---@param inputs gui.Inputs
function MainMenuV2:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.accept) then
		self:play()
	end
end

function MainMenuV2:play()
	Sounds.play("menu_transition")
	local ui = self.ui
	if ui.welcome_transition_shown then
		ui:setScreen(ui.song_select, true)
		return
	end
	-- The first Play of a session goes through the welcome transition; song select takes over under its tiles.
	ui.welcome_transition_shown = true
	local x, y, w, h = self.play_button:getWorldBounds()
	local transition = WelcomeTransition(function()
		ui:setScreen(ui.song_select)
	end, ui.localization:get("welcome.transition_band"), x + w / 2, y + h / 2)
	ui.overlay.root:insert(1, transition)
	transition:anchorFill(0, 0, 0, 0)
end

return MainMenuV2
