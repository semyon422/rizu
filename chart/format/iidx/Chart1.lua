---@class chart.iidx.Chart1Event
---@field tick integer
---@field type integer
---@field raw_lane integer
---@field value integer

---@class chart.iidx.Chart1Section
---@field index integer
---@field name string
---@field offset integer
---@field size integer
---@field events chart.iidx.Chart1Event[]

---@class chart.iidx.Chart1Chart
---@field header_size integer
---@field section_count integer
---@field sections {[integer]: chart.iidx.Chart1Section}
---@field data string

---@class chart.iidx.Chart1
---@field section_names {[integer]: string}
local Chart1 = {}

---@param s string
---@param o integer
---@return integer
local function le16(s, o)
	local a, b = s:byte(o, o + 1)
	return a + b * 256
end

---@param s string
---@param o integer
---@return integer
local function le32(s, o)
	local a, b, c, d = s:byte(o, o + 3)
	return a + b * 256 + c * 65536 + d * 16777216
end

Chart1.section_names = {
	[0] = "SPH",
	[1] = "SPN",
	[2] = "SPA",
	[3] = "SPB",
	[4] = "SPL",
	[5] = "DPB",
	[6] = "DPH",
	[7] = "DPN",
	[8] = "DPA",
	[10] = "DPL",
}

---@param data string
---@param offset integer
---@return chart.iidx.Chart1Event
local function parse_event(data, offset)
	local tick = le32(data, offset + 1)
	local typ = data:byte(offset + 5)
	local lane = data:byte(offset + 6)
	local value = le16(data, offset + 7)
	return {
		tick = tick,
		type = typ,
		raw_lane = lane,
		value = value,
	}
end

---@param data string
---@return chart.iidx.Chart1Chart
function Chart1.parse(data)
	local header_size
	for pos = 1, math.min(#data, 256), 8 do
		local offset = le32(data, pos)
		if offset > 0 then
			header_size = offset
			break
		end
	end
	assert(header_size and header_size % 8 == 0, "could not locate .1 section table")

	local chart = {
		header_size = header_size,
		section_count = header_size / 8,
		sections = {},
		data = data,
	}
	---@cast chart chart.iidx.Chart1Chart
	for i = 0, chart.section_count - 1 do
		local offset = le32(data, 1 + i * 8)
		local size = le32(data, 5 + i * 8)
		local section = {
			index = i,
			name = Chart1.section_names[i] or ("section_" .. i),
			offset = offset,
			size = size,
			events = {},
		}
		---@cast section chart.iidx.Chart1Section
		if offset > 0 and size > 0 then
			for p = offset, offset + size - 8, 8 do
				local event = parse_event(data, p)
				if event.tick ~= 0x7FFFFFFF then
					section.events[#section.events + 1] = event
				end
			end
		end
		chart.sections[i] = section
	end
	return chart
end

return Chart1
