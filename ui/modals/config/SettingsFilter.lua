---Case-insensitive, multi-term matching for the settings search box.
local SettingsFilter = {}

---Splits a query into lowercase terms. All terms must match.
---@param query string
---@return string[] terms
function SettingsFilter.parse(query)
	local terms = {}
	for term in query:lower():gmatch("%S+") do
		terms[#terms + 1] = term
	end
	return terms
end

---@param terms string[]
---@param haystacks (string?)[]
---@return boolean matches
local function matchesAll(terms, haystacks)
	for _, term in ipairs(terms) do
		local found = false
		for _, text in ipairs(haystacks) do
			if text:lower():find(term, 1, true) then
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end
	return true
end

---A control without a searchable name only matches the empty query.
---@param terms string[]
---@param control ui.views.form.FormControl
---@param section_name string
---@return boolean matches
function SettingsFilter.matchesControl(terms, control, section_name)
	if #terms == 0 then
		return true
	end
	if not control.setting_name then
		return false
	end
	local haystacks = {control.setting_name, section_name}
	if control.tip then
		haystacks[#haystacks + 1] = control.tip
	end
	for _, keyword in ipairs(control.setting_keywords or {}) do
		haystacks[#haystacks + 1] = keyword
	end
	return matchesAll(terms, haystacks)
end

---@param terms string[]
---@param section_name string
---@return boolean matches
function SettingsFilter.matchesSectionName(terms, section_name)
	return #terms > 0 and matchesAll(terms, {section_name})
end

---Returns the controls of a section that survive the filter. A query that
---matches the section name keeps the whole section.
---@param terms string[]
---@param section_name string
---@param controls ui.views.form.FormControl[]
---@return ui.views.form.FormControl[] kept
function SettingsFilter.filterControls(terms, section_name, controls)
	if #terms == 0 or SettingsFilter.matchesSectionName(terms, section_name) then
		return controls
	end
	local kept = {}
	for _, control in ipairs(controls) do
		if SettingsFilter.matchesControl(terms, control, section_name) then
			kept[#kept + 1] = control
		end
	end
	return kept
end

return SettingsFilter
