local Events = require("rizu.api.Events")

local NAMES = {
	"kaede", "yuki", "mori", "ren", "akari", "sora", "hinata", "tsubasa", "mio", "haru", "kou", "rin", "nagi",
	"aoi", "hikari", "shiro", "kuro", "momo", "riku", "sakura", "takumi", "umi", "yume", "zen", "chiyo",
	"daichi", "emi", "fuyu", "gin", "hotaru", "itsuki", "jun", "kiri", "luna", "minato", "nao", "ori",
	"piyo", "rei", "seri", "tama", "uta", "wataru", "yoru", "aqua", "nimue", "hewowo", "beatmapper",
}
local ONLINE = 42
local JOIN_INTERVAL = 6 -- seconds between players coming online
local AVATAR_SIZE = 64

---`rizu.api.Online` for a logged in player with no avatar, on a server where other players keep coming online.
---@class rizu.api.fake.FakeOnline : rizu.api.Events
---@operator call: rizu.api.fake.FakeOnline
---@field players rizu.api.Online.Player[] online, the latest to come first
---@field offline rizu.api.Online.Player[] the next ones to come online
---@field since_join number
---@field avatars {[string]: love.Image}
local FakeOnline = Events + {}

function FakeOnline:new()
	Events.new(self)
	self.players = {}
	self.offline = {}
	self.since_join = 0
	self.avatars = {}
	for i, name in ipairs(NAMES) do
		local role = i % 11 == 0 and "admin" or i % 5 == 0 and "donator" or nil
		local player = {name = name, avatar_url = "fake:" .. i, role = role, chartplays_count = i * 37, play_time = i * 5400}
		table.insert(i <= ONLINE and self.players or self.offline, player)
	end
end

function FakeOnline:isConnected() return true end
function FakeOnline:isLoggedIn() return true end
function FakeOnline:isAuthenticationResolved() return true end
function FakeOnline:getUsername() return "Player" end
function FakeOnline:getAvatarUrl() return nil end
function FakeOnline:getChatMessages() return {} end
function FakeOnline:sendChatMessage(text, f) f(true) end
function FakeOnline:getOnlineCount() return #self.players end
function FakeOnline:getOnlinePlayers()
	local players = {} ---@type rizu.api.Online.Player[]
	for i, player in ipairs(self.players) do players[i] = player end
	return players
end
function FakeOnline:getRecentScores()
	local scores = {} ---@type rizu.api.Online.RecentScore[]
	for i = 1, 10 do
		scores[i] = {player_name = NAMES[i], title = "Song " .. i, difficulty = "4K Hard", accuracy = 1 - i / 100}
	end
	return scores
end

---Draws the fake avatars on first use: a light silhouette on a color of their own.
---@param url string?
---@return love.Image?
function FakeOnline:getAvatar(url)
	local index = tonumber(url and url:match("^fake:(%d+)$"))
	-- Tests run without a window.
	if not index or not (love and love.image and love.graphics.isActive()) then return end
	---@cast url string
	local image = self.avatars[url]
	if image then return image end
	local hue = index * 0.618 % 1
	---@param shade number
	---@return number, number, number
	local function color(shade)
		local r = math.abs(hue * 6 - 3) - 1
		local g = 2 - math.abs(hue * 6 - 2)
		local b = 2 - math.abs(hue * 6 - 4)
		local function clamp(v) return math.max(0, math.min(1, v)) end
		return shade * (0.35 + 0.65 * clamp(r)), shade * (0.35 + 0.65 * clamp(g)), shade * (0.35 + 0.65 * clamp(b))
	end
	local data = love.image.newImageData(AVATAR_SIZE, AVATAR_SIZE)
	---@param x number
	---@param y number
	data:mapPixel(function(x, y)
		local u, v = x / AVATAR_SIZE, y / AVATAR_SIZE
		local head = (u - 0.5) ^ 2 + (v - 0.4) ^ 2 < 0.04
		local body = (u - 0.5) ^ 2 + ((v - 1.05) / 1.1) ^ 2 < 0.12
		if head or body then
			local r, g, b = color(1)
			return 0.6 + 0.4 * r, 0.6 + 0.4 * g, 0.6 + 0.4 * b, 1
		end
		local r, g, b = color(0.55 + 0.25 * (1 - v))
		return r, g, b, 1
	end)
	image = love.graphics.newImage(data)
	image:setFilter("linear", "linear")
	self.avatars[url] = image
	return image
end

---The fake game calls this every frame: now and then the next player comes online.
---@param dt number
function FakeOnline:update(dt)
	self.since_join = self.since_join + dt
	if self.since_join < JOIN_INTERVAL or #self.offline == 0 then return end
	self.since_join = 0
	local player = table.remove(self.offline, 1)
	-- The one online longest goes offline, so the count stays near ONLINE.
	table.insert(self.offline, table.remove(self.players))
	table.insert(self.players, 1, player)
	self:emit("online_players_changed")
	self:emit("player_joined", player)
end

function FakeOnline:login(email, password, f) f(true) end
function FakeOnline:logout() end

return FakeOnline
