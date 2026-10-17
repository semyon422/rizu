local path_util = require("path_util")
local QueryFragments = require("rizu.library.sql.QueryFragments")

---@type rdb.ModelOptions
local located_chartfiles = {}

located_chartfiles.subquery = "SELECT "
	.. "chartmetas.id AS chartmeta_id, chartmetas.mode AS chartmeta_mode, "
	.. QueryFragments.FIELDS_CHARTFILE_SET .. ", "
	.. "chartfiles.name AS chartfile_name, "
	.. [[
chartfiles.*
FROM chartfiles
INNER JOIN chartfile_sets ON
chartfiles.set_id = chartfile_sets.id
LEFT JOIN chartmetas ON
chartfiles.hash = chartmetas.hash
]]

located_chartfiles.types = {
	set_is_file = "boolean",
}

located_chartfiles.relations = {}

function located_chartfiles:from_db()
	local dir = self.set_dir
	if not self.set_is_file then
		dir = path_util.join(dir, self.set_name)
	end
	self.dir = dir
	self.path = path_util.join(dir, self.chartfile_name)
end

return located_chartfiles
