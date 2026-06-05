local class = require("class")
local Grade = {}
Grade.__index = Grade

Grade.N  = setmetatable({value = 0,  label = "N",  stats_column = "n_count"}, Grade)
Grade.F  = setmetatable({value = 1,  label = "F",  stats_column = "f_count"}, Grade)
Grade.D  = setmetatable({value = 2,  label = "D",  stats_column = "d_count"}, Grade)
Grade.C  = setmetatable({value = 3,  label = "C",  stats_column = "c_count"}, Grade)
Grade.B  = setmetatable({value = 4,  label = "B",  stats_column = "b_count"}, Grade)
Grade.A  = setmetatable({value = 5,  label = "A",  stats_column = "a_count"}, Grade)
Grade.S  = setmetatable({value = 6,  label = "S",  stats_column = "s_count"}, Grade)
Grade.SH = setmetatable({value = 7,  label = "SH", stats_column = "sh_count"}, Grade)
Grade.X  = setmetatable({value = 8,  label = "X",  stats_column = "x_count"}, Grade)
Grade.XH = setmetatable({value = 9,  label = "XH", stats_column = "xh_count"}, Grade)

function Grade.fromString(s)
	local _map = {
		xh = Grade.XH, x = Grade.X, sh = Grade.SH, s = Grade.S,
		a = Grade.A, b = Grade.B, c = Grade.C, d = Grade.D,
		f = Grade.F, n = Grade.N,
	}
	local g = _map[s:lower()]
	if not g then
		error(("invalid grade string: %q"):format(s), 2)
	end
	return g
end

--- Get grade from value.
---@param value integer
---@return table grade
function Grade.fromValue(value)
	for _, g in ipairs({Grade.N, Grade.F, Grade.D, Grade.C, Grade.B, Grade.A, Grade.S, Grade.SH, Grade.X, Grade.XH}) do
		if g.value == value then
			return g
		end
	end
	return Grade.N
end

return Grade
