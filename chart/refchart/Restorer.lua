local class = require("class")
local table_util = require("table_util")
local Fraction = require("chart.core.Fraction")
local InputMode = require("chart.core.InputMode")
local Chart = require("chart.model.Chart")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Note = require("chart.model.notes.Note")
local Tempo = require("chart.model.to.Tempo")
local Measure = require("chart.model.to.Measure")
local Visual = require("chart.model.visual.Visual")
local Expand = require("chart.model.visual.Expand")
local Velocity = require("chart.model.visual.Velocity")

---@class refchart.Restorer
---@operator call: refchart.Restorer
local Restorer = class()

---@param refchart refchart.RefChart
---@return chart.Chart
function Restorer:restore(refchart)
	local chart = Chart()

	chart.inputMode = InputMode(refchart.inputmode)

	---@type {[string]: {[string]: chart.VisualPoint[]}}
	local ps = {}

	for l_name, _layer in pairs(refchart.layers) do
		local layer = AbsoluteLayer()
		chart.layers[l_name] = layer

		---@type chart.AbsolutePoint[]
		local points = {}

		for i, _p in ipairs(_layer.points) do
			local p = layer:getPoint(_p.time)
			points[i] = p
			if _p.tempo then
				p._tempo = Tempo(_p.tempo)
			end
			if _p.measure then
				p._measure = Measure(Fraction(_p.measure))
			end
		end

		ps[l_name] = ps[l_name] or {}
		local vps = ps[l_name]

		for v_name, _visual in pairs(_layer.visuals) do
			vps[v_name] = vps[v_name] or {}
			local vis = vps[v_name]

			local visual = Visual()
			layer.visuals[v_name] = visual

			visual.primaryTempo = _visual.primaryTempo
			visual.tempoMultiplyTarget = _visual.tempoMultiplyTarget
			visual.bga = _visual.bga

			for j, _vp in ipairs(_visual.points) do
				local p = points[_vp.point]
				local vp = visual:newPoint(p)
				vis[j] = vp
				if _vp.velocity then
					vp._velocity = Velocity(unpack(_vp.velocity))
				end
				if _vp.expand then
					vp._expand = Expand(_vp.expand)
				end
			end
		end
	end

	for _, _note in ipairs(refchart.notes) do
		local vp_ref = _note.point
		local vp = ps[vp_ref.layer][vp_ref.visual][vp_ref.index]
		local note = Note(vp, _note.column, _note.type, _note.weight, table_util.deepcopy(_note.data))
		chart.notes:insert(note)
	end

	for _, res in ipairs(refchart.resources) do
		chart.resources:add(unpack(res))
	end

	chart:compute()

	return chart
end

return Restorer
