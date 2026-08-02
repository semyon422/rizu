#!/usr/bin/env luajit

---@type (string?)[]
local args = arg

require("pkg_config")

local Deployment = require("deploy.Deployment")
local Shell = require("rizu.build.Shell")

local function usage()
	print([[Usage:
  ./deploy.lua deploy <commit|release-directory>
  ./deploy.lua rollback [commit]

Environment:
  RIZU_DEPLOY_ROOT       Deployment root (default: deploy-data)
  RIZU_ARTIFACT_ROOT     Release artifact root (default: build/release)
  RIZU_COMPOSE_FILE      Compose file (default: compose.yaml)
  RIZU_COMPOSE           Compose command (default: docker compose)
  RIZU_RELEASE_RETAIN    Number of server releases to retain (default: 5)
  RIZU_HEALTH_ATTEMPTS   Health polling attempts (default: 30)
  RIZU_HEALTH_INTERVAL   Seconds between health checks (default: 2)]])
end

local function positiveInteger(name, default)
	local value = tonumber(os.getenv(name) or default)
	assert(value and value >= 1 and value % 1 == 0, name .. " must be a positive integer")
	return value
end

local command = args[1]
if command ~= "deploy" and command ~= "rollback" then
	usage()
	os.exit(command == "help" or command == "--help" and 0 or 2)
end
if command == "deploy" and not args[2] then
	usage()
	os.exit(2)
end

local deployment = Deployment(Shell(), {
	root = os.getenv("RIZU_DEPLOY_ROOT") or "deploy-data",
	artifact_root = os.getenv("RIZU_ARTIFACT_ROOT") or "build/release",
	compose_file = os.getenv("RIZU_COMPOSE_FILE") or "compose.yaml",
	compose_command = os.getenv("RIZU_COMPOSE") or "docker compose",
	retain = positiveInteger("RIZU_RELEASE_RETAIN", "5"),
	health_attempts = positiveInteger("RIZU_HEALTH_ATTEMPTS", "30"),
	health_interval = positiveInteger("RIZU_HEALTH_INTERVAL", "2"),
})

deployment.config.root = deployment:absolute(deployment.config.root)
deployment.config.artifact_root = deployment:absolute(deployment.config.artifact_root)
deployment.config.compose_file = deployment:absolute(deployment.config.compose_file)

if command == "deploy" then
	deployment:deploy(args[2])
else
	deployment:rollback(args[2])
end
