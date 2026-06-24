local IChartDecoder = require("chart.format.notechart.IChartDecoder")
local Ifs = require("chart.format.iidx.Ifs")
local Chart1 = require("chart.format.iidx.Chart1")
local Chart = require("chart.model.Chart")
local InputMode = require("chart.core.InputMode")
local MeasureLayer = require("chart.model.layers.MeasureLayer")
local Visual = require("chart.model.visual.Visual")
local VisualColumns = require("chart.model.visual.VisualColumns")
local Fraction = require("chart.core.Fraction")
local Tempo = require("chart.model.to.Tempo")
local Signature = require("chart.model.to.Signature")
local Note = require("chart.format.notechart.Note")
local Chartmeta = require("sea.chart.Chartmeta")

---@class chart.iidx.ChartDecoder: chart.IChartDecoder
---@operator call: chart.iidx.ChartDecoder
---@field hash string?
local ChartDecoder = IChartDecoder + {}

---@class chart.iidx.ChartVariation
---@field name chart.iidx.VariationName
---@field section integer
---@field inputMode chart.InputMode

---@type chart.iidx.ChartVariation[]
local variations = {
	{name = "SPB", section = 3, inputMode = InputMode({key = 7, scratch = 1})},
	{name = "SPN", section = 1, inputMode = InputMode({key = 7, scratch = 1})},
	{name = "SPH", section = 0, inputMode = InputMode({key = 7, scratch = 1})},
	{name = "SPA", section = 2, inputMode = InputMode({key = 7, scratch = 1})},
	{name = "SPL", section = 4, inputMode = InputMode({key = 7, scratch = 1})},
	{name = "DPB", section = 5, inputMode = InputMode({key = 14, scratch = 2})},
	{name = "DPN", section = 7, inputMode = InputMode({key = 14, scratch = 2})},
	{name = "DPH", section = 6, inputMode = InputMode({key = 14, scratch = 2})},
	{name = "DPA", section = 8, inputMode = InputMode({key = 14, scratch = 2})},
	{name = "DPL", section = 10, inputMode = InputMode({key = 14, scratch = 2})},
}

---@param filename string
---@return integer
local function song_id_from_filename(filename)
	local id = filename:match("(%d+)")
	return assert(tonumber(id), "missing IIDX song id")
end

---@param song_id integer
---@param archive chart.iidx.IfsArchive
---@return string
local function read_chart_data(song_id, archive)
	local dir = ("%05d"):format(song_id)
	return assert(Ifs.read_file(archive, dir .. "/" .. dir .. ".1"), "missing IIDX .1 chart")
end

---@param song_id integer
---@param ident integer?
---@return string?
local function get_2dx_paths(song_id, ident)
	local dir = ("%05d"):format(song_id)
	if not ident then
		return nil
	end
	local suffix = string.char(ident)
	if suffix == "0" then
		return dir .. "/" .. dir .. ".2dx"
	end
	return dir .. "/" .. dir .. suffix .. ".2dx"
end

---@param song_id integer
---@param chart chart.Chart
---@param song chart.iidx.MusicDbEntry?
---@param variation chart.iidx.ChartVariation
local function add_audio_resources(song_id, chart, song, variation)
	local dir = ("%05d"):format(song_id)
	chart.resources:add("s3p", dir .. "/" .. dir .. ".s3p", dir .. ".s3p")

	local two_dx_path = get_2dx_paths(song_id, song and song.idents and song.idents[variation.name] or nil)
	if two_dx_path then
		chart.resources:add("2dx", two_dx_path)
	end
end

---@param filename string
---@param content string
---@param song_id integer
---@return string
local function get_chart_data(filename, content, song_id)
	if filename:lower():match("%.1$") then
		return content
	end
	local archive = Ifs.parse(content)
	return read_chart_data(song_id, archive)
end

---@param events chart.iidx.Chart1Event[]
---@return integer[]
local function get_measure_ticks(events)
	---@type integer[]
	local ticks = {}
	---@type {[integer]: true}
	local added = {}
	for _, event in ipairs(events) do
		if event.type == 12 and not added[event.tick] then
			added[event.tick] = true
			ticks[#ticks + 1] = event.tick
		end
	end
	table.sort(ticks)
	if ticks[1] ~= 0 then
		table.insert(ticks, 1, 0)
	end
	if #ticks == 1 then
		ticks[2] = ticks[1] + 1500
	end
	return ticks
end

---@param ticks integer[]
---@param tick integer
---@return chart.Fraction
local function tick_to_measure(ticks, tick)
	local index = 1
	for i = 1, #ticks do
		if ticks[i] <= tick then
			index = i
		else
			break
		end
	end
	local current_tick = ticks[index]
	local next_tick = ticks[index + 1] or (current_tick + (ticks[index] - ticks[index - 1]))
	local width = next_tick - current_tick
	if width <= 0 then
		width = 1500
	end
	return Fraction(index - 1, 1) + Fraction(tick - current_tick, width)
end

---@param side integer
---@param lane integer
---@return string
local function get_column(side, lane)
	if lane == 7 then
		return "scratch" .. side
	end
	return "key" .. (lane + 1 + (side - 1) * 7)
end

---@param event chart.iidx.Chart1Event
---@return boolean
local function is_playable_note(event)
	return (event.type == 0 or event.type == 1) and event.raw_lane <= 7
end

---@param event chart.iidx.Chart1Event
---@return boolean
local function is_note_sound(event)
	return (event.type == 2 or event.type == 3) and event.raw_lane <= 7 and event.value > 0
end

---@param event chart.iidx.Chart1Event
---@return boolean
local function is_bgm_note(event)
	return event.type == 7 and event.value > 0
end

---@param event chart.iidx.Chart1Event
---@return integer
local function get_side(event)
	return event.type == 1 and 2 or 1
end

---@param value integer
---@return number
local function normalize_bpm(value)
	if value > 1000 then
		return value / 100
	end
	return value
end

---@param event chart.iidx.Chart1Event
---@return chart.Fraction
local function get_signature(event)
	local denominator = event.raw_lane
	assert(denominator > 0, "invalid IIDX meter denominator")
	return Fraction(event.value * 4, denominator)
end

---@param side integer
---@param lane integer
---@return string
local function get_lane_sound_key(side, lane)
	return ("%s:%s"):format(side, lane)
end

---@class chart.iidx.DecodeContext
---@field filename string?
---@field song_id integer?
---@field iidx_song chart.iidx.MusicDbEntry?
---@field selected_index integer?

---@param name string?
---@return string?
local function get_bga_resource_name(name)
	if not name or name == "" then
		return nil
	end
	if name:match("%.([^%.]+)$") then
		return name
	end
	return name .. ".mp4"
end

---@param delay integer?
---@param tempo number
---@return chart.Fraction
local function get_bga_measure_time(delay, tempo)
	if not delay or delay == 0 then
		return Fraction(0)
	end
	local seconds = delay / 60
	local measures = seconds * tempo / 240
	return Fraction(measures, 10000, "round")
end

---@param s string
---@param hash string?
---@param context chart.iidx.DecodeContext?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}[]
function ChartDecoder:decode(s, hash, context)
	self.hash = hash
	context = context or {}

	local song_id = context.song_id or song_id_from_filename(context.filename or "")

	local chart_data = get_chart_data(context.filename or "", s, song_id)
	local chart1 = Chart1.parse(chart_data)

	---@type {chart: chart.Chart, chartmeta: sea.Chartmeta}[]
	local out = {}
	local out_index = 0
	for _, variation in ipairs(variations) do
		local section = chart1.sections[variation.section]
		local song = context.iidx_song
		if section and #section.events > 0 then
			out_index = out_index + 1
			if not context.selected_index or out_index == context.selected_index then
				local chart = self:decodeSection(section, variation, song)
				add_audio_resources(song_id, chart, song, variation)
				local chartmeta = self:getChartmeta(out_index, song_id, song, variation, chart)
				out[#out + 1] = {
					chart = chart,
					chartmeta = chartmeta,
				}
				if context.selected_index then
					break
				end
			end
		end
	end

	return out
end

---@param section chart.iidx.Chart1Section
---@param variation chart.iidx.ChartVariation
---@param song chart.iidx.MusicDbEntry?
---@return chart.Chart
function ChartDecoder:decodeSection(section, variation, song)
	local chart = Chart()
	chart.inputMode = variation.inputMode

	local layer = MeasureLayer()
	chart.layers.main = layer

	local visual = Visual()
	layer.visuals.main = visual
	local visualColumns = VisualColumns(visual)

	local visual_bga = Visual()
	visual_bga.bga = true
	layer.visuals.bga = visual_bga
	local visual_bga_columns = VisualColumns(visual_bga, false)

	local ticks = get_measure_ticks(section.events)
	local max_measure = 0

	local first_bpm = nil
	for _, event in ipairs(section.events) do
		if event.type == 4 then
			first_bpm = normalize_bpm(event.value)
			break
		end
	end
	layer:getPoint(Fraction(0))._tempo = Tempo(first_bpm or 120)
	layer:getPoint(Fraction(0))._signature = Signature()
	visual:getPoint(layer:getPoint(Fraction(0)))
	visual_bga:getPoint(layer:getPoint(Fraction(0)))

	local bga_name = get_bga_resource_name(song and song.bga_filename)
	if bga_name then
		local point = layer:getPoint(get_bga_measure_time(song.bga_delay, first_bpm or 120))
		local note = Note(visual_bga_columns:getPoint(point, "bga"), "bga", "sprite")
		note.data.images = {{bga_name, 1}}
		chart.notes:insert(note)
		chart.resources:add("image", bga_name)
		visual_bga:getPoint(point)
	end

	for _, tick in ipairs(ticks) do
		local measure = tick_to_measure(ticks, tick)
		if measure:tonumber() > max_measure then
			max_measure = measure:tonumber()
		end
		local point = layer:getPoint(measure)
		visual:getPoint(point)
		visual_bga:getPoint(point)
	end

	---@type {[string]: chart.iidx.Chart1Event[]}
	local note_sounds = {}
	for _, event in ipairs(section.events) do
		if is_note_sound(event) then
			local side = event.type == 3 and 2 or 1
			local key = get_lane_sound_key(side, event.raw_lane)
			local sounds = note_sounds[key]
			if not sounds then
				sounds = {}
				note_sounds[key] = sounds
			end
			sounds[#sounds + 1] = event
		end
	end
	for _, sounds in pairs(note_sounds) do
		table.sort(sounds, function(a, b)
			return a.tick < b.tick
		end)
	end

	---@type {[string]: integer}
	local inherited_sounds = {}

	for _, event in ipairs(section.events) do
		if event.type == 4 then
			local point = layer:getPoint(tick_to_measure(ticks, event.tick))
			point._tempo = Tempo(normalize_bpm(event.value))
			visual:getPoint(point)
		elseif event.type == 5 then
			local point = layer:getPoint(tick_to_measure(ticks, event.tick))
			point._signature = Signature(get_signature(event))
			visual:getPoint(point)
		elseif is_playable_note(event) then
			local point = layer:getPoint(tick_to_measure(ticks, event.tick))
			local column = get_column(get_side(event), event.raw_lane)
			local note = Note(visualColumns:getPoint(point, column), column, "tap")
			local queued_sounds = note_sounds[get_lane_sound_key(get_side(event), event.raw_lane)]
			---@type [string, number][]?
			local sounds
			local inherited_key = get_lane_sound_key(get_side(event), event.raw_lane)
			while queued_sounds and queued_sounds[1] and queued_sounds[1].tick <= event.tick do
				local sound_event = table.remove(queued_sounds, 1)
				sounds = sounds or {}
				sounds[#sounds + 1] = {tostring(sound_event.value), 1}
				inherited_sounds[inherited_key] = sound_event.value
			end
			if sounds then
				note.data.sounds = sounds
			elseif event.value > 0 then
				note.data.sounds = {{tostring(event.value), 1}}
				inherited_sounds[inherited_key] = event.value
			elseif inherited_sounds[inherited_key] then
				note.data.sounds = {{tostring(inherited_sounds[inherited_key]), 1}}
			end
			chart.notes:insert(note)
			local measure = tick_to_measure(ticks, event.tick):tonumber()
			if measure > max_measure then
				max_measure = measure
			end
		elseif is_bgm_note(event) then
			local point = layer:getPoint(tick_to_measure(ticks, event.tick))
			local note = Note(visualColumns:getPoint(point, "auto"), "auto", "sample")
			note.data.sounds = {{tostring(event.value), 1}}
			chart.notes:insert(note)
		end
	end

	for i = 0, math.ceil(max_measure) do
		local point = layer:getPoint(Fraction(i))
		local note = Note(visualColumns:getPoint(point, "measure1"), "measure1", "shade")
		chart.notes:insert(note)
	end

	chart:compute()

	return chart
end

---@param index integer
---@param song_id integer
---@param song chart.iidx.MusicDbEntry?
---@param variation chart.iidx.ChartVariation
---@param chart chart.Chart
---@return sea.Chartmeta
function ChartDecoder:getChartmeta(index, song_id, song, variation, chart)
	local chartmeta = {
		hash = self.hash,
		index = index,
		format = "iidx",
		title = song and song.title or tostring(song_id),
		title_unicode = song and song.title or tostring(song_id),
		artist = song and song.artist or nil,
		artist_unicode = song and song.artist or nil,
		source = song and song.genre or nil,
		name = variation.name,
		level = song and song.levels and song.levels[variation.name] or nil,
		inputmode = tostring(chart.inputMode),
	}
	setmetatable(chartmeta, Chartmeta)
	---@cast chartmeta sea.Chartmeta
	assert(chartmeta:validate())
	return chartmeta
end

return ChartDecoder
