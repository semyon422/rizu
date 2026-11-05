local json = require("json")

---How hard the player found a play compared to its Rizu Difficulty, one JSON object per line, for
---tuning the calculator (see calc/). Never read by the game.
local DifficultyLabels = {}

DifficultyLabels.path = "userdata/difficulty_labels.jsonl"

---From "harder than its number" to "easier than its number".
DifficultyLabels.labels = {"extremely_underrated", "underrated", "exact", "overrated", "extremely_overrated"}

---@param fs fs.IFilesystem
---@param record table
---@return boolean? ok
---@return string? err
function DifficultyLabels.append(fs, record)
	local ok, line = pcall(json.encode, record)
	if not ok then
		return nil, tostring(line)
	end
	local content = ""
	if fs:getInfo(DifficultyLabels.path) then
		local data, err = fs:read(DifficultyLabels.path)
		-- An unreadable file is not overwritten.
		if not data then
			return nil, err
		end
		content = data
	end
	local written, err = fs:write(DifficultyLabels.path, content .. line .. "\n")
	if not written then
		return nil, err
	end
	return true
end

return DifficultyLabels
