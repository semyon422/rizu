local class = require("class")

---@class rizu.select.SortModel
---@operator call: rizu.select.SortModel
local SortModel = class()

---@alias rizu.select.SortOrder string[]

---@param name string
---@return rizu.select.SortOrder
function SortModel:getOrder(name)
	return self.orders[name] or self.orders.id
end

---@type {[string]: rizu.select.SortOrder}
SortModel.orders = {
	id = {},
	title = {"title", "artist"},
	artist = {"artist", "title"},
	difficulty = {"difficulty", "name"},
	level = {"level"},
	["notes count"] = {"notes_count"},
	duration = {"duration"},
	tempo = {"tempo"},
	modtime = {"modified_at"},
	["set modtime"] = {"set_modified_at"},
	["last played"] = {"chartplay_created_at"},
}

SortModel.name = "title"
SortModel.names = {
	"id",
	"title",
	"artist",
	"difficulty",
	"level",
	"notes count",
	"duration",
	"tempo",
	"modtime",
	"set modtime",
	"last played",
}

return SortModel
