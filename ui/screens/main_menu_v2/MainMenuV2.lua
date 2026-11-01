local Screen = require("gui.Screen")
local ShadowCompositeView = require("gui.ShadowCompositeView")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local UiActions = require("ui.UiActions")
local MainMenuBackground = require("ui.screens.main_menu.MainMenuBackground")
local WelcomeTransition = require("ui.screens.main_menu.WelcomeTransition")
local PlayButton = require("ui.screens.main_menu_v2.PlayButton")

-- Layout follows build/main-menu-mockups/6g-scrim.html (1920x1080 logical).
local EDGE = 40
-- The content drifts with the background, less, so it reads as nearer.
local CONTENT_PARALLAX = 0.35

---@class ui.screens.main_menu_v2.MainMenuV2 : gui.Screen
---@operator call: ui.screens.main_menu_v2.MainMenuV2
---@field ui ui.UserInterface
---@field content gui.ShadowCompositeView
---@field play_button ui.screens.main_menu_v2.PlayButton
local MainMenuV2 = Screen + {}

---@param ui ui.UserInterface
function MainMenuV2:new(ui)
	Screen.new(self)
	self.ui = ui

	self.root:setPivot(0.5, 0.5)

	local background = self.root:add(MainMenuBackground(Resources.images.main_menu_bg))
	background:anchorFill(0, 0, 0, 0)

	-- Everything above the background casts a soft shadow, like on the result screen.
	self.content = self.root:add(ShadowCompositeView({blur = 6, opacity = 0.85}))
	self.content:anchorFill(0, 0, 0, 0)
	-- Updates after the background, so it follows this frame's parallax.
	self.content:setUpdate(function(content)
		content:setOffset(background.parallax_x * CONTENT_PARALLAX, background.parallax_y * CONTENT_PARALLAX)
	end)

	self.play_button = self.content:add(PlayButton(ui.localization:get("main_menu.play"):upper(), function()
		self:play()
	end))
	self.play_button:setSize(560, 160):setAlignment(1, 1):addPosition(-EDGE, -EDGE)
end

function MainMenuV2:enter()
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
