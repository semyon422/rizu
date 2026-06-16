local bit = require("bit")

local band = bit.band
local bnot = bit.bnot
local bxor = bit.bxor
local rshift = bit.rshift

---@class chart.iidx.IfsNode
---@field name string
---@field type integer
---@field children chart.iidx.IfsNode[]
---@field attrs {[string]: string}
---@field value string|integer|integer[]?

---@class chart.iidx.IfsFile
---@field path string
---@field offset integer
---@field size integer
---@field time integer
---@field node chart.iidx.IfsNode

---@class chart.iidx.IfsArchive
---@field data string
---@field version integer
---@field timestamp integer
---@field tree_size integer
---@field data_offset integer
---@field manifest_raw string
---@field manifest chart.iidx.IfsNode
---@field files chart.iidx.IfsFile[]

---@class chart.iidx.IfsBuildEntry
---@field path string
---@field data string
---@field time integer?

---@class chart.iidx.IfsModule
local Ifs = {}

local NODE_CHARS = "0123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz"
local END_OF_NODE = 0xFE
local END_OF_DOCUMENT = 0xFF
local ATTR_TYPE = 0x2E
local ARRAY_BIT = 0x40

local TYPE = {
	VOID = 1,
	S8 = 2,
	U8 = 3,
	S16 = 4,
	U16 = 5,
	S32 = 6,
	U32 = 7,
	S64 = 8,
	U64 = 9,
	BIN = 10,
	STR = 11,
	IP4 = 12,
	TIME = 13,
	FLOAT = 14,
	DOUBLE = 15,
	[1] = {size = 0},
	[2] = {size = 1},
	[3] = {size = 1},
	[4] = {size = 2},
	[5] = {size = 2},
	[6] = {size = 4},
	[7] = {size = 4},
	[8] = {size = 8},
	[9] = {size = 8},
	[10] = {},
	[11] = {},
	[12] = {size = 4},
	[13] = {size = 4},
	[14] = {size = 4},
	[15] = {size = 8},
	[16] = {size = 2, comp = 2, elem = 1},
	[17] = {size = 2, comp = 2, elem = 1},
	[18] = {size = 4, comp = 2, elem = 2},
	[19] = {size = 4, comp = 2, elem = 2},
	[20] = {size = 8, comp = 2, elem = 4},
	[21] = {size = 8, comp = 2, elem = 4},
	[22] = {size = 16, comp = 2, elem = 8},
	[23] = {size = 16, comp = 2, elem = 8},
	[24] = {size = 8, comp = 2, elem = 4},
	[25] = {size = 16, comp = 2, elem = 8},
	[26] = {size = 3, comp = 3, elem = 1},
	[27] = {size = 3, comp = 3, elem = 1},
	[28] = {size = 6, comp = 3, elem = 2},
	[29] = {size = 6, comp = 3, elem = 2},
	[30] = {size = 12, comp = 3, elem = 4},
	[31] = {size = 12, comp = 3, elem = 4},
	[32] = {size = 24, comp = 3, elem = 8},
	[33] = {size = 24, comp = 3, elem = 8},
	[34] = {size = 12, comp = 3, elem = 4},
	[35] = {size = 24, comp = 3, elem = 8},
	[36] = {size = 4, comp = 4, elem = 1},
	[37] = {size = 4, comp = 4, elem = 1},
	[38] = {size = 8, comp = 4, elem = 2},
	[39] = {size = 8, comp = 4, elem = 2},
	[40] = {size = 16, comp = 4, elem = 4},
	[41] = {size = 16, comp = 4, elem = 4},
	[42] = {size = 32, comp = 4, elem = 8},
	[43] = {size = 32, comp = 4, elem = 8},
	[44] = {size = 16, comp = 4, elem = 4},
	[45] = {size = 32, comp = 4, elem = 8},
	[52] = {size = 1},
}

---@param s string
---@param o integer
---@return integer
local function u8(s, o)
	return s:byte(o)
end

---@param s string
---@param o integer
---@return integer
local function u16be(s, o)
	local a, b = s:byte(o, o + 1)
	return a * 256 + b
end

---@param s string
---@param o integer
---@return integer
local function u32be(s, o)
	local a, b, c, d = s:byte(o, o + 3)
	return ((a * 256 + b) * 256 + c) * 256 + d
end

---@param v integer
---@return string
local function p8(v)
	return string.char(band(v, 0xff))
end

---@param v integer
---@return string
local function p16be(v)
	return string.char(band(rshift(v, 8), 0xff), band(v, 0xff))
end

---@param v integer
---@return string
local function p32be(v)
	if v < 0 then
		v = v + 0x100000000
	end
	return string.char(
		band(rshift(v, 24), 0xff),
		band(rshift(v, 16), 0xff),
		band(rshift(v, 8), 0xff),
		band(v, 0xff)
	)
end

---@param s string
---@return string
local function pad4(s)
	return s .. string.rep("\0", (4 - #s % 4) % 4)
end

---@param n integer
---@return integer
local function align16_len(n)
	local rest = n % 16
	if rest == 0 then
		return n
	end
	return n + (16 - rest)
end

---@param s string
---@param o integer
---@return integer
local function i32be(s, o)
	local v = u32be(s, o)
	if v >= 0x80000000 then
		return v - 0x100000000
	end
	return v
end

---@param n string
---@return string
local function fix_name(n)
	n = n:gsub("_E", "."):gsub("__", "_")
	if n:sub(1, 1) == "_" and n:sub(2, 2):match("%d") then
		n = n:sub(2)
	end
	return n
end

---@param n string
---@return string
local function sanitize_name(n)
	n = n:gsub("_", "__"):gsub("%.", "_E")
	if n:sub(1, 1):match("%d") then
		n = "_" .. n
	end
	return n
end

---@param name string
---@param typ integer
---@return chart.iidx.IfsNode
local function node(name, typ)
	return {name = name, type = typ, children = {}, attrs = {}}
end

---@param data string
---@param pos integer
---@param compressed boolean
---@return string
---@return integer
local function decode_name(data, pos, compressed)
	local len = u8(data, pos)
	pos = pos + 1
	if not compressed then
		if len < 0x80 then
			len = len - 0x3f
		else
			len = len * 256 + u8(data, pos) - 0x7fbf
			pos = pos + 1
		end
		return data:sub(pos, pos + len - 1), pos + len
	end

	local binlen = math.floor((len * 6 + 7) / 8)
	local bits = {}
	for i = 0, binlen - 1 do
		local b = u8(data, pos + i)
		for j = 7, 0, -1 do
			bits[#bits + 1] = band(rshift(b, j), 1)
		end
	end
	pos = pos + binlen

	local out = {}
	for i = 1, len do
		local v = 0
		for j = 1, 6 do
			v = v * 2 + bits[(i - 1) * 6 + j]
		end
		out[i] = NODE_CHARS:sub(v + 1, v + 1)
	end
	return table.concat(out), pos
end

---@param name string
---@return string
local function encode_name(name)
	local len = #name
	if len < 0x41 then
		return p8(len + 0x3f) .. name
	end
	return p16be(len + 0x7fbf) .. name
end

---@param data string
---@param pos integer
---@param typ integer
---@param compressed boolean
---@return chart.iidx.IfsNode
---@return integer
local function parse_node(data, pos, typ, compressed)
	local name
	name, pos = decode_name(data, pos, compressed)
	local n = node(name, typ)
	while true do
		local child_type = u8(data, pos)
		pos = pos + 1
		if child_type == END_OF_NODE then
			return n, pos
		elseif child_type == ATTR_TYPE then
			local key
			key, pos = decode_name(data, pos, compressed)
			n.attrs[key] = ""
		else
			local child
			child, pos = parse_node(data, pos, child_type, compressed)
			n.children[#n.children + 1] = child
		end
	end
end

---@class chart.iidx.IfsOrderItem
---@field kind "value"|"attr"
---@field node chart.iidx.IfsNode
---@field key string?
---@field align integer

---@param n chart.iidx.IfsNode
---@param out chart.iidx.IfsOrderItem[]?
---@return chart.iidx.IfsOrderItem[]
local function flatten_order(n, out)
	out = out or {}
	local base = band(n.type, bnot(ARRAY_BIT))
	local meta = TYPE[base]
	if meta and meta.size ~= 0 then
		out[#out + 1] = {kind = "value", node = n, align = meta.size and math.min(meta.size, 4) or 4}
	end
	local keys = {}
	for k in pairs(n.attrs or {}) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		out[#out + 1] = {kind = "attr", node = n, key = k, align = 4}
	end
	for _, child in ipairs(n.children or {}) do
		flatten_order(child, out)
	end
	return out
end

---@class chart.iidx.IfsOrdering
---@field order {[integer]: false|integer}
---@field size integer
---@field lastb integer
---@field lasts integer
---@field lasti integer
local Ordering = {}
Ordering.__index = Ordering

---@param size integer
---@return chart.iidx.IfsOrdering
function Ordering.new(size)
	local t = {order = {}, size = size, lastb = 1, lasts = 1, lasti = 1}
	for i = 1, size do
		t.order[i] = false
	end
	return setmetatable(t, Ordering)
end

---@param sz integer
---@param loc0 integer
---@param round integer?
function Ordering:mark(sz, loc0, round)
	round = round or 1
	while sz % round ~= 0 do
		sz = sz + 1
	end
	self:_ensure(loc0 + sz)
	local loc = loc0 + 1
	for i = loc, loc + sz - 1 do
		self.order[i] = sz
	end
end

---@return integer?
function Ordering:get_byte()
	for i = self.lastb, self.size, 4 do
		for j = 0, 3 do
			local index = i + j
			if self.order[index] ~= 1 then
				if self.order[index] == false then
					self.lastb = i
					return index - 1
				end
				break
			end
		end
	end
end

---@return integer?
function Ordering:get_short()
	for i = self.lasts, self.size, 4 do
		for j = 0, 2, 2 do
			local index = i + j
			if not (self.order[index] == 2 and self.order[index + 1] == 2) then
				if self.order[index] == false and self.order[index + 1] == false then
					self.lasts = i
					return index - 1
				end
				break
			end
		end
	end
end

---@return integer?
function Ordering:get_int()
	for i = self.lasti, self.size, 4 do
		if self.order[i] == false and self.order[i + 1] == false and self.order[i + 2] == false and self.order[i + 3] == false then
			self.lasti = i
			return i - 1
		end
	end
end

function Ordering:_pad4()
	while self.size % 4 ~= 0 do
		self.size = self.size + 1
		self.order[self.size] = false
	end
end

---@param n integer
function Ordering:_ensure(n)
	while self.size < n do
		self.size = self.size + 1
		self.order[self.size] = false
	end
end

---@return integer
function Ordering:get_int_expand()
	self:_pad4()
	for i = self.lasti, self.size, 4 do
		if self.order[i] == false and self.order[i + 1] == false and self.order[i + 2] == false and self.order[i + 3] == false then
			self.lasti = i
			return i - 1
		end
	end
	local offset = self.size
	self:_ensure(self.size + 4)
	return offset
end

---@param ord chart.iidx.IfsOrdering
---@param align integer
---@return integer?
local function get_loc(ord, align)
	if align == 1 then
		return ord:get_byte()
	elseif align == 2 then
		return ord:get_short()
	end
	return ord:get_int()
end

---@param data string
---@param loc0 integer
---@param typ integer
---@return string|integer|integer[]
---@return integer?
---@return integer?
local function decode_scalar(data, loc0, typ)
	local base = band(typ, bnot(ARRAY_BIT))
	local meta = TYPE[base]
	if band(typ, ARRAY_BIT) ~= 0 then
		local len = u32be(data, loc0 + 1)
		local vals = {}
		for i = 1, math.floor(len / meta.size) do
			vals[i] = i32be(data, loc0 + 5 + (i - 1) * meta.size)
		end
		return vals, len + 4, 4
	end
	if base == TYPE.BIN or base == TYPE.STR then
		local len = u32be(data, loc0 + 1)
		local value = data:sub(loc0 + 5, loc0 + 4 + len)
		if base == TYPE.STR then
			value = value:gsub("\0$", "")
		end
		return value, len + 4, 4
	end
	if meta and meta.comp then
		local vals = {}
		for i = 1, meta.comp do
			vals[i] = i32be(data, loc0 + 1 + (i - 1) * meta.elem)
		end
		return vals
	end
	return i32be(data, loc0 + 1)
end

---@param data string
---@return chart.iidx.IfsNode
local function decode_binary_xml(data)
	assert(data:byte(1) == 0xA0, "not Konami binary XML")
	local contents = data:byte(2)
	local compressed = contents == 0x42 or contents == 0x43
	local enc = data:byte(3)
	assert(band(bnot(enc), 255) == data:byte(4), "bad encoding complement")

	local blob = data:sub(5)
	local header_len = u32be(blob, 1)
	local pos = 5
	local root_type = u8(blob, pos)
	pos = pos + 1
	local root
	root, pos = parse_node(blob, pos, root_type, compressed)
	assert(u8(blob, pos) == END_OF_DOCUMENT, "missing end of document")

	pos = header_len + 5
	local body_len = u32be(blob, pos)
	pos = pos + 4
	local body = blob:sub(pos, pos + body_len - 1)

	local ord = Ordering.new(body_len)
	for _, item in ipairs(flatten_order(root)) do
		local loc = get_loc(ord, item.align)
		assert(loc, "body ordering exhausted")
		if item.kind == "attr" then
			local len = u32be(body, loc + 1)
			ord:mark(len + 4, loc, 4)
			item.node.attrs[item.key] = body:sub(loc + 5, loc + 4 + len):gsub("\0$", "")
		else
			local base = band(item.node.type, bnot(ARRAY_BIT))
			local meta = TYPE[base]
			local value, used, round = decode_scalar(body, loc, item.node.type)
			item.node.value = value
			ord:mark(used or meta.size, loc, round or 1)
		end
	end

	return root
end

---@param n chart.iidx.IfsNode
---@param out string[]
local function encode_node_header(n, out)
	out[#out + 1] = p8(n.type)
	out[#out + 1] = encode_name(n.name)
	local keys = {}
	for k in pairs(n.attrs or {}) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		out[#out + 1] = p8(ATTR_TYPE)
		out[#out + 1] = encode_name(k)
	end
	for _, child in ipairs(n.children or {}) do
		encode_node_header(child, out)
	end
	out[#out + 1] = p8(END_OF_NODE)
end

---@param n chart.iidx.IfsNode
---@return string
local function encode_value(n)
	local base = band(n.type, bnot(ARRAY_BIT))
	if base == 30 then
		return p32be(n.value[1]) .. p32be(n.value[2]) .. p32be(n.value[3])
	end
	error("unsupported IFS test fixture node type: " .. tostring(n.type))
end

---@param root chart.iidx.IfsNode
---@return string
local function encode_binary_xml(root)
	local header_parts = {}
	encode_node_header(root, header_parts)
	header_parts[#header_parts + 1] = p8(END_OF_DOCUMENT)
	local header = pad4(table.concat(header_parts))

	local ordering = Ordering.new(0)
	local chunks = {}
	for _, item in ipairs(flatten_order(root)) do
		local data
		if item.kind == "attr" then
			local value = tostring(item.node.attrs[item.key] or "") .. "\0"
			data = p32be(#value) .. value
		else
			data = encode_value(item.node)
		end
		local loc = ordering:get_int_expand()
		chunks[#chunks + 1] = {loc = loc, data = data}
		ordering:mark(#data, loc, 4)
	end

	local body_bytes = {}
	for i = 1, ordering.size do
		body_bytes[i] = "\0"
	end
	for _, chunk in ipairs(chunks) do
		for i = 1, #chunk.data do
			body_bytes[chunk.loc + i] = chunk.data:sub(i, i)
		end
	end
	local body = table.concat(body_bytes)

	return string.char(0xA0, 0x45, 0xA0, 0x5F) .. p32be(#header) .. header .. p32be(#body) .. body
end

---@param root chart.iidx.IfsNode
---@param path string
---@param entry {offset: integer, size: integer, time: integer?}
local function add_path(root, path, entry)
	local current = root
	local parts = {}
	for part in path:gmatch("[^/]+") do
		parts[#parts + 1] = part
	end
	for i = 1, #parts - 1 do
		local name = sanitize_name(parts[i])
		local found
		for _, child in ipairs(current.children) do
			if child.name == name and child.type == TYPE.VOID then
				found = child
				break
			end
		end
		if not found then
			found = node(name, TYPE.VOID)
			current.children[#current.children + 1] = found
		end
		current = found
	end

	local file_node = node(sanitize_name(parts[#parts]), 30)
	file_node.value = {entry.offset, entry.size, entry.time or 0}
	current.children[#current.children + 1] = file_node
end

---@param n chart.iidx.IfsNode
---@param parent string
---@param files chart.iidx.IfsFile[]
local function walk_manifest(n, parent, files)
	local real = fix_name(n.name)
	local path = parent == "" and real or (parent .. "/" .. real)
	if band(n.type, bnot(ARRAY_BIT)) == 30 and type(n.value) == "table" then
		files[#files + 1] = {
			path = path:gsub("^imgfs/", ""),
			offset = n.value[1],
			size = n.value[2],
			time = n.value[3],
			node = n,
		}
	end
	for _, child in ipairs(n.children or {}) do
		walk_manifest(child, path, files)
	end
end

---@param data string
---@return chart.iidx.IfsArchive
function Ifs.parse(data)
	assert(u32be(data, 1) == 0x6CAD8F89, "invalid IFS signature")
	local version = u16be(data, 5)
	assert(bxor(version, u16be(data, 7)) == 0xffff, "bad IFS version complement")

	local archive = {
		data = data,
		version = version,
		timestamp = u32be(data, 9),
		tree_size = u32be(data, 13),
		data_offset = u32be(data, 17),
	}
	---@cast archive chart.iidx.IfsArchive
	local mstart = version > 1 and 37 or 21
	archive.manifest_raw = data:sub(mstart, archive.data_offset)
	archive.manifest = decode_binary_xml(archive.manifest_raw)
	archive.files = {}
	walk_manifest(archive.manifest, "", archive.files)

	return archive
end

---@param archive chart.iidx.IfsArchive
---@return chart.iidx.IfsFile[]
function Ifs.list(archive)
	return archive.files
end

---@param archive chart.iidx.IfsArchive
---@param file_path string
---@return string?
function Ifs.read_file(archive, file_path)
	for _, file in ipairs(archive.files) do
		if file.path == file_path then
			return archive.data:sub(
				archive.data_offset + file.offset + 1,
				archive.data_offset + file.offset + file.size
			)
		end
	end
end

---@param entries chart.iidx.IfsBuildEntry[]
---@return string
function Ifs.build(entries)
	local data_parts = {}
	local offset = 0
	local root = node("imgfs", TYPE.VOID)

	for _, entry in ipairs(entries) do
		assert(entry.path, "entry path is required")
		assert(entry.data, "entry data is required")
		add_path(root, entry.path, {
			offset = offset,
			size = #entry.data,
			time = entry.time,
		})
		data_parts[#data_parts + 1] = entry.data
		local aligned = align16_len(#entry.data)
		if aligned > #entry.data then
			data_parts[#data_parts + 1] = string.rep("\0", aligned - #entry.data)
		end
		offset = offset + aligned
	end

	local data_blob = table.concat(data_parts)
	local manifest = encode_binary_xml(root)
	local version = 1
	local data_offset = 20 + #manifest
	local header = p32be(0x6CAD8F89)
		.. p16be(version)
		.. p16be(bxor(version, 0xffff))
		.. p32be(0)
		.. p32be(#manifest)
		.. p32be(data_offset)

	return header .. manifest .. data_blob
end

return Ifs
