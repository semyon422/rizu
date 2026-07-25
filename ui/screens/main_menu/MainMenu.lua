local Screen = require("gui.Screen")
local Resources = require("ui.Resources")
local OnlineCommands = require("ui.commands.OnlineCommands")
local DatabaseCommands = require("ui.commands.DatabaseCommands")
local Image = require("ui.views.Image")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Button = require("ui.views.Button")

---@class ui.screens.main_menu.MainMenu : gui.Screen
---@operator call: ui.screens.main_menu.MainMenu
local MainMenu = Screen + {}

---@param ui ui.UserInterface
function MainMenu:new(ui)
	Screen.new(self)
	self.ui = ui

	self.root:setPivot(0.5, 0.5)

	self.online_commands = OnlineCommands(ui.game)
	self.database_commands = DatabaseCommands(ui.game)

	self:createLogo()
	self:createButtons()
end

function MainMenu:enter()
	self.ui.command_registry:pushContext("online", self.online_commands)
	self.ui.command_registry:pushContext("database", self.database_commands)
	self.root:scaleTo(1, 1, 0.4, "OutQuart")
	self.root:fadeIn(0.4, "OutQuart")
end

function MainMenu:exit()
	Screen.exit(self)
	self.ui.command_registry:popContext("online")
	self.ui.command_registry:popContext("database")
	self.root:scaleTo(0.95, 0.95, 0.2)
	self.root:fadeOut(0.3, "OutCubic")
	return true
end

function MainMenu:createButtons()
	local buttons = FlowContainer({
		direction = "column",
		gap = 16
	})

	buttons:add(Button("Play", function()
		self.ui:setScreen(self.ui.song_select, true)
	end))

	buttons:add(Button("Settings", function()
		self.ui.modal_manager:attachConfig()
	end))

	buttons:add(Button("Tests", function()
		self.ui:setScreen(self.ui.test_screen)
	end))

	buttons:add(Button("Quit", function()
		love.event.quit()
	end))

	buttons:fitContent()
	buttons:setAlignment(0.5, 0.5)
	buttons:setOffset(0, 170)

	self.root:add(buttons)
end

function MainMenu:createLogo()
	local logo = Image(Resources.atlas, Resources.quads.rizu)
	self.logo = logo
	self.logo:setAlignment(0.5, 0.5)
	self.logo:setScale(0.7, 0.7)
	self.logo:setPivot(0.5, 0.5)
	self.logo:setOpacity(0)
	self.logo:setOffset(0, -170)
	self.logo:fadeIn(0.9, "OutQuint")
	self.logo:moveTo(0, -200, 0.5, "OutCubic")
	self.root:add(logo)
end

return MainMenu
