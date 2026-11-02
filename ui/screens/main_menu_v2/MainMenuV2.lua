local Screen = require("gui.Screen")
local ShadowCompositeView = require("gui.ShadowCompositeView")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local UiActions = require("ui.UiActions")
local MainMenuBackground = require("ui.screens.main_menu.MainMenuBackground")
local BackgroundLayers = require("ui.screens.main_menu_v2.BackgroundLayers")
local BackgroundPanel = require("ui.screens.main_menu_v2.BackgroundPanel")
local WelcomeTransition = require("ui.screens.main_menu.WelcomeTransition")
local PlayButton = require("ui.screens.main_menu_v2.PlayButton")
local MenuButton = require("ui.screens.main_menu_v2.MenuButton")
local SessionPanel = require("ui.screens.main_menu_v2.SessionPanel")
local PlayerCard = require("ui.screens.main_menu_v2.PlayerCard")
local MusicStrip = require("ui.screens.main_menu_v2.MusicStrip")
local StatusLine = require("ui.screens.main_menu_v2.StatusLine")
local PresenceButton = require("ui.screens.main_menu_v2.PresenceButton")
local ChatBox = require("ui.screens.main_menu_v2.ChatBox")
local Scrim = require("ui.screens.song_select_v2.Scrim")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Painter = require("gui.Painter")
local Label = require("ui.views.Label")
local HeaderButton = require("ui.screens.song_select_v2.HeaderButton")
local NotificationsButton = require("ui.screens.song_select_v2.NotificationsButton")

-- Layout follows build/main-menu-mockups/6h-full.html, the music strip 6i-glass.html, the online players
-- next to the clock and the joins in the status line 6j-presence.html (1920x1080 logical).
local EDGE = 40
local PLAY_WIDTH, PLAY_HEIGHT = 560, 160
local PLAY_SLANT = 40
local COLUMN_WIDTH = PLAY_WIDTH - PLAY_SLANT -- spans Play without its slant
local BUTTON_GAP = 8
local COLUMN_GAP = 16
local ABOVE_PLAY = 20
-- Play and the music strip stand on the status line, which spans the bottom edge.
local BOTTOM = StatusLine.HEIGHT + ABOVE_PLAY
local TOP = 36
local SEPARATOR_HEIGHT = 26
local MULTIPLAYER_COLOR = {0x3E / 255, 0xAE / 255, 0xCB / 255, 1}
local LOCATIONS_COLOR = {0xD4 / 255, 0x87 / 255, 0x3E / 255, 1}
local SETTINGS_COLOR = {0x6B / 255, 0x68 / 255, 0x80 / 255, 1}
-- The background settles from this zoom and tilt (radians) on enter.
local BACKGROUND_ZOOM = 1.18
local BACKGROUND_TILT = -0.05
-- Below the player card.
local BACKGROUND_PANEL_TOP = 132
-- Darkens the top so the player card and top bar read on any background.
local TOP_SCRIM = {{0, 0.85}, {0.1, 0.7}, {0.24, 0}, {1, 0}}

---@class ui.screens.main_menu_v2.MainMenuV2 : gui.Screen
---@operator call: ui.screens.main_menu_v2.MainMenuV2
---@field ui ui.UserInterface
---@field background ui.screens.main_menu.MainMenuBackground
---@field background_layers ui.screens.main_menu_v2.BackgroundLayers
---@field background_panel ui.screens.main_menu_v2.BackgroundPanel
---@field content gui.ShadowCompositeView
---@field parts {view: gui.View, x: number, y: number, delay: number}[] Content that slides in from its edge
---@field play_button ui.screens.main_menu_v2.PlayButton
---@field top_bar gui.layout.FlowContainer
---@field player_card ui.screens.main_menu_v2.PlayerCard
---@field presence ui.screens.main_menu_v2.PresenceButton
---@field clock ui.views.Label
---@field buttons gui.layout.FlowContainer
---@field session_panel ui.screens.main_menu_v2.SessionPanel
---@field music_strip ui.screens.main_menu_v2.MusicStrip
---@field chat_box ui.screens.main_menu_v2.ChatBox
---@field status_line ui.screens.main_menu_v2.StatusLine
local MainMenuV2 = Screen + {}

---@param ui ui.UserInterface
function MainMenuV2:new(ui)
	Screen.new(self)
	self.ui = ui

	self.background_layers = BackgroundLayers(ui.config)
	self.background = self.root:add(MainMenuBackground(Resources.images.main_menu_bg))
	self.background:anchorFill(0, 0, 0, 0)
	self.background:setPivot(0.5, 0.5)
	self:refreshBackground()
	ui.config:subscribeAll(function(_, _, key)
		if key:find("^main_menu_") then
			self:refreshBackground()
		end
	end)
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
	self.play_button:setSize(PLAY_WIDTH, PLAY_HEIGHT):setAlignment(1, 1):addPosition(-EDGE, -BOTTOM)
	self:createColumn()
	self:createTopBar()
	self.player_card = self.content:add(PlayerCard(ui))
	self.player_card:setAlignment(0, 0):addPosition(EDGE, EDGE)
	self.music_strip = self.content:add(MusicStrip(ui))
	self.music_strip:setAlignment(0, 1):addPosition(EDGE, -BOTTOM)
	self.chat_box = self.content:add(ChatBox(ui.api.online, ui.api.notifications, ui.localization))
	self.chat_box:setSize(MusicStrip.WIDTH, 300):setAlignment(0, 1):addPosition(EDGE, -BOTTOM - 140)
	self.status_line = self.content:add(StatusLine(ui))
	self.status_line:setSize(0, StatusLine.HEIGHT):setAlignment(0, 1):fillWidth(0, 0)

	-- Over the content, but outside its shadow pass.
	self.background_panel = self.root:add(BackgroundPanel(self.background_layers, ui.localization, ui.api.notifications))
	self.background_panel:setAlignment(0, 0):addPosition(EDGE, BACKGROUND_PANEL_TOP)

	local SLIDE = 70
	self.parts = {
		{view = self.top_bar, x = 0, y = -SLIDE / 2, delay = 0.1},
		{view = self.player_card, x = -SLIDE, y = 0, delay = 0.1},
		{view = self.status_line, x = 0, y = SLIDE / 2, delay = 0.1},
		{view = self.music_strip, x = -SLIDE, y = 0, delay = 0.25},
		{view = self.chat_box, x = -SLIDE, y = 0, delay = 0.3},
		{view = self.session_panel, x = SLIDE, y = 0, delay = 0.1 + #self.buttons.children * 0.05},
		{view = self.play_button, x = SLIDE, y = 0, delay = 0},
	}
	for i, button in ipairs(self.buttons.children) do
		self.parts[#self.parts + 1] = {view = button, x = SLIDE, y = 0, delay = 0.1 + (#self.buttons.children - i) * 0.05}
	end
end

function MainMenuV2:refreshBackground()
	local layers = self.background_layers
	self.background:setLayers(layers:getLayers(), layers:getStrength())
end

---@private
function MainMenuV2:createTopBar()
	local ui = self.ui
	local bar = self.content:add(FlowContainer({direction = "row", gap = 4, align = 0.5}))
	self.top_bar = bar
	-- The bar is aligned by its right edge, so it refits when the count or the clock changes width.
	self.presence = bar:add(PresenceButton(ui, function() bar:fitContent() end))
	bar:add(self:separator())
	local clock = bar:add(Label({font_name = "medium", font_size = 17}))
	self.clock = clock
	clock:setUpdate(function()
		local time = os.date("%H:%M") --[[@as string]]
		if time == clock.text then return end
		clock:setText(time)
		bar:fitContent()
	end)
	bar:add(self:separator())
	local sprites = Resources.sprites
	bar:add(HeaderButton(sprites.icon_image, function()
		self.background_panel:toggle()
	end))
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
	local buttons_bottom = -BOTTOM - PLAY_HEIGHT - ABOVE_PLAY
	buttons:setAlignment(1, 1):addPosition(-EDGE, buttons_bottom)

	local _, buttons_height = buttons:getAuthoredSize() -- height is only resolved by the layout pass
	self.session_panel = self.content:add(SessionPanel(ui))
	self.session_panel:setAlignment(1, 1):addPosition(-EDGE, buttons_bottom - buttons_height - COLUMN_GAP)
end

function MainMenuV2:enter()
	-- Screens are loaded once, so a play made since the last visit is fetched here.
	self.player_card:refreshRatings()
	self.session_panel:refresh()
	self.ui.api.media:setPreviewModes("start", "random_chart")
	self.ui.api.media:startPreview()
	-- Starts from where exit() would leave it: a screen hidden right away never steps its exit animation.
	self.root:setOpacity(0)
	self.root:fadeIn(0.5, "OutQuart")
	for _, part in ipairs(self.parts) do
		part.view:clearTransforms():setOffset(part.x, part.y):setOpacity(0)
		part.view:delay(part.delay):moveTo(0, 0, 0.6, "OutQuint"):fadeIn(0.4, "OutCubic")
	end
	-- The zoom covers the corners the tilt uncovers: scale >= 1 + 16/9 * |rotation| holds all the way down.
	self.background:setScale(BACKGROUND_ZOOM, BACKGROUND_ZOOM):setRotation(BACKGROUND_TILT)
	self.background:scaleTo(1, 1, 1.2, "OutQuart")
	self.background:rotateTo(0, 1.2, "OutQuart")
end

function MainMenuV2:exit()
	Screen.exit(self)
	self.ui.api.media:setPreviewModes("chart", "loop")
	self.background_panel:close()
	self.root:fadeOut(0.3, "OutCubic")
	for _, part in ipairs(self.parts) do
		part.view:clearTransforms():moveTo(part.x * 0.5, part.y * 0.5, 0.25, "InQuad"):fadeOut(0.25, "OutCubic")
	end
	return true
end

---@param inputs gui.Inputs
function MainMenuV2:onHandleInputs(inputs)
	if self.background_panel.is_open or self.chat_box.input.focused then return end
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
