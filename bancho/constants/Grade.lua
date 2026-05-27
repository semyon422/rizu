local class = require("class")
local Grade = {}
Grade.__index = Grade

Grade.N  = setmetatable({value = 0,  label = "N"}, Grade)
Grade.F  = setmetatable({value = 1,  label = "F"}, Grade)
Grade.D  = setmetatable({value = 2,  label = "D"}, Grade)
Grade.C  = setmetatable({value = 3,  label = "C"}, Grade)
Grade.B  = setmetatable({value = 4,  label = "B"}, Grade)
Grade.A  = setmetatable({value = 5,  label = "A"}, Grade)
Grade.S  = setmetatable({value = 6,  label = "S"}, Grade)
Grade.SH = setmetatable({value = 7,  label = "SH"}, Grade)
Grade.X  = setmetatable({value = 8,  label = "X"}, Grade)
Grade.XH = setmetatable({value = 9,  label = "XH"}, Grade)

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

return Grade
