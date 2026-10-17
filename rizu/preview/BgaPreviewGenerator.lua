local class = require("class")
local table_util = require("table_util")
local BgaPreview = require("rizu.preview.BgaPreview")

---@class rizu.preview.BgaPreviewGenerator
---@operator call: rizu.preview.BgaPreviewGenerator
local BgaPreviewGenerator = class()

function BgaPreviewGenerator:new(fs)
	self.fs = assert(fs, "missing fs")
end

local bms_bga_whitelist = {
	["bmsbga4"] = true,
	["bmsbga7"] = true,
	["bmsbga10"] = true,
}

---@param chart chart.Chart
---@param hash string
function BgaPreviewGenerator:generate(chart, hash)
	local preview = BgaPreview()
	---@type {[string]: integer}
	local samples_map = {}

	---@type {time: number, sample_index: integer, column: string}[]
	local raw_events = {}
	---@type {[string]: boolean}
	local column_set = {}

	for _, linked_note in ipairs(chart.notes:getLinkedNotes()) do
		local visual = chart:getVisualByPoint(linked_note.startNote.visualPoint --[[@as chart.VisualPoint]])

		if visual and visual.bga then
			local column = linked_note:getColumn()
			local column_str = tostring(column)
			if not column_str:find("^bmsbga") or bms_bga_whitelist[column_str] then
				local images = linked_note.startNote.data.images
				---@type string?
				local name = images and images[1] and images[1][1]

				if name then
					if not samples_map[name] then
						table.insert(preview.samples, name)
						samples_map[name] = #preview.samples
					end

					column_set[column_str] = true
					table.insert(raw_events, {
						time = linked_note:getStartTime(),
						sample_index = samples_map[name],
						column = column_str,
					})
				end
			end
		end
	end

	---@type string[]
	local columns = {}
	for column in pairs(column_set) do
		table.insert(columns, column)
	end
	table.sort(columns)

	local column_to_int = table_util.invert(columns)

	for _, raw_event in ipairs(raw_events) do
		table.insert(preview.events, {
			time = raw_event.time,
			sample_index = raw_event.sample_index,
			column = column_to_int[raw_event.column],
		})
	end

	self:writePreview(preview, hash)
end

---@param preview rizu.preview.BgaPreview
---@param hash string
function BgaPreviewGenerator:writePreview(preview, hash)
	table.sort(preview.events, function(a, b)
		return a.time < b.time
	end)

	local output_dir = "userdata/bga_previews"
	if not self.fs:getInfo(output_dir) then
		self.fs:createDirectory(output_dir)
	end

	local output_path = output_dir .. "/" .. hash .. ".bga_preview"
	self.fs:write(output_path, preview:encode())
end

return BgaPreviewGenerator
