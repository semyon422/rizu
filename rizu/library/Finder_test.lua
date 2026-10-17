local Finder = require("rizu.library.Finder")
local path_util = require("path_util")

local test = {}

---@class rizu.library.FinderTestItem
---@field type "directory"|"file"
---@field cached boolean?
---@field [integer] string

---@alias rizu.library.FinderTestItems {[string]: rizu.library.FinderTestItem}

---@param prefix string?
---@param dir string?
---@return rizu.library.FinderTestItems
---@return rizu.library.FinderIterator
local function get_files(prefix, dir)
	---@type rizu.library.FinderTestItems
	local items = {
		["root"] = {
			type = "directory",
			"rel_charts",
			"unrel_charts",
		},
		["root/rel_charts"] = {
			type = "directory",
			"chartset",
		},
		["root/rel_charts/chartset"] = {
			type = "directory",
			"chart.osu",
		},
		["root/rel_charts/chartset/chart.osu"] = {
			type = "file",
		},
		["root/unrel_charts"] = {
			type = "directory",
			"chart.ojn",
		},
		["root/unrel_charts/chart.ojn"] = {
			type = "file",
		},
	}
	---@type fs.IFilesystem
	local fs = {}
	function fs:getDirectoryItems(path)
		return items[path]
	end
	function fs:getInfo(path)
		return items[path]
	end

	local ncf = Finder(fs)
	local iterator = ncf:iter(prefix, dir)

	return items, iterator
end

---@param items rizu.library.FinderTestItems
---@param iterator rizu.library.FinderIterator
---@param prefix string?
---@return string[] chartfile_sets
---@return string[] chartfiles
local function iter(items, iterator, prefix)
	---@type string[]
	local chartfile_sets = {}
	---@type string[]
	local chartfiles = {}

	local typ, dir, item, modtime = iterator()
	while typ do
		local path = path_util.join(prefix, dir)
		local path_np = dir
		if type(item) == "string" then
			path = path_util.join(prefix, dir, item)
			path_np = path_util.join(dir, item)
		end
		local not_cached = not assert(items[path]).cached
		---@type boolean?
		local res
		if typ == "related_dir" then
			table.insert(chartfile_sets, assert(path_np))
		elseif typ == "related" then
			if not_cached then
				table.insert(chartfiles, assert(path_np))
			end
		elseif typ == "unrelated_dir" then
		elseif typ == "unrelated" then
			if not_cached then
				table.insert(chartfile_sets, assert(path_np))
				table.insert(chartfiles, assert(path_np))
			end
		elseif typ == "directory_dir" then
		elseif typ == "directory" then
			res = not_cached
		elseif typ == "not_found" then
		end
		typ, dir, item, modtime = iterator(res)
	end

	return chartfile_sets, chartfiles
end

---@param t testing.T
function test.not_cached(t)
	local items, iterator = get_files(nil, "root")
	local chartfile_sets, chartfiles = iter(items, iterator, nil)

	t:teq(chartfile_sets, {
		"root/rel_charts/chartset",
		"root/unrel_charts/chart.ojn",
	})
	t:teq(chartfiles, {
		"root/rel_charts/chartset/chart.osu",
		"root/unrel_charts/chart.ojn",
	})
end

---@param t testing.T
function test.chartsets_cached(t)
	local items, iterator = get_files(nil, "root")
	items["root/rel_charts/chartset"].cached = true
	items["root/unrel_charts/chart.ojn"].cached = true

	local chartfile_sets, chartfiles = iter(items, iterator, nil)

	t:teq(chartfile_sets, {})
	t:teq(chartfiles, {})
end

---@param t testing.T
function test.new_charts(t)
	local items, iterator = get_files(nil, "root")
	items["root/rel_charts/chartset/chart.osu"].cached = true
	items["root/unrel_charts/chart.ojn"].cached = true

	items["root/rel_charts/chartset/chart2.osu"] = {type = "file"}
	table.insert(items["root/rel_charts/chartset"], "chart2.osu")

	items["root/unrel_charts/chart2.ojn"] = {type = "file"}
	table.insert(items["root/unrel_charts"], "chart2.ojn")

	local chartfile_sets, chartfiles = iter(items, iterator, nil)

	t:teq(chartfile_sets, {
		"root/rel_charts/chartset",
		"root/unrel_charts/chart2.ojn",
	})
	t:teq(chartfiles, {
		"root/rel_charts/chartset/chart2.osu",
		"root/unrel_charts/chart2.ojn",
	})
end

---@param t testing.T
function test.not_cached_prefixed(t)
	local items, iterator = get_files("root", nil)
	local chartfile_sets, chartfiles = iter(items, iterator, "root")

	-- print(require("inspect")(chartfile_sets))
	t:teq(chartfile_sets, {
		"rel_charts/chartset",
		"unrel_charts/chart.ojn",
	})
	t:teq(chartfiles, {
		"rel_charts/chartset/chart.osu",
		"unrel_charts/chart.ojn",
	})
end

---@param t testing.T
function test.not_cached_prefixed_string(t)
	local items, iterator = get_files("root", "rel_charts")
	local chartfile_sets, chartfiles = iter(items, iterator, "root")

	-- print(require("inspect")(chartfile_sets))
	t:teq(chartfile_sets, {
		"rel_charts/chartset",
	})
	t:teq(chartfiles, {
		"rel_charts/chartset/chart.osu",
	})
end

return test
