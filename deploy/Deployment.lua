local class = require("class")
local json = require("json")

---@class deploy.Config
---@field root string
---@field artifact_root string
---@field compose_file string
---@field compose_command string
---@field retain integer
---@field health_attempts integer
---@field health_interval integer

---@class deploy.ManifestArtifact
---@field path string
---@field sha256 string
---@field size integer

---@class deploy.Manifest
---@field format_version integer
---@field commit string
---@field artifacts {[string]: deploy.ManifestArtifact}

---@class deploy.Deployment
---@operator call: deploy.Deployment
---@field shell rizu.build.IShell
---@field config deploy.Config
local Deployment = class()

Deployment.ARTIFACTS = {"server", "files", "zip", "macos_zip"}

local function quote(value)
	return string.format("%q", value)
end

---@param path string
---@return string
local function dirname(path)
	return path:match("^(.+)/[^/]+$") or "."
end

---@param shell rizu.build.IShell
---@param config deploy.Config
function Deployment:new(shell, config)
	self.shell = shell
	self.config = config
end

---@param path string
---@return string
function Deployment:absolute(path)
	assert(path ~= "", "path must not be empty")
	if path:sub(1, 1) == "/" then
		return path
	end
	local cwd = assert(io.popen("pwd -P")):read("*l")
	if path == "." then
		return cwd
	end
	return cwd .. "/" .. path
end

---@param path string
---@return deploy.Manifest
function Deployment:readManifest(path)
	local file = assert(io.open(path, "rb"), "missing release manifest: " .. path)
	local content = file:read("*a")
	file:close()
	local manifest = json.decode(content)
	assert(type(manifest) == "table" and manifest.format_version == 1, "unsupported release manifest")
	assert(type(manifest.commit) == "string" and manifest.commit:match("^[0-9a-f]+$") and #manifest.commit == 40,
		"invalid release commit")
	assert(type(manifest.artifacts) == "table", "release manifest has no artifacts")
	return manifest
end

---@param release_dir string
---@param manifest deploy.Manifest
function Deployment:verifyRelease(release_dir, manifest)
	for _, name in ipairs(self.ARTIFACTS) do
		local artifact = assert(manifest.artifacts[name], "release manifest is missing artifact: " .. name)
		assert(type(artifact.path) == "string" and not artifact.path:find("/", 1, true), "invalid artifact path: " .. name)
		assert(type(artifact.sha256) == "string" and #artifact.sha256 == 64, "invalid artifact checksum: " .. name)
		assert(type(artifact.size) == "number", "invalid artifact size: " .. name)
		local path = release_dir .. "/" .. artifact.path
		local command = table.concat({
			"test -f " .. quote(path),
			"test \"$(wc -c < " .. quote(path) .. ")\" -eq " .. quote(tostring(artifact.size)),
			"printf '%s  %s\\n' " .. quote(artifact.sha256) .. " " .. quote(path) .. " | sha256sum -c - >/dev/null",
		}, " && ")
		self.shell:execute(command)
	end
end

---@param command "deploy"|"rollback"|"build-deploy"
---@param argument? string
function Deployment:runLocked(command, argument)
	local args = {quote(self.config.root .. "/deploy.lua"), quote(command)}
	if argument then table.insert(args, quote(argument)) end
	self.shell:execute("mkdir -p " .. quote(self.config.root) .. " && RIZU_DEPLOY_LOCKED=1 flock --nonblock " .. quote(self.config.root .. "/.deploy.lock") .. " " .. table.concat(args, " "))
end

---@param commit string
function Deployment:prepareCommit(commit)
	assert(commit:match("^[0-9a-f]+$") and #commit == 40, "commit must be a full lowercase SHA")
	self.shell:execute("test -z \"$(git status --porcelain --untracked-files=no)\"")
	self.shell:execute("git fetch --no-tags origin " .. quote(commit))
	self.shell:execute("git cat-file -e " .. quote(commit .. "^{commit}"))
	self.shell:execute("git checkout --detach " .. quote(commit))
	self.shell:execute("git submodule update --init --recursive")
	self.shell:execute("test -z \"$(git status --porcelain --untracked-files=no)\"")
	local head_output = self.shell:popen("git rev-parse HEAD")
	local head = head_output and head_output:match("^%s*([0-9a-f]+)")
	assert(head == commit, "checked out commit does not match requested commit")
end

---@param commit string
function Deployment:buildDeploy(commit)
	self:prepareCommit(commit)
	self.shell:execute(os.getenv("RIZU_DEPLOY_TEST_COMMAND") or "./test")
	self.shell:execute("./rizu/build/make.lua release")
	self:deploy(commit)
end

function Deployment:prepareRoot()
	local root = self.config.root
	self.shell:execute("mkdir -p " .. table.concat({
		quote(root .. "/releases"),
		quote(root .. "/server-state/storages"),
		quote(root .. "/server-state/logs"),
		quote(root .. "/server-state/temp"),
		quote(root .. "/public/releases"),
	}, " "))
	for _, name in ipairs({"app_config.lua", "bancho_config.lua", "nginx.conf", "nginx_config.lua"}) do
		self.shell:execute("test -f " .. quote(root .. "/server-state/" .. name))
	end
end

---@param release_dir string
---@param commit string
---@return string candidate
function Deployment:stageServer(release_dir, commit)
	local releases = self.config.root .. "/releases"
	local candidate = releases .. "/" .. commit
	local staging = releases .. "/." .. commit .. ".tmp"
	self.shell:execute("rm -rf " .. quote(staging) .. " && mkdir -p " .. quote(staging))
	self.shell:execute("tar -xzf " .. quote(release_dir .. "/server.tar.gz") .. " -C " .. quote(staging))
	local internal = self:readManifest(staging .. "/release.json")
	assert(internal.commit == commit, "server archive commit does not match outer manifest")
	self.shell:execute("rm -rf " .. quote(candidate) .. " && mv " .. quote(staging) .. " " .. quote(candidate))
	return candidate
end

---@param path string
---@return string?
function Deployment:readLink(path)
	local output = self.shell:popen("test -L " .. quote(path) .. " && readlink -f " .. quote(path))
	local target = output and output:match("^%s*(.-)%s*$") or nil
	return target ~= "" and target or nil
end

---@param app_dir string
---@return string
function Deployment:composeCommand(app_dir)
	local root = self.config.root
	return table.concat({
		"RIZU_APP_DIR=" .. quote(app_dir),
		"RIZU_SERVER_STATE_PATH=" .. quote(root .. "/server-state"),
		"RIZU_UID=" .. quote(assert(self.shell:popen("id -u")):match("%d+")),
		"RIZU_GID=" .. quote(assert(self.shell:popen("id -g")):match("%d+")),
		self.config.compose_command .. " -p rizu -f " .. quote(self.config.compose_file),
	}, " ")
end

---@param app_dir string
function Deployment:ensureNats(app_dir)
	self.shell:execute(self:composeCommand(app_dir) .. " up --detach --pull missing --no-build nats")
end

---@param app_dir string
function Deployment:startOpenResty(app_dir)
	self.shell:execute(self:composeCommand(app_dir) .. " up --detach --force-recreate --pull missing --no-build --no-deps openresty")
end

---@param app_dir string
---@return boolean
function Deployment:waitHealthy(app_dir)
	local compose = self:composeCommand(app_dir)
	for _ = 1, self.config.health_attempts do
		local status = self.shell:popen(compose .. " ps --format json openresty | grep -q '\"Health\":\"healthy\"' && echo healthy || true")
		if status and status:find("healthy", 1, true) then
			return true
		end
		self.shell:execute("sleep " .. tostring(self.config.health_interval))
	end
	return false
end

---@param candidate string
---@param previous string?
function Deployment:activateServer(candidate, previous)
	self:startOpenResty(candidate)
	if self:waitHealthy(candidate) then
		return
	end
	if previous and previous ~= "" then
		self:startOpenResty(previous)
		assert(self:waitHealthy(previous), "candidate failed health check and previous release could not be restored")
	else
		self.shell:execute(self:composeCommand(candidate) .. " stop openresty")
	end
	error("candidate failed OpenResty health check")
end

---@param link string
---@param target string
function Deployment:switchLink(link, target)
	self.shell:execute("mkdir -p " .. quote(dirname(link)) .. " && ln -sfn " .. quote(target) .. " " .. quote(link .. ".tmp") .. " && mv -Tf " .. quote(link .. ".tmp") .. " " .. quote(link))
end

---@param release_dir string
---@param commit string
function Deployment:publishClient(release_dir, commit)
	local public_root = self.config.root .. "/public"
	local target = public_root .. "/releases/" .. commit
	local staging = public_root .. "/releases/." .. commit .. ".tmp"
	self.shell:execute("rm -rf " .. quote(staging) .. " && mkdir -p " .. quote(staging))
	self.shell:execute("cp -a " .. table.concat({
		quote(release_dir .. "/rizu"),
		quote(release_dir .. "/files.json"),
		quote(release_dir .. "/rizu.zip"),
		quote(release_dir .. "/rizu_macos.zip"),
		quote(staging .. "/"),
	}, " "))
	self.shell:execute("rm -rf " .. quote(target) .. " && mv " .. quote(staging) .. " " .. quote(target))
	self:switchLink(public_root .. "/current", target)
end

---@param current string
---@param previous string?
function Deployment:recordActivation(current, previous)
	local root = self.config.root
	if previous and previous ~= "" and previous ~= current then
		self:switchLink(root .. "/previous", previous)
	end
	self:switchLink(root .. "/current", current)
end

---@param output string?
---@return string?
local function cleanOutput(output)
	local value = output and output:match("^%s*(.-)%s*$") or nil
	return value ~= "" and value or nil
end

---@return string mode
---@return string? app_path
---@return string? state_path
---@return string? health
function Deployment:getStatus()
	local container = cleanOutput(self.shell:popen("docker inspect rizu-openresty-1 --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}'"))
	if container then
		local app_path = cleanOutput(self.shell:popen("docker inspect rizu-openresty-1 --format '{{range .Mounts}}{{if eq .Destination \"/app\"}}{{.Source}}{{end}}{{end}}'"))
		local state_path = cleanOutput(self.shell:popen("docker inspect rizu-openresty-1 --format '{{range .Mounts}}{{if eq .Destination \"/app/server-state\"}}{{.Source}}{{end}}{{end}}'"))
		local _, health = container:match("^([^|]+)|(.*)$")
		local releases_prefix = self.config.root .. "/releases/"
		local mode = app_path and app_path:sub(1, #releases_prefix) == releases_prefix and "release" or "checkout"
		return mode, app_path, state_path, health ~= "" and health or nil
	end
	local host_pid = cleanOutput(self.shell:popen("test -s " .. quote(self.config.root .. "/server-state/logs/nginx.pid") .. " && kill -0 $(cat " .. quote(self.config.root .. "/server-state/logs/nginx.pid") .. ") 2>/dev/null && echo running"))
	return host_pid and "host" or "stopped"
end

function Deployment:status()
	local mode, app_path, state_path, health = self:getStatus()
	print("Mode: " .. mode)
	if app_path then print("Application: " .. app_path) end
	if state_path then print("Server state: " .. state_path) end
	if health then print("Health: " .. health) end
	local current = self:readLink(self.config.root .. "/current")
	local public = self:readLink(self.config.root .. "/public/current")
	if current then
		print("Current: " .. current)
		local commit = current:match("/releases/([0-9a-f]+)$")
		if commit then print("Commit: " .. commit) end
	end
	if public then print("Public: " .. public) end
end

function Deployment:prune()
	local root = self.config.root
	local command = "ls -1dt " .. quote(root .. "/releases/") .. "[0-9a-f]* 2>/dev/null | tail -n +" .. tostring(self.config.retain + 1) .. " | while IFS= read -r path; do " ..
		"test \"$path\" = \"$(readlink -f " .. quote(root .. "/current") .. ")\" || " ..
		"test \"$path\" = \"$(readlink -f " .. quote(root .. "/previous") .. " 2>/dev/null)\" || rm -rf \"$path\"; done"
	self.shell:execute(command)
end

---@param commit_or_path string
function Deployment:deploy(commit_or_path)
	self:prepareRoot()
	local release_dir = commit_or_path:find("/", 1, true) and commit_or_path or self.config.artifact_root .. "/" .. commit_or_path
	release_dir = self:absolute(release_dir)
	local manifest = self:readManifest(release_dir .. "/release.json")
	if not commit_or_path:find("/", 1, true) then
		assert(manifest.commit == commit_or_path, "requested commit does not match release manifest")
	end
	self:verifyRelease(release_dir, manifest)
	local previous = self:readLink(self.config.root .. "/current")
	local candidate = self:stageServer(release_dir, manifest.commit)
	self:ensureNats(candidate)
	self:activateServer(candidate, previous)
	self:recordActivation(candidate, previous)
	self:publishClient(release_dir, manifest.commit)
	self:prune()
	print("Deployed release: " .. manifest.commit)
end

---@param commit? string
function Deployment:rollback(commit)
	self:prepareRoot()
	local current = self:readLink(self.config.root .. "/current")
	assert(current and current ~= "", "there is no active release")
	local target = commit and (self.config.root .. "/releases/" .. commit) or self:readLink(self.config.root .. "/previous")
	assert(target and target ~= "", "there is no previous release")
	self.shell:execute("test -d " .. quote(target))
	self:ensureNats(target)
	self:activateServer(target, current)
	self:recordActivation(target, current)
	local target_commit = assert(target:match("([0-9a-f]+)$"), "invalid rollback release path")
	local public_target = self.config.root .. "/public/releases/" .. target_commit
	self.shell:execute("test -d " .. quote(public_target))
	self:switchLink(self.config.root .. "/public/current", public_target)
	print("Rolled back to release: " .. target_commit)
end

return Deployment
