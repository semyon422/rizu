local Modifier = require("sphere.models.ModifierModel.Modifier")
local Notes = require("chart.model.notes.Notes")
local Note = require("chart.model.notes.Note")

---@class sphere.FullLongNote: sphere.Modifier
---@operator call: sphere.FullLongNote
local FullLongNote = Modifier + {}

FullLongNote.name = "FullLongNote"
FullLongNote.point_theshold = 0.005

FullLongNote.defaultValue = 0
FullLongNote.values = {0, 1, 2, 3}

FullLongNote.description = "Replace short notes with long notes"

---@param config table
---@return string
---@return string
function FullLongNote:getString(config)
	return "FLN", tostring(config.value)
end

---@param config table
---@param chart chart.Chart
function FullLongNote:apply(config, chart)
	self.chart = chart
	self.level = config.value

	local notes = chart.notes.notes
	local max_n = #notes
	for i = 1, max_n do
		self:processNote(i, notes[i], max_n)
	end

	chart:compute()
end

---@param i number
---@param n chart.Note
---@param max_n integer
function FullLongNote:processNote(i, n, max_n)
	if n.type ~= "tap" then
		return
	end

	---@type {[chart.IVisualPoint]: true}
	local vp_map = {}
	local notes = self.chart.notes.notes
	local _n
	for j = i + 1, max_n do
		_n = notes[j]
		vp_map[_n.visualPoint] = true
		if _n.column == n.column then
			break
		end
	end

	if not next(vp_map) then
		return
	end

	local vps = {}
	for vp in pairs(vp_map) do
		table.insert(vps, vp)
	end
	table.sort(vps)
	vps = self:cleanTimePointList(vps, n, _n)

	---@type chart.IVisualPoint
	local end_vp
	local level = self.level
	if level >= 3 then
		end_vp = vps[#vps]
	elseif level >= 2 and #vps >= 3 then
		end_vp = vps[math.ceil(#vps / 2)]
	elseif level >= 1 and #vps >= 2 then
		end_vp = vps[2]
	elseif level >= 0 and #vps >= 1 then
		end_vp = vps[1]
	end

	if not end_vp then
		return
	end

	n.type = "hold"
	n.weight = 1

	local endNote = Note(end_vp, n.column, "hold", -1)
	self.chart.notes:insert(endNote)
end

---@param vps chart.IVisualPoint[]
---@param n chart.Note
---@param _n chart.Note?
---@return chart.IVisualPoint[]
function FullLongNote:cleanTimePointList(vps, n, _n)
	local min_time = n.visualPoint.point.absoluteTime
	local max_time = _n and _n.visualPoint.point.absoluteTime or math.huge
	local th = self.point_theshold

	local filtered = {vps[1]}

	for i = 2, #vps do
		if vps[i].point.absoluteTime - filtered[#filtered].point.absoluteTime >= th then
			table.insert(filtered, vps[i])
		end
	end

	local out = {}

	for _, vp in ipairs(filtered) do
		local t = vp.point.absoluteTime
		if t - min_time >= th and max_time - t >= th then
			table.insert(out, vp)
		end
	end

	return out
end

return FullLongNote
