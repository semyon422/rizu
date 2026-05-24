local class = require("class")
local json = require("json")
local stbl = require("stbl")
local table_util = require("table_util")
local string_util = require("string_util")
local md5 = require("md5")
local int_rates = require("chart.scoring.int_rates")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")

local ModifierEncoder = class()

---@param config table
---@return string
function ModifierEncoder:encode(config)
	local t = {}
	for i, m in ipairs(config) do
		t[i] = {m.id, m.version, m.value}
	end
	return stbl.encode(t)
end

---@param config table
---@return string
function ModifierEncoder:hash(config)
	return md5.sumhexa(stbl.encode(config))
end

---@param s string
---@return any?
local function decodeValue(s)
	if s == "nil" or s == "true" then
		return nil
	end
	return tonumber(s) or s
end

---@param s string
---@return table
function ModifierEncoder:decode(s)
	local ok, err = pcall(stbl.decode, s)
	if not ok or not err then
		return {}
	end
	local t = {}
	for i, m in ipairs(err) do
		t[i] = {
			id = m[1],
			version = m[2],
			value = m[3],
		}
	end
	return t
end

--[[
AMod, 0Q, 1.2X, AltK, AM10
14:0,key;11:0,10
[{"id":19,"version":0,"value":3}]
]]

local mods_encoded_since = 1633689604

local ids = ModifierRegistry.enum
local ids_inv = table_util.invert(ModifierRegistry.enum)

local function parse_mod_from_name(s)
	if s == "AMod" or s == "XMod" or s == "ToOsu" or s:match("^(.+)dB$") then
		return {}
	elseif s == "CMod" then
		return {const = true}
	elseif s:match("^(.+)Q$") then
		local q = tonumber(s:match("^(.+)Q$"))
		return {rate = 2 ^ (q / 10), is_exp_rate = q ~= 0}
	elseif s:match("^(.+)X$") then
		return {rate = tonumber(s:match("^(.+)X$"))}
	elseif s:match("^Alt(.)$") then
		return {
			modifier = {
				id = ids.Alternate,
				version = 0,
				value = s:match("^Alt(.)$") == "K" and "key" or "scratch",
			}
		}
	elseif s:match("^Alt2(.)$") then
		return {
			modifier = {
				id = ids.Alternate2,
				version = 0,
				value = s:match("^Alt2(.)$") == "K" and "key" or "scratch",
			}
		}
	elseif s:match("^AM(.+)$") then
		return {
			modifier = {
				id = ids.Automap,
				version = 0,
				value = tonumber(s:match("^AM(.+)$")),
			}
		}
	elseif s == "DP" then
		return {
			modifier = {
				id = ids.MultiplePlay,
				version = 0,
				value = 2,
			}
		}
	elseif s == "TP" then
		return {
			modifier = {
				id = ids.MultiplePlay,
				version = 0,
				value = 3,
			}
		}
	elseif s == "QP" then
		return {
			modifier = {
				id = ids.MultiplePlay,
				version = 0,
				value = 4,
			}
		}
	elseif s == "DO" then
		return {
			modifier = {
				id = ids.MultiOverPlay,
				version = 0,
				value = 2,
			}
		}
	elseif s == "TO" then
		return {
			modifier = {
				id = ids.MultiOverPlay,
				version = 0,
				value = 3,
			}
		}
	elseif s == "QO" then
		return {
			modifier = {
				id = ids.MultiOverPlay,
				version = 0,
				value = 4,
			}
		}
	elseif s == "NLN" then
		return {
			modifier = {
				id = ids.NoLongNote,
				version = 0,
			}
		}
	elseif s == "BS" then
		return {
			modifier = {
				id = ids.BracketSwap,
				version = 0,
			}
		}
	elseif s == "NoScratch" then
		return {
			modifier = {
				id = ids.NoScratch,
				version = 0,
			}
		}
	elseif s:match("^RD(.)$") then
		local v = s:match("^RD(.)$")
		return {
			modifier = {
				id = ids.Random,
				version = 0,
				value = v == "A" and "all" or v == "L" and "left" or v == "R" and "right",
			}
		}
	elseif s:match("^Mirror(.)$") then
		local v = s:match("^Mirror(.)$")
		return {
			modifier = {
				id = ids.Mirror,
				version = 0,
				value = v == "A" and "all" or v == "L" and "left" or v == "R" and "right",
			}
		}
	elseif s:match("^FLN(.)$") then
		return {
			modifier = {
				id = ids.FullLongNote,
				version = 0,
				value = tonumber(s:match("^FLN(.)$")),
			}
		}
	end
	error(s)
end

local function _is_exp_rate(x)
	local exp = 10 * math.log(x, 2)
	local roundedExp = math.floor(exp + 0.5)
	if roundedExp % 10 == 0 then
		return false
	end
	return math.abs(exp - roundedExp) % 1 < 1e-2 and math.abs(exp) > 1e-2
end

---@param score table
---@return table
function ModifierEncoder:decodeOld(score)
	local mods = score.modifiers
	local time = score.time
	local rate = 1
	local const = false
	local config = {}

	if time >= mods_encoded_since then
		rate = score.rate
	end

	local is_exp_rate = _is_exp_rate(rate)

	if mods == "" or mods == "[]" then
		return {
			modifiers = config,
			rate = int_rates.round(rate),
			const = const,
			is_exp_rate = is_exp_rate,
		}
	end

	local ok, err = pcall(json.decode, mods)
	if ok then
		return {
			modifiers = err,
			rate = int_rates.round(rate),
			const = const,
			is_exp_rate = is_exp_rate,
		}
	end

	if time >= mods_encoded_since then
		for id, version, value in mods:gmatch("(%d+):([^;^,]+),([^;^,]+)") do
			id = tonumber(id)
			version = tonumber(version)
			if ids_inv[id] then
				table.insert(config, {
					id = id,
					version = version,
					value = decodeValue(value),
				})
			end
		end
		return {
			modifiers = config,
			rate = int_rates.round(rate),
			const = const,
			is_exp_rate = is_exp_rate,
		}
	end

	for _, mod in string_util.isplit(mods, ", ") do
		local info = parse_mod_from_name(mod)
		if info.rate then
			rate = rate * info.rate
		end
		if info.const then
			const = info.const
		end
		if info.is_exp_rate then
			is_exp_rate = info.is_exp_rate
		end
		if info.modifier then
			table.insert(config, info.modifier)
		end
	end

	return {
		modifiers = config,
		rate = int_rates.round(rate),
		const = const,
		is_exp_rate = is_exp_rate,
	}
end

return ModifierEncoder
