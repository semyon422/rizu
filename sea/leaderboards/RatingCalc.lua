local Enum = require("rdb.Enum")

---@enum (key) sea.RatingCalc
local RatingCalc = {
	level = 0,
	difftable = 1,
	enps = 2,
	pp = 3,
}

RatingCalc = Enum(RatingCalc)
---@cast RatingCalc +{column: fun(self: rdb.Enum, rating_calc: sea.RatingCalc): string}
---@cast RatingCalc +{postfix: fun(self: rdb.Enum, rating_calc: sea.RatingCalc): string}

---@type {[sea.RatingCalc]: string}
local columns = {
	level = "chartmeta_level",
	difftable = "difftable_level",
	enps = "rating",
	pp = "rating_pp",
}

---@type {[sea.RatingCalc]: string}
local postfixes = {
	level = "lvl",
	difftable = "lvl",
	enps = "enps",
	pp = "pp",
}

---@param rating_calc sea.RatingCalc
function RatingCalc:column(rating_calc)
	return assert(columns[rating_calc])
end

---@param rating_calc sea.RatingCalc
function RatingCalc:postfix(rating_calc)
	return assert(postfixes[rating_calc])
end

return RatingCalc
