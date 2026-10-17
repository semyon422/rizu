local KeyBindings = {}

local modifier_names = { ---@type {[string]: string}
	alt = "alt",
	control = "control",
	ctrl = "control",
	shift = "shift",
	super = "super",
}

local modifier_labels = {
	alt = "Alt",
	control = "Ctrl",
	shift = "Shift",
	super = "Super",
}

local modifier_order = {"control", "shift", "alt", "super"}

---@param value string
---@return string trimmed
local function trim(value)
	return assert(value:match("^%s*(.-)%s*$"))
end

---@param bindings rizu.config.KeyBindings
---@return string formatted
function KeyBindings.format(bindings)
	local formatted = {} ---@type string[]
	for _, binding in ipairs(bindings) do
		local parts = {} ---@type string[]
		for _, modifier in ipairs(modifier_order) do
			if binding[modifier] then
				parts[#parts + 1] = modifier_labels[modifier]
			end
		end
		parts[#parts + 1] = binding.key
		formatted[#formatted + 1] = table.concat(parts, "+")
	end
	return table.concat(formatted, ", ")
end

---@param text string
---@return rizu.config.KeyBindings bindings
function KeyBindings.parse(text)
	local bindings = {} ---@type rizu.config.KeyBindings
	---@diagnostic disable-next-line: no-unknown
	for raw_value in text:gmatch("[^,]+") do
		local value = trim(raw_value)
		local key ---@type string?
		local modifiers = {} ---@type {[string]: boolean}
		---@diagnostic disable-next-line: no-unknown
		for raw_part in value:gmatch("[^+]+") do
			local part = trim(raw_part):lower()
			local modifier = modifier_names[part]
			if modifier then
				assert(not modifiers[modifier], "duplicate key binding modifier: " .. part)
				modifiers[modifier] = true
			else
				assert(not key, "key binding must contain exactly one key: " .. value)
				assert(part ~= "", "key binding key must not be empty")
				key = part
			end
		end
		assert(key, "key binding must contain a key: " .. value)
		bindings[#bindings + 1] = {
			key = key,
			control = modifiers.control,
			shift = modifiers.shift,
			alt = modifiers.alt,
			super = modifiers.super,
		}
	end
	return bindings
end

return KeyBindings
