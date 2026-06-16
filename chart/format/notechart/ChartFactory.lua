local class = require("class")
local valid = require("valid")
local path_util = require("path_util")
local digest = require("digest")

---@class chart.ChartFactory
---@operator call: chart.ChartFactory
local ChartFactory = class()

ChartFactory.extensions = {
	"osu",
	"sph",
	"ojn",
	"bms",
	"bme",
	"bml",
	"pms",
	"sm",
	"ssc",
	"qua",
	"mid",
	"midi",
	"ksh",
	"1"
}

local ChartDecoders = {
	osu = require("chart.format.osu.ChartDecoder"),
	sph = require("chart.format.sph.ChartDecoder"),
	ojn = require("chart.format.o2jam.ChartDecoder"),
	bms = require("chart.format.bms.ChartDecoder"),
	bme = require("chart.format.bms.ChartDecoder"),
	bml = require("chart.format.bms.ChartDecoder"),
	pms = require("chart.format.bms.PmsChartDecoder"),
	sm = require("chart.format.stepmania.ChartDecoder"),
	ssc = require("chart.format.stepmania.SscChartDecoder"),
	qua = require("chart.format.quaver.ChartDecoder"),
	mid = require("chart.format.midi.ChartDecoder"),
	midi = require("chart.format.midi.ChartDecoder"),
	ksh = require("chart.format.ksm.ChartDecoder"),
	["1"] = require("chart.format.iidx.ChartDecoder"),
}

---@param filename string
---@return chart.IChartDecoder
function ChartFactory:getChartDecoder(filename)
	---@type chart.IChartDecoder
	local Decoder = assert(ChartDecoders[path_util.ext(filename, true)])
	return Decoder()
end

---@param filename string
---@param content string
---@param hash string?
---@param context table?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}[]?
---@return string?
function ChartFactory:getCharts(filename, content, hash, context)
	hash = hash or digest.hash("md5", content, true)
	context = context or {}
	context.filename = context.filename or filename

	---@type chart.IChartDecoder
	local decoder = assert(ChartDecoders[path_util.ext(filename, true)], filename)()

	local status, chart_chartmetas = xpcall(decoder.decode, debug.traceback, decoder, content, hash, context)
	if not status then
		---@cast chart_chartmetas -table, +string
		return valid.format(nil, chart_chartmetas)
	end

	for _, t in ipairs(chart_chartmetas) do
		if t.chartmeta.hash ~= hash then
			return nil, "invalid hash"
		end
	end

	return chart_chartmetas
end

return ChartFactory
