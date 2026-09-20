local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Panel = require("ui.views.Panel")
local AvatarShader = require("ui.views.AvatarShader")

---@class ui.views.PlayerInfo : gui.View
---@operator call: ui.views.PlayerInfo
---@field font love.Font
---@field username string
---@field text_y number
---@field avatar_url string?
---@field avatar_image love.Image?
local PlayerInfo = View + {}

local HEIGHT = 50
local AVATAR_SIZE = 34
local LEFT_PADDING = 16
local GAP = 10
local RIGHT_PADDING = 12

---@param username string
function PlayerInfo:new(username)
	View.new(self)
	self.font = Resources.getFont("bold", 13)
	self.avatar_shader = AvatarShader.new()
	self.avatar = self:add(Panel({
		color = Colors.surface_raised,
		line_color = Colors.outline,
	}))
	self.avatar_display = self:add(View())
	self.avatar_display:setDraw(function()
		self:drawAvatar()
	end)
	self:updateText(username)
end

---@param username string
function PlayerInfo:updateText(username)
	self.username = username
	local text_width = self.font:getWidth(username)
	local avatar_x = LEFT_PADDING + text_width + GAP
	self.avatar_x = avatar_x
	self:setSize(avatar_x + AVATAR_SIZE + RIGHT_PADDING, HEIGHT)
	self.avatar:anchorFixed(avatar_x, (HEIGHT - AVATAR_SIZE) / 2, AVATAR_SIZE, AVATAR_SIZE)
	self.avatar_display:anchorFixed(avatar_x, (HEIGHT - AVATAR_SIZE) / 2, AVATAR_SIZE, AVATAR_SIZE)
end

---@param avatar_url string?
---@param avatar_cache rizu.online.AvatarCache?
function PlayerInfo:updateAvatar(avatar_url, avatar_cache)
	self.avatar_url = avatar_url
	self.avatar_cache = avatar_cache
	self.avatar_image = nil
	self.logged_avatar_image = nil
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function PlayerInfo:onLayoutChanged(old_x, old_y, old_width, old_height)
	self.text_y = (self.height - self.font:getHeight()) / 2
end

function PlayerInfo:drawAvatar()
	if self.avatar_cache then
		self.avatar_image = self.avatar_cache:get(self.avatar_url)
	end
	if self.avatar_image and self.logged_avatar_image ~= self.avatar_image then
		self.logged_avatar_image = self.avatar_image
	end
	if not self.avatar_image then return end

	local image_width, image_height = self.avatar_image:getDimensions()
	local scale = math.max(AVATAR_SIZE / image_width, AVATAR_SIZE / image_height)
	local width, height = image_width * scale, image_height * scale
	local graphics = love.graphics
	local x, y = self.avatar_display.world_transform:transformPoint(0, 0)
	self.avatar_shader:send("u_position", {x, y})
	self.avatar_shader:send("u_size", {AVATAR_SIZE, AVATAR_SIZE})
	self.avatar_shader:send("u_radius", 5)
	Painter.setColorRgb(1, 1, 1)
	graphics.setShader(self.avatar_shader)
	graphics.draw(self.avatar_image, (AVATAR_SIZE - width) / 2, (AVATAR_SIZE - height) / 2, 0, scale)
	graphics.setShader()
end

function PlayerInfo:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print(self.username, LEFT_PADDING, self.text_y)
end

return PlayerInfo
