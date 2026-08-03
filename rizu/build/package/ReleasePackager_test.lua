local ReleasePackager = require("rizu.build.package.ReleasePackager")
local package_config = require("rizu.build.package.config")

local test = {}

local function listingWithRequiredPaths()
	local paths = {"./"}
	for _, path in ipairs(ReleasePackager.SERVER_REQUIRED_PATHS) do
		table.insert(paths, "./" .. path)
	end
	return table.concat(paths, "\n")
end

---@param t testing.T
function test.valid_server_listing(t)
	t:has_not_error(function()
		ReleasePackager.validateServerListing(listingWithRequiredPaths())
	end)
end

---@param t testing.T
function test.missing_server_runtime_is_rejected(t)
	local listing = listingWithRequiredPaths():gsub("./bin/linux64/libsqlite3.so\n?", "")
	t:has_error(function()
		ReleasePackager.validateServerListing(listing)
	end)
end

---@param t testing.T
function test.runtime_state_and_configuration_are_rejected(t)
	for _, forbidden_path in ipairs(ReleasePackager.SERVER_FORBIDDEN_PATHS) do
		t:has_error(function()
			ReleasePackager.validateServerListing(listingWithRequiredPaths() .. "\n./" .. forbidden_path .. "/private")
		end)
	end
end

---@param t testing.T
function test.similarly_named_examples_are_allowed(t)
	t:has_not_error(function()
		ReleasePackager.validateServerListing(listingWithRequiredPaths() .. "\n./nginx_config.example.lua")
	end)
end

---@param t testing.T
function test.client_source_directories_exist(t)
	for _, path in ipairs(package_config.repo.include) do
		t:assert(io.open(path) ~= nil, "missing client source directory: " .. path)
	end
end

return test
