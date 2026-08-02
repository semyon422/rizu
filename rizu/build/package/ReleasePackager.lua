local class = require("class")
local json = require("json")

---@class rizu.build.package.ReleaseArtifact
---@field path string
---@field sha256 string
---@field size integer

---@class rizu.build.package.ReleaseManifest
---@field format_version integer
---@field commit string
---@field built_at string
---@field artifacts {[string]: rizu.build.package.ReleaseArtifact}

---@class rizu.build.package.ReleasePackager
---@operator call: rizu.build.package.ReleasePackager
---@field ctx rizu.build.Context
local ReleasePackager = class()

ReleasePackager.SERVER_RUNTIME_PATHS = {
	"bin/linux64/lib7z.so",
	"bin/linux64/libiconv.so",
	"bin/linux64/libminacalc.so",
	"bin/linux64/libsqlite3.so",
	"tree/lib/lua/5.1",
	"tree/share/lua/5.1",
}

ReleasePackager.SERVER_REQUIRED_PATHS = {
	"sea/app/handler.lua",
	"docker/entrypoint.sh",
	"compose.yaml",
	"luajit",
	"luajit.lua",
	"pkg_config.lua",
	"bin/linux64/lib7z.so",
	"bin/linux64/libiconv.so",
	"bin/linux64/libminacalc.so",
	"bin/linux64/libsqlite3.so",
	"tree/lib/lua/5.1/bcrypt.so",
	"tree/share/lua/5.1/resty/nats/client.lua",
	"release.json",
}

ReleasePackager.SERVER_FORBIDDEN_PATHS = {
	"app_config.lua",
	"nginx.conf",
	"nginx_config.lua",
	"server.db",
	"storages",
	"logs",
	"temp",
	"userdata",
	"server-state",
}

---@param ctx rizu.build.Context
function ReleasePackager:new(ctx)
	self.ctx = ctx
end

---@return string
function ReleasePackager:getCommit()
	local commit = self.ctx.shell:popen("git rev-parse HEAD")
	commit = commit and commit:match("^%s*([0-9a-fA-F]+)")
	assert(commit and #commit == 40, "failed to read the Git commit")
	return commit:lower()
end

---@param listing string
---@return {[string]: true}
function ReleasePackager.parseListing(listing)
	---@type {[string]: true}
	local paths = {}
	for path in listing:gmatch("[^\r\n]+") do
		path = path:gsub("^%./", ""):gsub("/$", "")
		if path ~= "" and path ~= "." then
			paths[path] = true
		end
	end
	return paths
end

---@param listing string
function ReleasePackager.validateServerListing(listing)
	local paths = ReleasePackager.parseListing(listing)
	for _, path in ipairs(ReleasePackager.SERVER_REQUIRED_PATHS) do
		assert(paths[path], "server archive is missing required path: " .. path)
	end
	for archive_path in pairs(paths) do
		for _, forbidden_path in ipairs(ReleasePackager.SERVER_FORBIDDEN_PATHS) do
			local is_forbidden = archive_path == forbidden_path or archive_path:sub(1, #forbidden_path + 1) == forbidden_path .. "/"
			assert(not is_forbidden, "server archive contains runtime state or configuration: " .. archive_path)
		end
	end
end

---@param path string
---@return rizu.build.package.ReleaseArtifact
function ReleasePackager:getArtifact(path)
	local sha256 = self.ctx.shell:popen(string.format("sha256sum %q | cut -d ' ' -f1", path))
	sha256 = sha256 and sha256:match("^%s*([0-9a-fA-F]+)")
	assert(sha256 and #sha256 == 64, "failed to checksum artifact: " .. path)

	local size_output = self.ctx.shell:popen(string.format("wc -c < %q", path))
	local size = size_output and tonumber(size_output:match("%d+"))
	assert(size, "failed to read artifact size: " .. path)

	return {
		path = path:match("([^/]+)$") or path,
		sha256 = sha256:lower(),
		size = size,
	}
end

---@param path string
---@param manifest rizu.build.package.ReleaseManifest
function ReleasePackager:writeManifest(path, manifest)
	assert(self.ctx.fs:write(path, json.encode(manifest)))
end

function ReleasePackager:build()
	local commit = self:getCommit()
	local release_root = "build/release"
	local release_dir = release_root .. "/" .. commit
	local staging_dir = release_root .. "/." .. commit .. ".tmp"
	local server_dir = staging_dir .. "/server"
	local server_archive = staging_dir .. "/server.tar.gz"

	self.ctx.shell:execute(string.format("rm -rf %q %q", staging_dir, release_dir))
	self.ctx.shell:execute(string.format("mkdir -p %q", server_dir))

	local export_command = table.concat({
		"git ls-files --recurse-submodules -z",
		string.format("tar --exclude=%q --exclude=%q --null --files-from=- -cf -", "userdata", "temp"),
		string.format("tar -xf - -C %q", server_dir),
	}, " | ")
	self.ctx.shell:execute(export_command)

	for _, path in ipairs(ReleasePackager.SERVER_RUNTIME_PATHS) do
		assert(self.ctx.fs:getInfo(path), "missing server runtime path: " .. path)
		local parent = path:match("^(.+)/[^/]+$")
		assert(parent, "invalid server runtime path: " .. path)
		self.ctx.shell:execute(string.format("mkdir -p %q && cp -a %q %q", server_dir .. "/" .. parent, path, server_dir .. "/" .. path))
	end

	local built_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
	---@type rizu.build.package.ReleaseManifest
	local server_manifest = {
		format_version = 1,
		commit = commit,
		built_at = built_at,
		artifacts = {},
	}
	self:writeManifest(server_dir .. "/release.json", server_manifest)

	self.ctx.shell:execute(string.format("tar --sort=name --owner=0 --group=0 --numeric-owner -cf - -C %q . | gzip -n > %q", server_dir, server_archive))
	local listing = self.ctx.shell:popen(string.format("tar -tzf %q", server_archive))
	assert(listing, "failed to list server archive")
	ReleasePackager.validateServerListing(listing)

	local client_artifacts = {
		files = "build/repo/files.json",
		zip = "build/repo/rizu.zip",
		macos_zip = "build/repo/rizu_macos.zip",
	}
	assert(self.ctx.fs:getInfo("build/repo/rizu"), "missing client repository: build/repo/rizu")
	for _, path in pairs(client_artifacts) do
		assert(self.ctx.fs:getInfo(path), "missing client artifact: " .. path)
	end

	self.ctx.shell:execute(string.format("cp -a %q %q", "build/repo/rizu", staging_dir .. "/rizu"))
	for _, path in pairs(client_artifacts) do
		self.ctx.shell:execute(string.format("cp -a %q %q", path, staging_dir .. "/"))
	end

	---@type rizu.build.package.ReleaseManifest
	local release_manifest = {
		format_version = 1,
		commit = commit,
		built_at = built_at,
		artifacts = {
			server = self:getArtifact(server_archive),
			files = self:getArtifact(staging_dir .. "/files.json"),
			zip = self:getArtifact(staging_dir .. "/rizu.zip"),
			macos_zip = self:getArtifact(staging_dir .. "/rizu_macos.zip"),
		},
	}
	self:writeManifest(staging_dir .. "/release.json", release_manifest)

	self.ctx.shell:execute(string.format("rm -rf %q && mv %q %q", server_dir, staging_dir, release_dir))
	print("Release artifact: " .. release_dir)
end

return ReleasePackager
