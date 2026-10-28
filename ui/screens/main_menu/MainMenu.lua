local Screen = require("gui.Screen")
local Resources = require("ui.Resources")
local Image = require("ui.views.Image")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local MainMenuButton = require("ui.screens.main_menu.MainMenuButton")
local MainMenuBackground = require("ui.screens.main_menu.MainMenuBackground")
local Label = require("ui.views.Label")
local Colors = require("ui.Colors")
local UiActions = require("ui.UiActions")

---@class ui.screens.main_menu.MainMenu : gui.Screen
---@operator call: ui.screens.main_menu.MainMenu
---@field content gui.layout.FlowContainer
---@field online_status ui.views.Label
---@field online_observer fun()?
---@field account_buttons gui.layout.FlowContainer
---@field register_button ui.screens.main_menu.MainMenuButton
---@field login_button ui.screens.main_menu.MainMenuButton
---@field stats gui.layout.FlowContainer
---@field stat_columns gui.layout.FlowContainer[]
---@field pp_label ui.views.Label
---@field msd_label ui.views.Label
local MainMenu = Screen + {}

---@param ui ui.UserInterface
function MainMenu:new(ui)
	Screen.new(self)
	self.ui = ui

	self.root:setPivot(0.5, 0.5)
	-- Starts where exit() leaves it, so the first enter() animates too.
	self.root:setOpacity(0):setScale(0.95, 0.95)

	self.root:add(MainMenuBackground(Resources.images.main_menu_bg)):anchorFill(0, 0, 0, 0)
	self:createOnlineStatus()
	self:createAccountButtons()
	self:createContent()
	self:createLogo()
	self:createButtons()
	self:createStats()
	self:createWipNotice()
end

function MainMenu:load()
	Screen.load(self)
	self.online_observer = self.ui.api.online:on("account_changed", function()
		self:updateOnlineStatus()
	end)
	self:updateOnlineStatus()
	-- Coming back from a play loads the menu again, so its score is counted.
	self.ui.api.scores:getTotalRatings(function(totals)
		if not totals then return end
		self.pp_label:setText(("%d"):format(totals.pp))
		self.msd_label:setText(("%.2f"):format(totals.msd))
		for _, column in ipairs(self.stat_columns) do
			column:fitContent()
		end
		self.stats:fitContent()
	end)
end

function MainMenu:unload()
	if self.online_observer then
		self.online_observer()
		self.online_observer = nil
	end
	Screen.unload(self)
end

function MainMenu:enter()
	self.root:scaleTo(1, 1, 0.4, "OutQuart")
	self.root:fadeIn(0.4, "OutQuart")
end

function MainMenu:exit()
	Screen.exit(self)
	self.root:scaleTo(0.95, 0.95, 0.2)
	self.root:fadeOut(0.3, "OutCubic")
	return true
end

---@param inputs gui.Inputs
function MainMenu:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.accept) then
		self.ui:setScreen(self.ui.song_select, true)
	end
end

function MainMenu:createButtons()
	local actions = FlowContainer({direction = "column", gap = 14, align = 0.5})

	local play = actions:add(MainMenuButton(self.ui.localization:get("main_menu.play"), function()
		self.ui:setScreen(self.ui.song_select, true)
	end, {
		variant = "play",
		font_size = 30,
		icon = Resources.sprites.icon_play,
		get_beat_phase = function()
			return self.ui.api.media:getBeat()
		end,
		get_bpm = function()
			local chartview = self.ui.api.charts:getSelectedChart()
			return chartview and chartview.tempo
		end,
	}))
	play:setSize(380, 88)

	local utility = actions:add(FlowContainer({direction = "row", gap = 12, align = 0.5}))
	local settings = utility:add(MainMenuButton(self.ui.localization:get("main_menu.settings"), function()
		self.ui.modal_manager:attachConfig()
	end, {variant = "primary", font_size = 18, icon = Resources.sprites.icon_gear}))
	settings:setSize(184, 54)
	local quit = utility:add(MainMenuButton(self.ui.localization:get("main_menu.quit"), function()
		love.event.quit()
	end, {variant = "danger", font_size = 18, icon = Resources.sprites.icon_x}))
	quit:setSize(184, 54)
	utility:fitContent()

	actions:fitContent()
	self.content:add(actions)
	self.content:fitContent()

	self:createFooter()
end

function MainMenu:createFooter()
	local footer = View()
	footer:setSize(0, 72):fillWidth(0, 0):setAlignmentY(1)

	local links = footer:add(FlowContainer({direction = "row", gap = 12, align = 0.5}))
	local music_player = links:add(MainMenuButton(self.ui.localization:get("main_menu.music_player"), function()
		self.ui:setScreen(self.ui.music_player, true)
	end, {font_size = 16, icon = Resources.sprites.icon_music}))
	music_player:setSize(180, 44)

	local dlc = links:add(MainMenuButton(self.ui.localization:get("main_menu.dlc"), function()
		self.ui:setScreen(self.ui.dlc, true)
	end, {font_size = 16, icon = Resources.sprites.icon_download}))
	dlc:setSize(180, 44)

	local locations = links:add(MainMenuButton(self.ui.localization:get("main_menu.locations"), function()
		self.ui:setScreen(self.ui.locations, true)
	end, {font_size = 16, icon = Resources.sprites.icon_folder}))
	locations:setSize(180, 44)

	links:fitContent()
	links:setAlignment(0.5, 0.5)
	self.root:add(footer)
end

function MainMenu:createAccountButtons()
	local buttons = self.root:add(FlowContainer({direction = "row", gap = 10, align = 0.5}))
	self.account_buttons = buttons
	self.register_button = buttons:add(MainMenuButton(self.ui.localization:get("main_menu.register"), function()
		self.ui.modal_manager:attachExternalLink(
			self.ui.localization:get("external_link.register_title"),
			"https://rizu.su/register"
		)
	end, {font_size = 15, icon = Resources.sprites.icon_user_plus}))
	self.register_button:setSize(150, 44)
	self.login_button = buttons:add(MainMenuButton(self.ui.localization:get("main_menu.login"), function()
		self.ui.modal_manager:attachLogin()
	end, {
		variant = "primary", font_size = 15, icon = Resources.sprites.icon_log_in,
	}))
	self.login_button:setSize(150, 44)
	buttons:fitContent()
	buttons:setAlignment(1, 0):addPosition(-24, 16)
	self:updateAccountButtons()
end

function MainMenu:createOnlineStatus()
	self.online_status = self.root:add(Label({
		font_name = "medium",
		font_size = 16,
		color = Colors.muted,
	}))
	self.online_status:setAlignment(0, 0):addPosition(24, 20)
	self:updateOnlineStatus()
end

function MainMenu:updateOnlineStatus()
	local username = self.ui.api.online:getUsername()
	if username then
		self.online_status:setText(self.ui.localization:get("main_menu.logged_in_as", {username = username}))
	else
		self.online_status:setText(self.ui.localization:get("main_menu.not_connected"))
	end
	self:updateAccountButtons()
end

function MainMenu:updateAccountButtons()
	if not self.account_buttons or not self.register_button or not self.login_button then return end
	local online = self.ui.api.online
	local show_buttons = online:isConnected() and online:isAuthenticationResolved() and not online:isLoggedIn()
	if not show_buttons then
		if self.register_button.parent then self.account_buttons:remove(self.register_button) end
		if self.login_button.parent then self.account_buttons:remove(self.login_button) end
	elseif not self.register_button.parent then
		self.account_buttons:add(self.register_button)
		self.account_buttons:add(self.login_button)
	end
	self.account_buttons:fitContent()
end

function MainMenu:createWipNotice()
	local notice = self.root:add(Label({
		font_name = "medium",
		font_size = 16,
		text = self.ui.localization:get("main_menu.wip_notice"),
		color = Colors.danger,
	}))
	notice:setAlignment(0.5, 1):addPosition(0, -88)
end

function MainMenu:createContent()
	self.content = self.root:add(FlowContainer({direction = "column", gap = 28, align = 0.5}))
	self.content:setAlignment(0.5, 0.45)
end

---The player's total ratings over their local scores, see rizu.api.Scores:getTotalRatings().
function MainMenu:createStats()
	self.stats = self.root:add(FlowContainer({direction = "column", gap = 20, align = 0}))
	self.stat_columns = {}
	---@param caption string
	---@return ui.views.Label
	local function addStat(caption)
		local column = self.stats:add(FlowContainer({direction = "column", align = 0}))
		table.insert(self.stat_columns, column)
		local value = column:add(Label({font_name = "bold", font_size = 48, text = "-"}))
		column:add(Label({font_name = "medium", font_size = 16, text = caption, color = Colors.muted}))
		column:fitContent()
		return value
	end
	self.pp_label = addStat("Local PP")
	self.msd_label = addStat("Local MSD")
	self.stats:fitContent()
	self.stats:setAlignment(0, 0):addPosition(24, 52)
end

function MainMenu:createLogo()
	local logo = Image(Resources.sprites.rizu, "fit")
	self.logo = logo
	self.logo:setSize(420, 161)
	self.logo:setPivot(0.5, 0.5)
	self.logo:setScale(1.08, 1.08)
	self.logo:setOpacity(0)
	self.logo:fadeIn(0.9, "OutQuint")
	self.logo:scaleTo(1, 1, 0.3, "OutQuart")
	self.content:add(logo)
end

return MainMenu
