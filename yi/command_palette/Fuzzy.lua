---@class yi.command_palette.Fuzzy.Candidate
---@field [string] any

---@class yi.command_palette.Fuzzy.MatchResult
---@field candidate yi.command_palette.Fuzzy.Candidate
---@field score number

local M = {}

--- Calculates a fuzzy match score between a query and a target string.
--- Returns nil if not a match, or a score (higher is better) if it matches.
---@param query string
---@param target string
---@return number? score
function M.match(query, target)
	if #query == 0 then return 0 end

	local q = query:lower()
	local t = target:lower()

	local q_idx = 1
	local score = 0
	local consecutive = 0
	local last_match_idx = 0

	for t_idx = 1, #t do
		local q_char = q:sub(q_idx, q_idx)
		local t_char = t:sub(t_idx, t_idx)

		if q_char == t_char then
			local char_score = 10 -- Base points for a match

			-- Bonus for matching at the beginning of a word or boundary
			if t_idx == 1 then
				char_score = char_score + 15
			else
				local prev_char = target:sub(t_idx - 1, t_idx - 1)
				if prev_char == " " or prev_char == "_" or prev_char == ":" or prev_char == "/" or prev_char == "." then
					char_score = char_score + 15
				elseif target:sub(t_idx, t_idx):find("%u") then
					-- Upper case letter boundary
					char_score = char_score + 10
				end
			end

			-- Consecutive match bonus
			if consecutive > 0 then
				char_score = char_score + (consecutive * 10)
			end

			-- Distance penalty
			if last_match_idx > 0 then
				local dist = t_idx - last_match_idx - 1
				char_score = char_score - (dist * 2)
			end

			score = score + char_score
			consecutive = consecutive + 1
			last_match_idx = t_idx
			q_idx = q_idx + 1

			if q_idx > #q then
				return score
			end
		else
			consecutive = 0
		end
	end

	return nil
end

--- Filters and sorts candidates list using the fuzzy match score.
---@param query string
---@param candidates yi.command_palette.Fuzzy.Candidate[]
---@param key_name string Field to match on
---@return yi.command_palette.Fuzzy.Candidate[] filtered_candidates
function M.filter(query, candidates, key_name)
	if #query == 0 then
		return candidates
	end

	---@type yi.command_palette.Fuzzy.MatchResult[]
	local results = {}
	for _, candidate in ipairs(candidates) do
		local val = candidate[key_name]
		if type(val) == "string" then
			local score = M.match(query, val)
			if score then
				table.insert(results, {
					candidate = candidate,
					score = score
				})
			end
		end
	end

	table.sort(results, function(a, b)
		return a.score > b.score
	end)

	---@type yi.command_palette.Fuzzy.Candidate[]
	local final_list = {}
	for i, v in ipairs(results) do
		final_list[i] = v.candidate
	end
	return final_list
end

return M

