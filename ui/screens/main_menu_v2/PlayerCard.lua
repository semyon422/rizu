local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Label = require("ui.views.Label")
local AvatarShader = require("ui.views.AvatarShader")
local MainMenuButton = require("ui.screens.main_menu.MainMenuButton")

local lg = love.graphics

local AVATAR_SIZE = 64
local RING_WIDTH = 3
local PP_COLOR = {0xF5 / 255, 0xC8 / 255, 0x42 / 255, 1}
local DIVIDER_COLOR = {0xF2 / 255, 0xF2 / 255, 1, 0.25}

---Top left of the main menu: round avatar and name, or Register and Login when connected but
---not logged in, then the local PP.
---@class ui.screens.main_menu_v2.PlayerCard : gui.layout.FlowContainer
---@operator call: ui.screens.main_menu_v2.PlayerCard
---@field ui ui.UserInterface
---@field profile gui.layout.FlowContainer Avatar and name
---@field account gui.layout.FlowContainer Register and Login
---@field name ui.views.Label
---@field pp ui.views.Label
---@field pp_column gui.layout.FlowContainer
---@field avatar_shader love.Shader?
---@field unsubscribe fun()?
local PlayerCard = FlowContainer + {}

---@param ui ui.UserInterface
function PlayerCard:new(ui)
	FlowContainer.new(self, {direction = "row", gap = 18, align = 0.5})
	self.ui = ui

	local localization = ui.localization
	self.profile = self:add(FlowContainer({direction = "row", gap = 18, align = 0.5}))
	local avatar = self.profile:add(View():setSize(AVATAR_SIZE, AVATAR_SIZE))
	avatar:setDraw(function() self:drawAvatar() end)
	self.name = self.profile:add(Label({font_name = "bold", font_size = 32}))

	self.account = FlowContainer({direction = "row", gap = 10, align = 0.5})
	self.account:add(MainMenuButton(localization:get("main_menu.register"), function()
		ui.modal_manager:attachExternalLink(localization:get("external_link.register_title"), "https://rizu.su/register")
	end, {font_size = 15, icon = Resources.sprites.icon_user_plus})):setSize(150, 44)
	self.account:add(MainMenuButton(localization:get("main_menu.login"), function()
		ui.modal_manager:attachLogin()
	end, {variant = "primary", font_size = 15, icon = Resources.sprites.icon_log_in})):setSize(150, 44)
	self.account:fitContent()

	-- With the 18px gaps on both sides, the line gets the mockup's 22px of room.
	local divider = self:add(View():setSize(9, 52))
	divider:setDraw(function(view)
		Painter.setColorTable(DIVIDER_COLOR)
		Resources.sprites.pixel:draw(math.floor(view.width / 2), 0, 0, 1, view.height)
	end)

	self.pp_column = self:add(FlowContainer({direction = "column", align = 0}))
	self.pp = self.pp_column:add(Label({font_name = "bold", font_size = 32, text = "-", color = PP_COLOR}))
	self.pp_column:add(Label({
		font_name = "medium",
		font_size = 13,
		text = localization:get("main_menu.local_pp"):upper(),
		color = Colors.muted,
	}))
	self.pp_column:fitContent()
	self:updateAccount()
end

function PlayerCard:load()
	self.unsubscribe = self.ui.api.online:on("account_changed", function() self:updateAccount() end)
	self:updateAccount()
end

---Asks for the local PP again, so plays made since are counted.
function PlayerCard:refreshRatings()
	self.ui.api.scores:getTotalRatings(function(totals)
		if not totals then return end
		self.pp:setText(("%.0f"):format(totals.pp))
		self.pp_column:fitContent()
		self:fitContent()
	end)
end

function PlayerCard:unload()
	if self.unsubscribe then
		self.unsubscribe()
		self.unsubscribe = nil
	end
end

function PlayerCard:updateAccount()
	local online = self.ui.api.online
	-- Offline or still unknown keeps the profile, so the buttons do not flash on startup.
	local show_account = online:isConnected() and online:isAuthenticationResolved() and not online:isLoggedIn()
	local shown, hidden = self.profile, self.account
	if show_account then shown, hidden = self.account, self.profile end
	if hidden.parent then self:remove(hidden) end
	if not shown.parent then self:insert(1, shown) end
	self.name:setText(online:getUsername() or self.ui.localization:get("song_select.username"))
	self.profile:fitContent()
	self:fitContent()
end

function PlayerCard:drawAvatar()
	local half = AVATAR_SIZE / 2
	Painter.setColorTable(Colors.magenta)
	lg.circle("fill", half, half, half + RING_WIDTH, 48)

	local online = self.ui.api.online
	local image = online:getAvatar(online:getAvatarUrl())
	local shader = self.avatar_shader or AvatarShader.new()
	self.avatar_shader = shader
	AvatarShader.setRect(shader, 0, 0, AVATAR_SIZE, AVATAR_SIZE, half)
	Painter.setColorRgb(1, 1, 1)
	lg.setShader(shader)
	if image then
		local w, h = image:getDimensions()
		local scale = math.max(AVATAR_SIZE / w, AVATAR_SIZE / h)
		lg.draw(image, (AVATAR_SIZE - w * scale) / 2, (AVATAR_SIZE - h * scale) / 2, 0, scale)
	else
		local sprite = Resources.sprites.avatar
		local w, h = sprite:getDimensions()
		local scale = math.max(AVATAR_SIZE / w, AVATAR_SIZE / h)
		sprite:draw((AVATAR_SIZE - w * scale) / 2, (AVATAR_SIZE - h * scale) / 2, 0, scale, scale)
	end
	lg.setShader()
end

return PlayerCard
