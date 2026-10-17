local Events = require("rizu.api.Events")

---`rizu.api.Skins` with two made-up mania skins and one osu! skin.
---@class rizu.api.fake.FakeSkins : rizu.api.Events
---@operator call: rizu.api.fake.FakeSkins
local FakeSkins = Events + {}

function FakeSkins:new()
	Events.new(self)
	self.mania = {
		{path = "builtin/mania", name = "Rizu Default", author = "Rizu", format = "builtin"},
		{path = "skins/neon", name = "Neon", author = "Nimue", version = "1.0", format = "lua"},
	}
	self.osu = {{path = "skins/classic", name = "Classic", format = "osu"}}
	self.selected = {}
end

function FakeSkins:getContext() return "mania", "4key" end

function FakeSkins:getList(gamemode, input_mode)
	return gamemode == "mania" and self.mania or self.osu
end

function FakeSkins:getSelected(gamemode, input_mode)
	return self.selected[gamemode .. "/" .. input_mode] or self:getList(gamemode, input_mode)[1]
end

function FakeSkins:select(gamemode, input_mode, skin)
	self.selected[gamemode .. "/" .. input_mode] = skin
	self:emit("skins_changed")
end

return FakeSkins
