local chartplays = require("rizu.library.models.chartplays")

---@type rdb.ModelOptions
local chartplays_computable = {}

chartplays_computable.subquery = [[
SELECT DISTINCT
chartplays.*
FROM chartplays
INNER JOIN chartfiles ON
chartplays.hash = chartfiles.hash
]]

chartplays_computable.types = chartplays.types
chartplays_computable.relations = chartplays.relations
chartplays_computable.metatable = chartplays.metatable

return chartplays_computable
