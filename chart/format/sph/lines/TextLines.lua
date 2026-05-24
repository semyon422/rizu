local class = require("class")
local string_util = require("string_util")
local Fraction = require("chart.core.Fraction")
local template_key = require("chart.format.sph.lines.template_key")
local Line = require("chart.format.sph.lines.Line")

---@class chart.sph.TextLines
---@operator call: chart.sph.TextLines
---@field lines chart.sph.Line[]
local TextLines = class()

function TextLines:new()
	self.lines = {}
	self.columns = 1
end

---@param s string
---@return chart.Fraction
local function decode_fraction(s)
	local n, d = s:match("^(%d+)/(%d+)$")
	if not n or not d then
		return Fraction()
	end

	return Fraction(tonumber(n), tonumber(d))
end

---@param s string
---@param n number
---@return table
local function split_chars(s, n)
	local chars = {}
	for i = 1, #s, n do
		table.insert(chars, s:sub(i, i + n - 1))
	end
	return chars
end

---@param notes chart.sph.LineNote[]
---@return table
local function parse_notes(notes)
	local out = {}
	for i, note in ipairs(notes) do
		if note ~= "0" then
			table.insert(out, {
				column = i,
				type = note,
			})
		end
	end
	return out
end

---@param sounds string[]
---@return table
local function parse_sounds(sounds)
	---@type number[]
	local out = {}
	for i, sound in ipairs(sounds) do
		out[i] = template_key.decode(sound)
	end
	return out
end

---@param volume string[]
---@return number[]
local function parse_volume(volume)
	---@type number[]
	local out = {}
	for i, vol in ipairs(volume) do
		vol = tonumber(vol) or 0
		if vol == 0 then
			vol = 100
		end
		out[i] = vol / 100
	end
	return out
end

---@param velocity string
---@return number[]
local function parse_velocity(velocity)
	local vel = string_util.split(velocity, ",")
	---@type number[]
	local out = {}
	for i = 1, 3 do
		out[i] = tonumber(vel[i]) or 1
	end
	return out
end

---@param s string
---@return chart.sph.Line
function TextLines:decodeLine(s)
	local line = Line()

	local data, comment = s:match("^(.-) // (.+)$")
	if not data then
		data = s
	end
	line.comment = comment

	local args = string_util.split(data, " ")
	for i = 2, #args do
		local k, v = args[i]:match("^(.)(.*)$")

		if k == "=" then
			line.offset = tonumber(v)
		elseif k == "+" then
			line.time = decode_fraction(v)
		elseif k == "^" then
			line.same = true
		elseif k == "v" then
			line.visual = v
		elseif k == "#" then
			line.measure = decode_fraction(v)
		elseif k == ":" then
			line.sounds = parse_sounds(split_chars(v, 2))
		elseif k == "." then
			line.volume = parse_volume(split_chars(v, 2))
		elseif k == "x" then
			line.velocity = parse_velocity(v)
		elseif k == "e" then
			line.expand = tonumber(v)
		end
	end

	if args[1] ~= "-" then
		self.columns = math.max(self.columns, #args[1])
		local notes = split_chars(args[1], 1)
		line.notes = parse_notes(notes)
	end

	table.insert(self.lines, line)

	return line
end

---@param f chart.Fraction
---@return string
local function formatFraction(f)
	if f[1] == 0 then
		return ""
	end
	return f[1] .. "/" .. f[2]
end

---@param v table
---@return string
local function format_velocity(v)
	if v[3] ~= 1 then
		return ("%s,%s,%s"):format(v[1], v[2], v[3])
	end
	if v[2] ~= 1 then
		return ("%s,%s"):format(v[1], v[2])
	end
	return tostring(v[1])
end

---@param _notes chart.sph.LineNote[]
---@return string?
function TextLines:encodeNotes(_notes)
	if not _notes then
		return "-"
	end
	---@type string[]
	local notes = {}
	for i = 1, self.columns do
		notes[i] = "0"
	end
	for _, note in ipairs(_notes) do
		if note.column then
			notes[note.column] = note.type
		end
	end
	return table.concat(notes)
end

---@return string
function TextLines:encode()
	for _, line in ipairs(self.lines) do
		if line.notes then
			for _, note in ipairs(line.notes) do
				if note.column then
					self.columns = math.max(self.columns, note.column)
				end
			end
		end
	end

	local slines = {}

	for _, line in ipairs(self.lines) do
		local out = {}
		table.insert(out, self:encodeNotes(line.notes))

		if line.offset then
			table.insert(out, "=" .. line.offset)
		end
		if line.time then
			table.insert(out, "+" .. formatFraction(line.time))
		end
		if line.same then
			table.insert(out, "^")
		end
		if line.visual then
			table.insert(out, "v" .. line.visual)
		end
		if line.expand then
			table.insert(out, "e" .. tostring(line.expand))
		end
		if line.velocity then
			table.insert(out, "x" .. format_velocity(line.velocity))
		end
		if line.measure then
			table.insert(out, "#" .. formatFraction(line.measure))
		end
		if line.sounds then
			---@type string[]
			local sounds = {}
			for i, sound in ipairs(line.sounds) do
				sounds[i] = template_key.encode(sound)
			end
			table.insert(out, ":" .. table.concat(sounds))
		end
		if line.volume then
			---@type string[]
			local volume = {}
			for i, vol in ipairs(line.volume) do
				volume[i] = ("%02d"):format(math.floor(vol * 100 + 0.5) % 100)
			end
			table.insert(out, "." .. table.concat(volume))
		end
		if line.comment then
			table.insert(out, "// " .. line.comment)
		end

		table.insert(slines, table.concat(out, " "))
	end

	return table.concat(slines, "\n")
end

return TextLines
