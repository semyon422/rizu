local GraphsGenerator = require("rizu.editor.analysis.GraphsGenerator")
local Layer = require("chart.chartedit.Layer")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

local tcf = TestChartFactory()

---@param t testing.T
function test.density_graph(t)
	local generator = GraphsGenerator()
	local res = tcf:create("4key", {
		{time = 0, column = 1},
		{time = 0.2, column = 1},
		{time = 1, column = 2},
	})

	generator:genDensityGraph(res.chart, 0, 2)

	t:eq(generator.densityGraph[0], 1)
	t:eq(generator.densityGraph[2], 0.5)
	t:eq(generator.densityGraph[4], 0)
end

---@param t testing.T
function test.density_graph_without_notes(t)
	local generator = GraphsGenerator()
	local res = tcf:create("4key", {})

	generator:genDensityGraph(res.chart, 0, 2)

	t:eq(generator.densityGraph[0], 0)
	t:eq(generator.densityGraph[4], 0)
end

---@param t testing.T
function test.vertices_graph(t)
	local generator = GraphsGenerator()
	local layer = Layer()
	layer.points:initDefault()

	generator:genVerticesGraph(layer, 0, 1)

	t:eq(generator.vertexDatasGraph.n, 2000)
	t:eq(generator.vertexDatasGraph[0], true)
	t:eq(generator.vertexDatasGraph[2000], true)
end

return test
