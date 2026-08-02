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
		retain = 5,
		health_attempts = 2,
		health_interval = 1,
	})
	return deployment, shell
end

local function joinedCommands(shell)
	return table.concat(shell.commands, "\n")
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
	t:assert(command:find('RIZU_SERVER_STATE_DIR="/srv/rizu/server-state"', 1, true))
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
function test.rollback_restarts_target_before_switching_links(t)
	local deployment, shell = createDeployment()
	local commit = string.rep("d", 40)
	shell.outputs['readlink -f "/srv/rizu/current"'] = "/srv/rizu/releases/current\n"
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

return test
