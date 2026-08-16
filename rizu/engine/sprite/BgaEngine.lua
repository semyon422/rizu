local class = require("class")
local AsyncVideoEngine = require("rizu.preview.AsyncVideoEngine")
local SpriteEngine = require("rizu.engine.sprite.SpriteEngine")
local ResourceFinder = require("rizu.files.ResourceFinder")
local path_util = require("path_util")

local bms_bga_whitelist = {
	["bmsbga4"] = true,
	["bmsbga7"] = true,
	["bmsbga10"] = true,
}

---@class rizu.sprite.BgaEvent
---@field type "ImageNote"|"VideoNote"
---@field name string
---@field time number
---@field column chart.Column

---@class rizu.sprite.BgaEngine
---@operator call: rizu.sprite.BgaEngine
local BgaEngine = class()

---@param visual_info rizu.VisualInfo
---@param video_engine rizu.preview.AsyncVideoEngine?
function BgaEngine:new(visual_info, video_engine)
	self.visual_info = visual_info
	self.video_engine = video_engine or AsyncVideoEngine()
	self.sprite_engine = SpriteEngine()

	---@type {[chart.Visual]: {[chart.Column]: rizu.sprite.BgaEvent[]}}
	self.bga_notes = {}
	---@type {[chart.Visual]: {[chart.Column]: integer}}
	self.last_bga_index = {}
	---@type rizu.sprite.BgaEvent[]
	self.active_notes = {}
end

---@param notes rizu.sprite.BgaEvent[]
---@param time number
---@return integer
local function _findBgaIndex(notes, time)
	local low, high = 1, #notes
	local ans = 1
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if notes[mid].time <= time then
			ans = mid
			low = mid + 1
		else
			high = mid - 1
		end
	end
	return ans
end

---@param chart chart.Chart
---@param resources {[string]: string}
---@param resource_paths {[string|integer]: string}?
function BgaEngine:load(chart, resources, resource_paths)
	self.video_engine:unload()
	self.sprite_engine:unload()

	self.bga_notes = {}
	self.last_bga_index = {}

	---@type {[string]: true?}
	local image_names_map = {}
	---@type {[string]: true?}
	local video_names_map = {}

	for _, visual in ipairs(chart:getVisuals()) do
		if visual.bga then
			self.bga_notes[visual] = {}
			self.last_bga_index[visual] = {}
		end
	end

	for _, linked_note in ipairs(chart.notes:getLinkedNotes()) do
		local visual = chart:getVisualByPoint(linked_note.startNote.visualPoint --[[@as chart.VisualPoint]])

		if visual and visual.bga then
			local column = linked_note:getColumn()
			if not tostring(column):find("^bmsbga") or bms_bga_whitelist[tostring(column)] then
				self.bga_notes[visual][column] = self.bga_notes[visual][column] or {}

				---@type {images: {[1]: string}[]?}
				local note_data = linked_note.startNote.data
				local images = note_data.images
				---@type string?
				local name = images and images[1] and images[1][1]
				local _type = "ImageNote"

				if name then
					local _, ext = path_util.name_ext(name)
					if ResourceFinder:getFormat(ext) == "video" then
						_type = "VideoNote"
						video_names_map[name] = true
					else
						image_names_map[name] = true
					end
				end

				table.insert(self.bga_notes[visual][column], {
					type = _type,
					name = name,
					time = linked_note:getStartTime(),
					column = column,
				})
			end
		end
	end

	for _, columns in pairs(self.bga_notes) do
		for _, notes in pairs(columns) do
			table.sort(notes, function(a, b)
				return a.time < b.time
			end)
		end
	end

	local image_names = {}
	for name in pairs(image_names_map) do
		table.insert(image_names, name)
	end

	local video_names = {}
	for name in pairs(video_names_map) do
		table.insert(video_names, name)
	end

	self.sprite_engine:load(image_names, resources)
	if #video_names > 0 then
		self.video_engine:load(video_names, resource_paths or {})
	end
end

function BgaEngine:update()
	self.video_engine:update()
	local time = self.visual_info:getTime()
	---@type rizu.sprite.BgaEvent[]
	local active_notes = {}

	for visual, columns in pairs(self.bga_notes) do
		for column, notes in pairs(columns) do
			local last_index = self.last_bga_index[visual][column]
			---@type integer?
			local index

			if last_index and notes[last_index].time <= time then
				index = last_index
				for i = last_index + 1, #notes do
					if notes[i].time <= time then
						index = i
					else
						break
					end
				end
			else
				index = _findBgaIndex(notes, time)
			end

			if index then
				self.last_bga_index[visual][column] = index
				local bga_event = notes[index]
				table.insert(active_notes, bga_event)
			end
		end
	end

	table.sort(active_notes, function(a, b)
		return a.column < b.column
	end)

	self.active_notes = active_notes
end

-- TODO: fix
---@param time number
function BgaEngine:seek(time)
	for visual, columns in pairs(self.last_bga_index) do
		for column in pairs(columns) do
			columns[column] = nil
		end
	end
	self.video_engine:rewind()
	self:update()
end

function BgaEngine:unload()
	self.video_engine:unload()
	self.sprite_engine:unload()
	self.bga_notes = {}
	self.last_bga_index = {}
	self.active_notes = {}
end

return BgaEngine
