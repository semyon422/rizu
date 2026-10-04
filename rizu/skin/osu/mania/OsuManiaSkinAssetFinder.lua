local class = require("class")

---@class rizu.skin.osu.mania.OsuManiaSkinAssetFinder
---@operator call: rizu.skin.osu.mania.OsuManiaSkinAssetFinder
---@field section table
---@field columns integer
---@field column_suffixes string[]
---@field score_assets string[]
---@field accuracy_assets string[]
---@field combo_assets string[]
---@field judge_assets {name: string?, fallback: string?}[]
local OsuManiaSkinAssetFinder = class()

---@class rizu.skin.osu.mania.OsuManiaSkinAssetFinder.Request
---@field name string?
---@field fallback string?
---@field animation boolean
---@field role string

---@param section table<string, any>
---@param key string
---@return string?
local function get_section_value(section, key)
	local value = section[key]
	if value ~= nil then return value end
	local lowered_key = key:lower()
	for name, candidate in pairs(section) do
		if type(name) == "string" and name:lower() == lowered_key then return candidate end
	end
end

---@param options table<string, any>
function OsuManiaSkinAssetFinder:new(options)
	self.section = options.section or {}
	self.columns = options.columns or 0
	self.column_suffixes = options.column_suffixes or {}
	self.score_assets = options.score_assets or {}
	self.accuracy_assets = options.accuracy_assets or {}
	self.combo_assets = options.combo_assets or {}
	self.judge_assets = options.judge_assets or {}
end

---@param name string?
---@param fallback string?
---@param animation boolean?
---@param role string
function OsuManiaSkinAssetFinder:add(name, fallback, animation, role)
	if (not name or name == "") and (not fallback or fallback == "") then return end
	self.requests = self.requests or {} ---@type rizu.skin.osu.mania.OsuManiaSkinAssetFinder.Request[]
	self.seen = self.seen or {} ---@type {[string]: rizu.skin.osu.mania.OsuManiaSkinAssetFinder.Request}
	local key = tostring(name or ""):lower() .. "\0" .. tostring(fallback or ""):lower() .. "\0" .. role
	local existing = self.seen[key]
	if existing then
		existing.animation = existing.animation or animation == true
		return
	end
	local request = {
		name = name,
		fallback = fallback,
		animation = animation == true,
		role = role,
	}
	self.seen[key] = request
	self.requests[#self.requests + 1] = request
end

---@return rizu.skin.osu.mania.OsuManiaSkinAssetFinder.Request[]
function OsuManiaSkinAssetFinder:find()
	if self.requests then return self.requests end
	local requests = {} ---@type rizu.skin.osu.mania.OsuManiaSkinAssetFinder.Request[]
	local seen = {} ---@type {[string]: rizu.skin.osu.mania.OsuManiaSkinAssetFinder.Request}
	self.requests, self.seen = requests, seen

	local section = self.section
	for column = 1, self.columns do
		local zero_based_column = column - 1
		local suffix = self.column_suffixes[column] or "1"
		for _, postfix in ipairs({"", "H", "L", "T"}) do
			-- Any note part may be animated by a skin.
			self:add(get_section_value(section, "NoteImage" .. zero_based_column .. postfix), nil, true, "note")
			if postfix == "H" or postfix == "T" then
				self:add(get_section_value(section, "NoteImage" .. zero_based_column .. "H"), nil, false, "note")
				self:add(get_section_value(section, "NoteImage" .. zero_based_column), nil, false, "note")
			end
			local fallback = "mania-note" .. suffix .. postfix
			self:add(fallback, nil, true, "note")
			if postfix == "H" or postfix == "T" then
				self:add("mania-note" .. suffix, nil, false, "note")
			end
		end

		self:add(get_section_value(section, "KeyImage" .. zero_based_column), nil, false, "key")
		self:add(get_section_value(section, "KeyImage" .. zero_based_column .. "D"), nil, false, "key")
		self:add("mania-key" .. suffix, nil, false, "key")
		self:add("mania-key" .. suffix .. "D", nil, false, "key")
	end

	for _, key in ipairs({"StageHint", "StageLeft", "StageRight", "StageBottom"}) do
		local name = get_section_value(section, key)
		if name and tonumber(name) then name = nil end
		local fallback = "mania-" .. key:gsub("^Stage", "stage-"):lower()
		self:add(name, fallback, false, key == "StageHint" and "stage_hint" or "stage_decoration")
	end
	self:add(get_section_value(section, "StageLight"), "mania-stage-light", true, "lighting")
	self:add(get_section_value(section, "LightingN"), "lightingN", true, "lighting")
	self:add(get_section_value(section, "LightingL"), "lightingL", true, "lighting")

	for digit = 0, 9 do self:add("score-" .. digit, nil, false, "score_font") end
	for _, suffix in ipairs({"dot", "comma", "percent", "slash", "fps", "ms", "hz", "x"}) do
		self:add("score-" .. suffix, nil, false, "score_font")
	end
	for _, name in ipairs(self.score_assets) do self:add(name, nil, false, "score_font") end
	for _, name in ipairs(self.accuracy_assets) do self:add(name, nil, false, "accuracy_font") end
	for _, name in ipairs(self.combo_assets) do self:add(name, nil, false, "combo_font") end
	for digit = 0, 9 do self:add("score-" .. digit, nil, false, "combo_font") end
	for _, suffix in ipairs({"dot", "comma", "percent", "slash", "fps", "ms", "hz", "x"}) do
		self:add("score-" .. suffix, nil, false, "combo_font")
	end
	for _, asset in ipairs(self.judge_assets) do
		local name = asset.name or asset.fallback
		local fallback = asset.name and asset.fallback or nil
		self:add(name, fallback, true, "judgement")
	end

	self:add("editor-rate-arrow", nil, false, "standalone")
	self:add("circularmetre", nil, false, "standalone")
	return self.requests
end

return OsuManiaSkinAssetFinder
