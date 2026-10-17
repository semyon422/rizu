local types = require("sea.shared.types")

---@alias sea.ComputeFailureKind "permanent"|"transient"

---@class sea.ComputeFailure
---@field kind sea.ComputeFailureKind
---@field code string
---@field message string
local ComputeFailure = {}

---@param kind sea.ComputeFailureKind
---@param code string
---@param message string
---@return sea.ComputeFailure
function ComputeFailure.new(kind, code, message)
	assert(kind == "permanent" or kind == "transient")
	assert(types.name(code))
	assert(type(message) == "string")
	return {
		kind = kind,
		code = code,
		message = message,
	}
end

---@param code string
---@param message string
---@return sea.ComputeFailure
function ComputeFailure.permanent(code, message)
	return ComputeFailure.new("permanent", code, message)
end

---@param code string
---@param message string
---@return sea.ComputeFailure
function ComputeFailure.transient(code, message)
	return ComputeFailure.new("transient", code, message)
end

---@param value any
---@return boolean
function ComputeFailure.is(value)
	return type(value) == "table"
		and (value.kind == "permanent" or value.kind == "transient")
		and types.name(value.code) == true
		and type(value.message) == "string"
end

---@param failure sea.ComputeFailure
---@return string
function ComputeFailure.format(failure)
	return ("%s: %s"):format(failure.code, failure.message)
end

return ComputeFailure
