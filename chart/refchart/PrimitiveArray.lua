local ffi = require("ffi")

local PrimitiveArray = {}

---@class refchart.DoublePointer: ffi.cdata*
---@field [integer] number
---@class refchart.Uint32Pointer: ffi.cdata*
---@field [integer] integer
---@class refchart.Int32Pointer: ffi.cdata*
---@field [integer] integer
---@class refchart.Uint16Pointer: ffi.cdata*
---@field [integer] integer
---@class refchart.Int8Pointer: ffi.cdata*
---@field [integer] integer

---@param values number[]|integer[]
---@param ctype string
---@return string
local function pack(values, ctype)
	local array = ffi.new(ctype .. "[?]", #values)
	for index, value in ipairs(values) do
		---@diagnostic disable-next-line: no-unknown -- Dynamic FFI array type is selected by the typed public wrapper.
		array[index - 1] = value
	end
	return ffi.string(array, ffi.sizeof(ctype) * #values)
end

---@param values number[]
---@return string
function PrimitiveArray.packDoubles(values)
	return pack(values, "double")
end

---@param values integer[]
---@return string
function PrimitiveArray.packUint32(values)
	return pack(values, "uint32_t")
end

---@param values integer[]
---@return string
function PrimitiveArray.packInt32(values)
	return pack(values, "int32_t")
end

---@param values integer[]
---@return string
function PrimitiveArray.packUint16(values)
	return pack(values, "uint16_t")
end

---@param values integer[]
---@return string
function PrimitiveArray.packInt8(values)
	return pack(values, "int8_t")
end

---@param value string
---@return refchart.DoublePointer
function PrimitiveArray.doubles(value)
	return ffi.cast("const double *", value)
end

---@param value string
---@return refchart.Uint32Pointer
function PrimitiveArray.uint32(value)
	return ffi.cast("const uint32_t *", value)
end

---@param value string
---@return refchart.Int32Pointer
function PrimitiveArray.int32(value)
	return ffi.cast("const int32_t *", value)
end

---@param value string
---@return refchart.Uint16Pointer
function PrimitiveArray.uint16(value)
	return ffi.cast("const uint16_t *", value)
end

---@param value string
---@return refchart.Int8Pointer
function PrimitiveArray.int8(value)
	return ffi.cast("const int8_t *", value)
end

return PrimitiveArray
