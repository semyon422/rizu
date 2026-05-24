local ffi = require("ffi")
local bit = require("bit")

---@class minacalc.NoteInfo
---@field notes integer
---@field rowTime number

---@class minacalc.Ssr
---@field overall number
---@field stream number
---@field jumpstream number
---@field handstream number
---@field stamina number
---@field jackspeed number
---@field chordjack number
---@field technical number

---@class minacalc.MsdForAllRates
---@field msds {[integer]: minacalc.Ssr}

---@class minacalc.CalcHandle

---@class minacalc.Minacalc
---@field calc_version fun(): integer
---@field create_calc fun(): minacalc.CalcHandle
---@field destroy_calc fun(handle: minacalc.CalcHandle)
---@field calc_msd fun(calc: minacalc.CalcHandle, rows: minacalc.NoteInfo[], num_rows: integer, keycount: integer): minacalc.MsdForAllRates
---@field calc_msd_rate fun(calc: minacalc.CalcHandle, rows: minacalc.NoteInfo[], num_rows: integer, music_rate: number, keycount: integer): minacalc.Ssr
---@field calc_ssr fun(calc: minacalc.CalcHandle, rows: minacalc.NoteInfo[], num_rows: integer, music_rate: number, score_goal: number, keycount: integer): minacalc.Ssr

ffi.cdef [[
	typedef struct NoteInfo {
		unsigned int notes;
		float rowTime;
	} NoteInfo;

	typedef struct CalcHandle {} CalcHandle;

	typedef struct Ssr {
		float overall;
		float stream;
		float jumpstream;
		float handstream;
		float stamina;
		float jackspeed;
		float chordjack;
		float technical;
	} Ssr;

	typedef struct MsdForAllRates {
		// one for each full-rate from 0.7 to 2.0 inclusive
		Ssr msds[14];
	} MsdForAllRates;

	int calc_version();

	CalcHandle *create_calc();

	void destroy_calc(CalcHandle *calc);

	MsdForAllRates calc_msd(CalcHandle *calc, const NoteInfo *rows, size_t num_rows, const unsigned int keycount);
	Ssr calc_msd_rate(CalcHandle *calc, const NoteInfo *rows, size_t num_rows, float music_rate, unsigned keycount);
	Ssr calc_ssr(CalcHandle *calc, NoteInfo *rows, size_t num_rows, float music_rate, float score_goal, const unsigned int keycount);
]]

---@type minacalc.Minacalc
local lib = ffi.load("minacalc")

local calc_handle = lib.create_calc()

local function fix_num(n)
	if n ~= n or n == math.huge then
		return 0
	end
	return n
end

local minacalc = {}

---@type minacalc.Ssr
local empty_ssr = ffi.new("Ssr")
---@type minacalc.MsdForAllRates
local empty_msds = ffi.new("MsdForAllRates")

---@param notes {time: number, column: integer}[]
---@return minacalc.NoteInfo[] rows
---@return number num_rows
function minacalc.get_rows(notes)
	---@type {[number]: integer}
	local rows_map = {}

	for _, note in ipairs(notes) do
		local time = note.time
		local row = rows_map[time]
		rows_map[time] = bit.bor(row or 0, bit.lshift(1, note.column - 1))
	end

	---@type minacalc.NoteInfo[]
	local rows = {}

	for time, _notes in pairs(rows_map) do
		table.insert(rows, {
			rowTime = time,
			notes = _notes,
		})
	end

	table.sort(rows, function(a, b)
		return a.rowTime < b.rowTime
	end)

	return ffi.new("NoteInfo[?]", #rows, rows), #rows
end

---@param notes {time: number, column: integer}[]
---@param columns integer
---@param base_rate minacalc.Ssr
---@return number[] rate_multipliers
function minacalc.calc_rate_multipliers(notes, columns, base_rate)
	local rows, num_rows = minacalc.get_rows(notes)
	columns = math.ceil(columns / 2) * 2

	---@type minacalc.Ssr[]
	local msds = empty_msds.msds

	local ok, err = pcall(lib.calc_msd, calc_handle, rows, num_rows, columns)
	if ok then
		msds = err.msds
	end

	local rate_multipliers = {}

	for i = 0, 13, 1 do
		table.insert(rate_multipliers, fix_num(msds[i].overall / base_rate.overall))
	end

	return rate_multipliers
end

---@param notes {time: number, column: integer}[]
---@param columns integer
---@param rate number
---@return minacalc.Ssr
function minacalc.calc(notes, columns, rate)
	local rows, num_rows = minacalc.get_rows(notes)
	columns = math.ceil(columns / 2) * 2

	local ssr = empty_ssr

	-- C++ exception
	local ok, err = pcall(lib.calc_msd_rate, calc_handle, rows, num_rows, rate, columns)
	if ok then
		ssr = err
	end

	return {
		overall = fix_num(ssr.overall),
		stream = fix_num(ssr.stream),
		jumpstream = fix_num(ssr.jumpstream),
		handstream = fix_num(ssr.handstream),
		stamina = fix_num(ssr.stamina),
		jackspeed = fix_num(ssr.jackspeed),
		chordjack = fix_num(ssr.chordjack),
		technical = fix_num(ssr.technical),
	}
end

---@param notes {time: number, column: integer}[]
---@param columns integer
---@param rate number
---@param accuracy number?
---@return minacalc.Ssr
function minacalc.calc_ssr(notes, columns, rate, accuracy)
	local rows, num_rows = minacalc.get_rows(notes)
	columns = math.ceil(columns / 2) * 2

	local ssr = empty_ssr

	local ok, err = pcall(lib.calc_ssr, calc_handle, rows, num_rows, rate, accuracy, columns)
	if ok then
		ssr = err
	end

	return {
		overall = fix_num(ssr.overall),
		stream = fix_num(ssr.stream),
		jumpstream = fix_num(ssr.jumpstream),
		handstream = fix_num(ssr.handstream),
		stamina = fix_num(ssr.stamina),
		jackspeed = fix_num(ssr.jackspeed),
		chordjack = fix_num(ssr.chordjack),
		technical = fix_num(ssr.technical),
	}
end

return minacalc
