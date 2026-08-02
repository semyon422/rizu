COMPOSE ?= docker compose
RIZU_UID ?= $(shell id -u)
RIZU_GID ?= $(shell id -g)

export RIZU_UID
export RIZU_GID

.DEFAULT_GOAL := help

.PHONY: help config nginx-conf preflight validate pull up down restart ps logs openresty-logs nats-logs shell update

help:
	@echo "Rizu server deployment"
	@echo
	@echo "  make config          Create the local application config"
	@echo "  make nginx-conf      Render nginx.conf from local configuration"
	@echo "  make preflight       Check prebuilt server artifacts"
	@echo "  make validate        Validate the Compose configuration"
	@echo "  make pull            Pull OpenResty and NATS images"
	@echo "  make up              Start OpenResty and NATS"
	@echo "  make down            Stop OpenResty and NATS"
	@echo "  make restart         Restart OpenResty and NATS"
	@echo "  make ps              Show service status"
	@echo "  make logs            Follow all service logs"
	@echo "  make openresty-logs  Follow OpenResty logs"
	@echo "  make nats-logs       Follow NATS logs"
	@echo "  make shell           Open a shell in the OpenResty container"
	@echo "  make update          Pull Git and submodule changes"

config:
	@mkdir -p server-state
	@if [ ! -e server-state/app_config.lua ]; then \
		cp sea/app/AppConfig.lua server-state/app_config.lua; \
		echo "Created server-state/app_config.lua"; \
		echo "Replace its placeholder session secret before starting the server."; \
	else \
		echo "server-state/app_config.lua already exists"; \
	fi
	@if [ ! -e server-state/nginx_config.lua ]; then \
		cp nginx_config.example.lua server-state/nginx_config.lua; \
		echo "Created server-state/nginx_config.lua"; \
	else \
		echo "server-state/nginx_config.lua already exists"; \
	fi

nginx-conf: config
	@OR_ROOT=/usr/local/openresty \
		LJ_ROOT=/usr/local/openresty/luajit \
		NGINX_CONFIG_PATH=server-state/nginx_config.lua \
		NGINX_OUTPUT_PATH=server-state/nginx.conf \
		NGINX_MIME_TYPES_PATH=/app/aqua/web/nginx/mime.types \
		NGINX_ERROR_LOG_PATH=/app/server-state/logs/error.log \
		NGINX_ACCESS_LOG_PATH=/app/server-state/logs/access.log \
		NGINX_PID_PATH=/app/server-state/logs/nginx.pid \
		NGINX_TEMP_PATH=/app/server-state/temp \
		PATH="$$PWD/tree/bin:$$PATH" \
		./luajit aqua/web/nginx/compile.lua
	@echo "Rendered server-state/nginx.conf"

preflight: nginx-conf
	@test -f server-state/app_config.lua || { echo "missing server-state/app_config.lua; run make config" >&2; exit 1; }
	@test -f server-state/nginx.conf || { echo "missing server-state/nginx.conf; run make nginx-conf" >&2; exit 1; }
	@test -f server-state/nginx_config.lua || { echo "missing server-state/nginx_config.lua; run make config" >&2; exit 1; }
	@test -f bin/linux64/lib7z.so || { echo "missing bin/linux64/lib7z.so" >&2; exit 1; }
	@test -f bin/linux64/libiconv.so || { echo "missing bin/linux64/libiconv.so" >&2; exit 1; }
	@test -f bin/linux64/libsqlite3.so || { echo "missing bin/linux64/libsqlite3.so" >&2; exit 1; }
	@test -f bin/linux64/libminacalc.so || { echo "missing bin/linux64/libminacalc.so" >&2; exit 1; }
	@test -f tree/lib/lua/5.1/bcrypt.so || { echo "missing tree/lib/lua/5.1/bcrypt.so" >&2; exit 1; }
	@test -f tree/share/lua/5.1/resty/nats/client.lua || { echo "missing tree/share/lua/5.1/resty/nats/client.lua" >&2; exit 1; }
	@test -w server-state || { echo "server-state must be writable for SQLite WAL files and runtime logs" >&2; exit 1; }
	@test ! -e server-state/server.db || test -w server-state/server.db || { echo "server-state/server.db is not writable" >&2; exit 1; }
	@echo "Prebuilt runtime artifacts are ready"

validate:
	$(COMPOSE) config --quiet

pull:
	$(COMPOSE) pull

up: preflight
	$(COMPOSE) up --detach --force-recreate --pull missing --no-build

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs --follow

openresty-logs:
	$(COMPOSE) logs --follow openresty

nats-logs:
	$(COMPOSE) logs --follow nats

shell:
	$(COMPOSE) exec openresty /bin/sh

update:
	git pull --ff-only
	git submodule update --init --recursive
