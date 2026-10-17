local valid = require("valid")
local utf8 = require("utf8")
local country_codes = require("sea.shared.country_codes")

local types = {}

function types.name(v)
	if type(v) ~= "string" then
		return nil, "not a string"
	end

	---@type integer?
	local len = utf8.len(v)
	if not len then
		return nil, "not a valid UTF-8 string"
	end

	if len == 0 then
		return nil, "too short"
	elseif len > 32 then
		return nil, "too long"
	end

	return true
end

function types.description(v)
	if type(v) ~= "string" then
		return nil, "not a string"
	end

	---@type integer?
	local len = utf8.len(v)
	if not len then
		return nil, "not a valid UTF-8 string"
	end

	if len > 4096 then
		return nil, "too long"
	end

	return true
end

function types.email(v)
	return not not (type(v) == "string" and v:find("@"))
end

function types.password(v)
	if type(v) ~= "string" then
		return nil, "not a string"
	end

	---@type integer?
	local len = utf8.len(v)
	if not len then
		return nil, "not a valid UTF-8 string"
	end

	if len < 8 then
		return nil, "too short"
	elseif len > 64 then
		return nil, "too long"
	end

	return true
end

function types.password_any_length(v)
	if type(v) ~= "string" then
		return nil, "not a string"
	end

	---@type integer?
	local len = utf8.len(v)
	if not len then
		return nil, "not a valid UTF-8 string"
	end

	return true
end

function types.file_name(v)
	if type(v) ~= "string" then
		return nil, "not a string"
	end

	---@type integer?
	local len = utf8.len(v)
	if not len then
		return nil, "not a valid UTF-8 string"
	end

	if len == 0 then
		return nil, "too short"
	elseif len > 255 then
		return nil, "too long"
	end

	return true
end

function types.binary(v)
	if type(v) ~= "string" then
		return nil, "not a string"
	end

	return true
end

function types.number(v)
	if type(v) ~= "number" then
		return nil, "not a number"
	elseif v ~= v then
		return nil, "NaN"
	elseif math.abs(v) == math.huge then
		return nil, "infinity"
	end

	return true
end

function types.number_or_inf(v)
	if type(v) ~= "number" then
		return nil, "not a number"
	elseif v ~= v then
		return nil, "NaN"
	end

	return true
end

function types.string(v)
	if type(v) ~= "string" then
		return nil, "not a string"
	end

	---@type integer?
	local len = utf8.len(v)
	if not len then
		return nil, "not a valid UTF-8 string"
	end

	return true
end

function types.normalized(v)
	if type(v) ~= "number" then
		return nil, "not a number"
	elseif v ~= v then
		return nil, "NaN"
	elseif v < 0 or v > 1 then
		return nil, "out of range"
	end

	return true
end

function types.count(v)
	if type(v) ~= "number" then
		return nil, "not a number"
	elseif v ~= math.floor(v) then
		return nil, "not an integer"
	elseif v < 0 then
		return nil, "negative"
	end

	return true
end
types.time = types.count

function types.integer(v)
	if type(v) ~= "number" then
		return nil, "not a number"
	elseif v ~= math.floor(v) then
		return nil, "not an integer"
	end

	return true
end

function types.boolean(v)
	if type(v) ~= "boolean" then
		return nil, "not a boolean"
	end

	return true
end

function types.md5hash(v)
	if type(v) ~= "string" then
		return nil, "not a string"
	elseif #v ~= 32 or not v:match("^[a-f0-9]*$") then
		return nil, "invalid md5 hash"
	end

	return true
end

function types.country_code(v)
	if type(v) ~= "string" then
		return nil, "not a string"
	end

	---@type integer?
	local len = utf8.len(v)
	if not len then
		return nil, "not a valid UTF-8 string"
	end
	if len ~= 2 then
		return nil, "invalid code length"
	end

	for _, t in ipairs(country_codes) do
		if t.code == v then
			return true
		end
	end

	return nil, "country code does not exist"
end

types.timezone = valid.struct({
	h = types.integer,
	m = types.integer,
	negative = types.boolean,
})

--------------------------------------------------------------------------------

---@param enum rdb.Enum
function types.new_enum(enum)
	return function(v)
		return not not enum:encode_safe(v)
	end
end

return types
