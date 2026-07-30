COMPOSE ?= docker compose

.DEFAULT_GOAL := help

.PHONY: help config nginx-conf preflight validate pull up down restart ps logs openresty-logs nats-logs shell update deploy

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
	@echo "  make deploy          Update and start the deployment"

config:
	@if [ ! -e app_config.lua ]; then \
		cp sea/app/AppConfig.lua app_config.lua; \
		echo "Created app_config.lua"; \
		echo "Replace its placeholder session secret before starting the server."; \
	else \
		echo "app_config.lua already exists"; \
	fi
	@if [ ! -e nginx_config.lua ]; then \
		cp nginx_config.example.lua nginx_config.lua; \
		echo "Created nginx_config.lua"; \
	else \
		echo "nginx_config.lua already exists"; \
	fi

nginx-conf: config
	@OR_ROOT=/usr/local/openresty \
		LJ_ROOT=/usr/local/openresty/luajit \
		PATH="$$PWD/tree/bin:$$PATH" \
		./luajit aqua/web/nginx/compile.lua
	@echo "Rendered nginx.conf"

preflight: nginx-conf
	@test -f app_config.lua || { echo "missing app_config.lua; run make config" >&2; exit 1; }
	@test -f nginx.conf || { echo "missing nginx.conf; run make nginx-conf" >&2; exit 1; }
	@test -f nginx_config.lua || { echo "missing nginx_config.lua; run make config" >&2; exit 1; }
	@test -f bin/linux64/lib7z.so || { echo "missing bin/linux64/lib7z.so" >&2; exit 1; }
	@test -f bin/linux64/libiconv.so || { echo "missing bin/linux64/libiconv.so" >&2; exit 1; }
	@test -f bin/linux64/libsqlite3.so || { echo "missing bin/linux64/libsqlite3.so" >&2; exit 1; }
	@test -f bin/linux64/libminacalc.so || { echo "missing bin/linux64/libminacalc.so" >&2; exit 1; }
	@test -f tree/lib/lua/5.1/bcrypt.so || { echo "missing tree/lib/lua/5.1/bcrypt.so" >&2; exit 1; }
	@test -f tree/share/lua/5.1/resty/nats/client.lua || { echo "missing tree/share/lua/5.1/resty/nats/client.lua" >&2; exit 1; }
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

deploy: update
	$(MAKE) up
