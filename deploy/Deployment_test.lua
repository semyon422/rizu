local Deployment = require("deploy.Deployment")

local test = {}

local function createDeployment()
	local shell = {commands = {}, outputs = {}}
	function shell:execute(command)
		table.insert(self.commands, command)
		return true
	end
	function shell:popen(command)
		table.insert(self.commands, command)
		return self.outputs[command]
	end
	local deployment = Deployment(shell, {
		root = "/srv/rizu",
		artifact_root = "/artifacts",
		compose_file = "/repo/compose.yaml",
		compose_command = "docker compose",
		health_attempts = 2,
		health_interval = 1,
		auto_rollback = true,
		backup_before_deploy = false,
	})
	return deployment, shell
end

local function joinedCommands(shell)
	return table.concat(shell.commands, "\n")
end

---@param t testing.T
function test.lock_wraps_mutating_command(t)
	local deployment, shell = createDeployment()
	deployment:runLocked("build-deploy", string.rep("a", 40))
	local command = shell.commands[1]
	t:assert(command:find("flock --wait 7200", 1, true))
	t:assert(command:find('RIZU_DEPLOY_LOCKED=1', 1, true))
	t:assert(command:find('"/srv/rizu/deploy.lua" "build-deploy"', 1, true))
end

---@param t testing.T
function test.prepare_commit_checks_out_exact_revision(t)
	local deployment, shell = createDeployment()
	local commit = string.rep("a", 40)
	shell.outputs["git rev-parse HEAD"] = commit .. "\n"
	deployment:prepareCommit(commit)
	local commands = joinedCommands(shell)
	t:assert(commands:find('git fetch --no-tags origin "' .. commit .. '"', 1, true))
	t:assert(commands:find('git checkout --detach "' .. commit .. '"', 1, true))
	t:assert(commands:find("git submodule update --init --recursive", 1, true))
end

---@param t testing.T
function test.build_deploy_tests_builds_and_deploys(t)
	local deployment, shell = createDeployment()
	local commit = string.rep("b", 40)
	local prepared
	local deployed
	deployment.prepareCommit = function(_, value) prepared = value end
	deployment.deploy = function(_, value) deployed = value end
	deployment:buildDeploy(commit)
	t:eq(prepared, commit)
	t:eq(deployed, commit)
	t:eq(shell.commands[1], os.getenv("RIZU_DEPLOY_TEST_COMMAND") or "./test")
	t:eq(shell.commands[2], "./rizu/build/make.lua release")
end

---@param t testing.T
function test.prepare_root_renders_generated_nginx_config(t)
	local deployment, shell = createDeployment()
	deployment:prepareRoot()
	local commands = joinedCommands(shell)
	t:assert(commands:find('test -f "/srv/rizu/server-state/app_config.lua"', 1, true))
	t:assert(commands:find('test -f "/srv/rizu/server-state/bancho_config.lua"', 1, true))
	t:assert(commands:find('test -f "/srv/rizu/server-state/package_config.lua"', 1, true))
	t:assert(commands:find('test -f "/srv/rizu/server-state/nginx_config.lua"', 1, true))
	t:assert(commands:find('test -f "/srv/rizu/server-state/ai-router/config.lua"', 1, true))
	t:assert(commands:find('test -f "/srv/rizu/server-state/ai-router/network.lua"', 1, true))
	local render_at = assert(commands:find("make nginx-conf", 1, true))
	local check_at = assert(commands:find('test -f "/srv/rizu/server-state/nginx.conf"', 1, true))
	t:assert(render_at < check_at)
end

---@param t testing.T
function test.verifies_all_manifest_artifacts(t)
	local deployment, shell = createDeployment()
	local artifact = {path = "artifact", sha256 = string.rep("a", 64), size = 12}
	deployment:verifyRelease("/release", {
		format_version = 1,
		commit = string.rep("b", 40),
		artifacts = {server = artifact, files = artifact, zip = artifact, macos_zip = artifact},
	})
	local commands = joinedCommands(shell)
	local _, count = commands:gsub("sha256sum %-c", "")
	t:eq(count, 4)
end

---@param t testing.T
function test.rejects_unsafe_artifact_path(t)
	local deployment = createDeployment()
	t:has_error(function()
		deployment:verifyRelease("/release", {
			format_version = 1,
			commit = string.rep("b", 40),
			artifacts = {
				server = {path = "../server.tar.gz", sha256 = string.rep("a", 64), size = 12},
			},
		})
	end)
end

---@param t testing.T
function test.health_failure_restores_previous_release(t)
	local deployment, shell = createDeployment()
	shell.outputs["id -u"] = "1000\n"
	shell.outputs["id -g"] = "1000\n"
	deployment.waitHealthy = function(self, app_dir)
		return app_dir == "/srv/rizu/releases/old"
	end
	t:has_error(function()
		deployment:activateServer("/srv/rizu/releases/new", "/srv/rizu/releases/old")
	end)
	local commands = joinedCommands(shell)
	t:assert(commands:find("RIZU_APP_DIR=\"/srv/rizu/releases/new\"", 1, true))
	t:assert(commands:find("RIZU_APP_DIR=\"/srv/rizu/releases/old\"", 1, true))
end

---@param t testing.T
function test.persistent_state_is_mounted_separately(t)
	local deployment, shell = createDeployment()
	shell.outputs["id -u"] = "1000\n"
	shell.outputs["id -g"] = "1000\n"
	local command = deployment:composeCommand("/srv/rizu/releases/new")
	t:assert(command:find('RIZU_APP_DIR="/srv/rizu/releases/new"', 1, true))
	t:assert(command:find('RIZU_SERVER_STATE_PATH="/srv/rizu/server-state"', 1, true))
end

---@param t testing.T
function test.publication_switches_only_after_copy(t)
	local deployment, shell = createDeployment()
	deployment:publishClient("/artifact", string.rep("c", 40))
	local commands = joinedCommands(shell)
	local copy_at = assert(commands:find("cp -a", 1, true))
	local switch_at = assert(commands:find("/public/current.tmp", 1, true))
	t:assert(copy_at < switch_at)
end

---@param t testing.T
function test.status_identifies_release_mount(t)
	local deployment, shell = createDeployment()
	shell.outputs["docker inspect rizu-openresty-1 --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}'"] = "running|healthy\n"
	shell.outputs["docker inspect rizu-openresty-1 --format '{{range .Mounts}}{{if eq .Destination \"/app\"}}{{.Source}}{{end}}{{end}}'"] = "/srv/rizu/releases/" .. string.rep("a", 40) .. "\n"
	shell.outputs["docker inspect rizu-openresty-1 --format '{{range .Mounts}}{{if eq .Destination \"/app/server-state\"}}{{.Source}}{{end}}{{end}}'"] = "/srv/rizu/server-state\n"
	local mode, app_path, state_path, health = deployment:getStatus()
	t:eq(mode, "release")
	t:eq(app_path, "/srv/rizu/releases/" .. string.rep("a", 40))
	t:eq(state_path, "/srv/rizu/server-state")
	t:eq(health, "healthy")
end

---@param t testing.T
function test.status_identifies_checkout_mount(t)
	local deployment, shell = createDeployment()
	shell.outputs["docker inspect rizu-openresty-1 --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}'"] = "running|healthy\n"
	shell.outputs["docker inspect rizu-openresty-1 --format '{{range .Mounts}}{{if eq .Destination \"/app\"}}{{.Source}}{{end}}{{end}}'"] = "/srv/rizu\n"
	local mode = deployment:getStatus()
	t:eq(mode, "checkout")
end

---@param t testing.T
function test.status_identifies_stopped_server(t)
	local deployment = createDeployment()
	local mode = deployment:getStatus()
	t:eq(mode, "stopped")
end

---@param t testing.T
function test.prune_keeps_only_current_and_previous_deployments(t)
	local deployment, shell = createDeployment()
	deployment:prune()
	local commands = joinedCommands(shell)
	t:assert(commands:find('find "/srv/rizu/releases"', 1, true))
	t:assert(commands:find('readlink -f "/srv/rizu/current"', 1, true))
	t:assert(commands:find('readlink -f "/srv/rizu/previous"', 1, true))
	t:assert(commands:find('find "/srv/rizu/public/releases"', 1, true))
	t:assert(commands:find('readlink -f "/srv/rizu/public/current"', 1, true))
	t:assert(commands:find('find "/artifacts"', 1, true))
	t:assert(commands:find(".[0-9a-f]*.tmp", 1, true))
end

---@param t testing.T
function test.rollback_restarts_target_before_switching_links(t)
	local deployment, shell = createDeployment()
	local commit = string.rep("d", 40)
	shell.outputs['test -L "/srv/rizu/current" && readlink -f "/srv/rizu/current"'] = "/srv/rizu/releases/current\n"
	deployment.prepareRoot = function() end
	deployment.ensureNats = function() end
	deployment.activateServer = function(self, target, current)
		t:eq(target, "/srv/rizu/releases/" .. commit)
		t:eq(current, "/srv/rizu/releases/current")
	end
	deployment:rollback(commit)
	local commands = joinedCommands(shell)
	t:assert(commands:find("/public/releases/" .. commit, 1, true))
	t:assert(commands:find("/public/current.tmp", 1, true))
end

---@param t testing.T
function test.router_deploys_with_application_and_legacy_rollback_stops_it(t)
	local deployment, shell = createDeployment()
	shell.outputs["id -u"], shell.outputs["id -g"] = "1000", "1000"
	shell.outputs['test -f "/release/new/docker/ai-router-entrypoint.sh" && echo yes || true'] = "yes\n"
	deployment:startOpenResty("/release/new")
	t:assert(joinedCommands(shell):find("--no-deps compute ai-router openresty", 1, true))
	shell.commands = {}
	deployment:startOpenResty("/release/old")
	local commands = joinedCommands(shell)
	local stop_at = assert(commands:find("stop ai-router", 1, true))
	local start_at = assert(commands:find("--no-deps compute openresty", 1, true))
	t:assert(stop_at < start_at)
end

---@param t testing.T
function test.router_health_is_required_before_activation(t)
	local deployment, shell = createDeployment()
	shell.outputs["id -u"], shell.outputs["id -g"] = "1000", "1000"
	local path = "/release/new"
	shell.outputs['test -f "/release/new/docker/ai-router-entrypoint.sh" && echo yes || true'] = "yes\n"
	local compose = deployment:composeCommand(path)
	for _, service in ipairs({"compute", "openresty"}) do
		shell.outputs[compose .. " ps --format json " .. service .. " | grep -q '\"Health\":\"healthy\"' && echo healthy || true"] = "healthy\n"
	end
	t:eq(deployment:waitHealthy(path), false)
	shell.outputs[compose .. " ps --format json ai-router | grep -q '\"Health\":\"healthy\"' && echo healthy || true"] = "healthy\n"
	t:eq(deployment:waitHealthy(path), true)
end

---@param t testing.T
function test.startup_exception_restores_previous_release(t)
	local deployment = createDeployment()
	local restored = false
	deployment.startOpenResty = function(_, path)
		if path == "/new" then error("compose startup failed") end
		restored = path == "/old"
	end
	deployment.waitHealthy = function() return true end
	t:has_error(function() deployment:activateServer("/new", "/old") end)
	t:eq(restored, true)
end

---@param t testing.T
function test.disabled_rollback_never_starts_previous_release(t)
	for _, startup_fails in ipairs({false, true}) do
		local deployment, shell = createDeployment()
		deployment.config.auto_rollback = false
		shell.outputs["id -u"], shell.outputs["id -g"] = "1000", "1000"
		local started = {}
		function deployment:startOpenResty(path)
			table.insert(started, path)
			if startup_fails then error("candidate startup failed") end
		end
		deployment.waitHealthy = function() return false end
		t:has_error(function() deployment:activateServer("/new", "/old") end)
		t:tdeq(started, {"/new"})
		t:assert(joinedCommands(shell):find("stop openresty compute ai-router", 1, true))
	end
end

---@param t testing.T
function test.backup_is_required_before_activation_and_publication(t)
	for _, backup_fails in ipairs({false, true}) do
		local deployment, shell = createDeployment()
		deployment.config.backup_before_deploy = true
		local commit = string.rep("e", 40)
		local events = {}
		deployment.prepareRoot = function() end
		deployment.absolute = function(_, path) return path end
		deployment.readManifest = function() return {format_version = 1, commit = commit, artifacts = {}} end
		deployment.verifyRelease = function() end
		deployment.readLink = function() return "/old" end
		deployment.stageServer = function() return "/new" end
		function shell:execute(command)
			t:eq(command, "./scripts/backup")
			table.insert(events, "backup")
			if backup_fails then error("backup failed") end
		end
		deployment.ensureNats = function() table.insert(events, "nats") end
		deployment.activateServer = function() table.insert(events, "activate") end
		deployment.recordActivation = function() table.insert(events, "record") end
		deployment.publishClient = function() table.insert(events, "publish") end
		deployment.prune = function() table.insert(events, "prune") end
		if backup_fails then
			t:has_error(function() deployment:deploy(commit) end)
			t:tdeq(events, {"backup"})
		else
			deployment:deploy(commit)
			t:tdeq(events, {"backup", "nats", "activate", "record", "publish", "prune"})
		end
	end
end

return test
