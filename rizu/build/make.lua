#!/usr/bin/env luajit

require("pkg_config")

local Cli = require("rizu.build.Cli")

---@type (string?)[]
local args = {...}
Cli.run(args)
