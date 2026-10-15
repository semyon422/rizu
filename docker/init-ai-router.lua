local random = require("web.random")
local stbl = require("stbl")

-- The caller creates a private directory and uses noclobber + umask 077 for output.
local config = assert(loadfile("docker/ai-router-config.example.lua"))()
config.admin_password = random.hex(32)
config.mcp_token = random.hex(32)
io.write("return ", stbl.encode_pretty(config), "\n")
