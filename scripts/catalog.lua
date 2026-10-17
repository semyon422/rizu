#!/usr/bin/env luajit

--[[
Builds the remote catalog from a directory of charts: `<out>/catalog.sqlite` (and `.gz`) and the files it points to.

	./luajit scripts/catalog.lua --charts /media/SSD/s3_test/charts --out /media/SSD/s3_test

Run it again after adding charts: what is known is kept, and only new files are encoded.
The charts are measured by the game's own library code, so the catalog is a library database of the
mania charts. See `rizu/library/CatalogBuilder.lua`.

Options:
	--charts DIR   Directory of locations, each with a directory for every chart set. Default: <out>/charts
	--out DIR      Where the catalog and the files go. Default: the current directory
	--work FILE    The library the charts are measured into. Default: <out>/catalog-work.sqlite
	--ffmpeg PATH  Default: ffmpeg
]]

require("pkg_config")

local CatalogBuilder = require("rizu.library.CatalogBuilder")
local CatalogTools = require("rizu.library.CatalogTools")

local options = {}
local i = 1
while i <= #arg do
	local name = assert(arg[i]:match("^%-%-(.+)$"), "unknown argument " .. arg[i])
	options[name] = assert(arg[i + 1], "missing value for --" .. name)
	i = i + 2
end
for name in pairs(options) do
	assert(name == "charts" or name == "out" or name == "work" or name == "ffmpeg", "unknown option --" .. name)
end

local out_dir = options.out or "."
CatalogBuilder({
	charts_dir = options.charts or (out_dir .. "/charts"),
	out_dir = out_dir,
	work_path = options.work,
	tools = CatalogTools(options.ffmpeg),
}):run()
