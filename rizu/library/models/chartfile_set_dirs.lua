---@type rdb.ModelOptions
local chartfile_set_dirs = {}

chartfile_set_dirs.subquery = [[
SELECT DISTINCT `dir`, `location_id` FROM `chartfile_sets`
]]

return chartfile_set_dirs
