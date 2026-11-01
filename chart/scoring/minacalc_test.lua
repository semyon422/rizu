local minacalc = require("chart.scoring.minacalc")

local test = {}

---@param t testing.T
function test.negative_times(t)
	local notes = {{time = -2147483.648, column = 1}}
	for i = 1, 100 do
		notes[#notes + 1] = {time = i * 0.2, column = i % 4 + 1}
	end

	local rows, num_rows = minacalc.get_rows(notes)
	t:eq(rows[0].rowTime, 0)
	t:eq(num_rows, 101)

	-- throws a C++ exception without the shift, pcall in calc hides it here but not on Windows
	local ffi = require("ffi")
	local lib = ffi.load("minacalc")
	t:assert(pcall(lib.calc_msd_rate, lib.create_calc(), rows, num_rows, 0.5, 4))
end

return test
