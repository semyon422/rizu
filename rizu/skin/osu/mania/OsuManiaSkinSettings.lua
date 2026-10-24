local FIELD_HEIGHT = 480
local DEFAULT_COLUMN_WIDTH = 30
local DEFAULT_COLUMN_START = 136
local DEFAULT_COLUMN_RIGHT = 19
local DEFAULT_HIT_POSITION = 402

---Values the osu!mania renderer reads from the skin.ini [Mania] section of the current key count.
---@class rizu.skin.osu.mania.OsuManiaSkinSettings
---@field section rizu.skin.OsuSkinIni.ManiaSection
---@field columns integer
---@field inputs chart.Column[] Inputs in physical lane order
---@field input_map {[chart.Column]: integer} Physical lane of each input
---@field scratch_count integer
---@field scratch_columns {[integer]: boolean}
---@field column_suffixes {[integer]: "1"|"2"|"S"} Keyed by zero based lane
---@field column_widths number[]
---@field column_spacings number[]
---@field column_lines number[]
---@field column_start number
---@field column_right number
---@field skin_hit_position number Hit position declared by the skin ini (HitPosition)
---@field skin_upside_down boolean Direction declared by the skin ini (UpsideDown)
---@field special_style integer
---@field note_height_scale number
---@field note_base_width number Column width that note heights scale from
---@field note_body_styles string[]
---@field default_note_body_style string
---@field keys_under_notes boolean
---@field stage_under_keys boolean Draw stage decorations below keys when true.
---@field judgement_line boolean
---@field note_flip boolean
---@field key_flip boolean
---@field split_stages boolean
---@field stage_separation number
---@field light_position number
---@field light_frame_rate number
---@field lighting_n_widths number[]
---@field lighting_l_widths number[]

local OsuManiaSkinSettings = {}

---skin.ini keys are case insensitive.
---@param section table<string, any>
---@param key string
---@return string?
function OsuManiaSkinSettings.get_value(section, key)
	local value = section[key]
	if value ~= nil then return value end
	local lowered_key = key:lower()
	for name, candidate in pairs(section) do
		if type(name) == "string" and name:lower() == lowered_key then return candidate end
	end
end
local get_value = OsuManiaSkinSettings.get_value

---@param number number?
---@return boolean
local function is_finite(number)
	return type(number) == "number" and number == number and number ~= math.huge and number ~= -math.huge
end

---@param section table<string, any>
---@param key string
---@param default number
---@return number
function OsuManiaSkinSettings.get_number(section, key, default)
	local number = tonumber((get_value(section, key)))
	if not is_finite(number) then return default end
	---@cast number number
	return number
end
local get_number = OsuManiaSkinSettings.get_number

---@param section table<string, any>
---@param key string
---@param default boolean
---@return boolean
function OsuManiaSkinSettings.get_boolean(section, key, default)
	local value = get_value(section, key)
	if not value then return default end
	value = value:lower()
	if value == "true" or tonumber(value) == 1 then return true end
	if value == "false" or tonumber(value) == 0 then return false end
	return default
end
local get_boolean = OsuManiaSkinSettings.get_boolean

---Like osu!stable, an entry that is not a number reads as 0 and keeps its slot; missing entries keep the default.
---@param section table<string, any>
---@param key string
---@param count integer
---@param default number
---@param minimum number
---@param maximum number
---@return number[]
function OsuManiaSkinSettings.get_number_list(section, key, count, default, minimum, maximum)
	local result = {}
	for index = 1, count do result[index] = default end
	local value = get_value(section, key)
	if value and value ~= "" then
		local index = 0
		for component in (value .. ","):gmatch("(.-),") do
			index = index + 1
			if index > count then break end
			local number = tonumber(component:match("^%s*(.-)%s*$"))
			result[index] = is_finite(number) and number or 0
		end
	end
	for index = 1, count do result[index] = math.max(minimum, math.min(maximum, result[index])) end
	return result
end
local get_number_list = OsuManiaSkinSettings.get_number_list

---@param section table<string, any>
---@param key string
---@param fallback number[]
---@return number[]
function OsuManiaSkinSettings.get_color(section, key, fallback)
	local value = get_value(section, key)
	if not value then return fallback end
	local values = {}
	for component in (value .. ","):gmatch("(.-),") do
		local number = tonumber(component:match("^%s*(.-)%s*$"))
		if not number then return fallback end
		values[#values + 1] = math.max(0, math.min(255, number)) / 255
	end
	if #values < 3 then return fallback end
	values[4] = values[4] or 1
	return values
end

---@param columns integer
---@param scratch_count integer
---@param special_style integer
---@return {[integer]: boolean}
local function get_scratch_columns(columns, scratch_count, special_style)
	local scratch_columns = {}
	if special_style == 1 then
		if scratch_count == 1 then
			scratch_columns[1] = true
		elseif scratch_count == 2 then
			scratch_columns[1] = true
			scratch_columns[columns] = true
		end
	elseif special_style == 2 then
		if scratch_count == 1 then
			scratch_columns[columns] = true
		elseif scratch_count == 2 then
			local center = math.floor(columns / 2)
			scratch_columns[center] = true
			scratch_columns[center + 1] = true
		end
	end
	return scratch_columns
end

---@param inputs chart.Column[]
---@param special_style integer
---@return chart.Column[]
local function reorder_scratch_inputs(inputs, special_style)
	local scratches, keys = {}, {}
	for _, input in ipairs(inputs) do
		if input:lower():match("^scratch%d+$") then
			scratches[#scratches + 1] = input
		else
			keys[#keys + 1] = input
		end
	end

	local scratch_columns = get_scratch_columns(#inputs, #scratches, special_style)
	if not next(scratch_columns) then return inputs end

	local reordered = {}
	local scratch_index, key_index = 1, 1
	for column = 1, #inputs do
		if scratch_columns[column] then
			reordered[column] = scratches[scratch_index]
			scratch_index = scratch_index + 1
		else
			reordered[column] = keys[key_index]
			key_index = key_index + 1
		end
	end
	return reordered
end

---@param settings rizu.skin.osu.mania.OsuManiaSkinSettings
---@param physical_column integer one based physical Mania lane index
---@return "1"|"2"|"S"
local function get_column_suffix(settings, physical_column)
	local scratch_count = settings.scratch_count

	if scratch_count > 0 and (settings.special_style == 1 or settings.special_style == 2) then
		local scratch_columns = settings.scratch_columns
		if scratch_columns[physical_column] then return "S" end

		local scratch_before = 0
		for current = 1, physical_column do
			if scratch_columns[current] then scratch_before = scratch_before + 1 end
		end
		local key = physical_column - scratch_before
		local key_count = settings.columns - scratch_count
		if key_count % 2 == 1 then
			local half = (key_count - 1) / 2
			if (key_count + 1) / 2 == key then return "2" end
			return (half - key + 1) % 2 == 1 and "1" or "2"
		end
		local odd = (key_count / 2 - key + 1) % 2 == 1
		local same = key <= key_count / 2
		return odd == same and "2" or "1"
	end

	-- Preserve the original fallback layout for key-only modes and for skins
	-- that declare SpecialStyle without a matching scratch input mode.
	local key = physical_column
	local key_count = settings.columns
	local special_style = settings.special_style
	if special_style == 1 then
		if key == 1 then return "S" end
		key = key - 1
		key_count = key_count - 1
	elseif special_style == 2 then
		if key == key_count then return "S" end
		key_count = key_count - 1
	end

	if key_count % 2 == 1 then
		local half = (key_count - 1) / 2
		if (key_count + 1) / 2 == key then
			if special_style == 0 then return "S" end
			return "2"
		end
		return (half - key + 1) % 2 == 1 and "1" or "2"
	end

	local odd = (key_count / 2 - key + 1) % 2 == 1
	local same = key <= key_count / 2
	return odd == same and "2" or "1"
end

---@param skin_ini rizu.skin.OsuSkinIni.Data?
---@param base_inputs chart.Column[] Inputs of the input mode in engine order
---@param input_mode string
---@return rizu.skin.osu.mania.OsuManiaSkinSettings
function OsuManiaSkinSettings.read(skin_ini, base_inputs, input_mode)
	local columns = math.max(1, math.min(18, math.floor(#base_inputs)))
	local section = {}
	for _, candidate in ipairs(skin_ini and skin_ini.Mania or {}) do
		if tonumber(get_value(candidate, "Keys")) == columns then
			section = candidate
			break
		end
	end

	---@type rizu.skin.osu.mania.OsuManiaSkinSettings
	---@diagnostic disable-next-line: missing-fields
	local settings = {}
	settings.section = section
	settings.columns = columns
	settings.skin_upside_down = get_boolean(section, "UpsideDown", false)
	settings.column_widths = get_number_list(section, "ColumnWidth", columns, DEFAULT_COLUMN_WIDTH, 5, 100)
	settings.column_spacings = get_number_list(section, "ColumnSpacing", math.max(columns - 1, 0), 0, -math.huge, math.huge)
	for index = 1, #settings.column_spacings do
		settings.column_spacings[index] = math.max(settings.column_spacings[index], -settings.column_widths[index + 1])
	end
	settings.column_lines = get_number_list(section, "ColumnLineWidth", columns + 1, 2, 0, math.huge)
	for index, line_width in ipairs(settings.column_lines) do
		if line_width > 0 and line_width < 2 then settings.column_lines[index] = 2 end
	end
	settings.column_start = get_number(section, "ColumnStart", DEFAULT_COLUMN_START)
	settings.column_right = get_number(section, "ColumnRight", DEFAULT_COLUMN_RIGHT)
	settings.skin_hit_position = math.max(240, math.min(480, get_number(section, "HitPosition", DEFAULT_HIT_POSITION)))
	settings.special_style = math.max(0, math.min(2, math.floor(get_number(section, "SpecialStyle", 0))))
	settings.note_height_scale = math.max(0, get_number(section, "WidthForNoteHeightScale", 0))

	local base_width = settings.note_height_scale
	if base_width <= 0 then
		base_width = math.huge
		for lane = 1, columns do base_width = math.min(base_width, settings.column_widths[lane]) end
	end
	settings.note_base_width = base_width

	local general = skin_ini and skin_ini.General
	local version_value = general and get_value(general, "Version")
	local version = tonumber(version_value)
	if version_value and version_value:lower() == "latest" then version = 2.6 end
	settings.default_note_body_style = version and version >= 2.5 and "repeat_bottom" or "stretch"
	settings.note_body_styles = {}
	for column = 1, columns do
		local style = get_value(section, "NoteBodyStyle" .. (column - 1)) or get_value(section, "NoteBodyStyle")
		local style_number = tonumber(style)
		settings.note_body_styles[column] = style_number == 2 and "repeat_top"
			or style_number == 3 and "repeat_bottom"
			or style_number == 4 and "repeat_top_and_bottom"
			or style_number == 0 and "stretch"
			or settings.default_note_body_style
	end

	settings.keys_under_notes = get_boolean(section, "KeysUnderNotes", false)
	settings.stage_under_keys = get_boolean(section, "StageUnderKeys", true)
	settings.judgement_line = get_boolean(section, "JudgementLine", false)
	settings.note_flip = get_boolean(section, "NoteFlipWhenUpsideDown", true)
	settings.key_flip = get_boolean(section, "KeyFlipWhenUpsideDown", true)
	settings.split_stages = get_boolean(section, "SplitStages", columns >= 10)
	settings.stage_separation = math.max(5, get_number(section, "StageSeparation", 40))
	settings.light_position = math.max(0, math.min(FIELD_HEIGHT, get_number(section, "LightPosition", 413)))
	settings.light_frame_rate = math.max(1, get_number(section, "LightFramePerSecond", 60))
	settings.lighting_n_widths = get_number_list(section, "LightingNWidth", columns, 0, 0, math.huge)
	settings.lighting_l_widths = get_number_list(section, "LightingLWidth", columns, 0, 0, math.huge)
	if settings.split_stages and columns > 1 then
		local split = math.floor(columns / 2)
		settings.column_spacings[split] = math.max(settings.column_spacings[split] or 0, settings.stage_separation)
	end

	local inputs = {}
	for index, input in ipairs(base_inputs) do inputs[index] = input end
	local skin_inputs = get_value(section, "Inputs" .. input_mode)
	if skin_inputs then
		local reordered = {}
		for input in (skin_inputs .. ","):gmatch("(.-),") do
			input = input:match("^%s*(.-)%s*$")
			if input ~= "" then reordered[#reordered + 1] = input end
		end
		if #reordered == columns then inputs = reordered end
	end
	inputs = reorder_scratch_inputs(inputs, settings.special_style)
	settings.inputs = inputs
	settings.input_map = {}
	settings.scratch_count = 0
	for column, input in ipairs(inputs) do
		settings.input_map[input] = column
		if input:lower():match("^scratch%d+$") then settings.scratch_count = settings.scratch_count + 1 end
	end
	settings.scratch_columns = get_scratch_columns(columns, settings.scratch_count, settings.special_style)
	settings.column_suffixes = {}
	for column = 1, columns do settings.column_suffixes[column - 1] = get_column_suffix(settings, column) end

	return settings
end

return OsuManiaSkinSettings
