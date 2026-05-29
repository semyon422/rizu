local BanchoConfig = require("bancho.config.BanchoConfig")

local test = {}

--- Defaults are applied when no overrides given.
function test.defaults(t)
	local config = BanchoConfig()
	t:eq(config.domain, "rizu.su")
	t:eq(config.bot_name, "bot")
	t:eq(config.bot_id, 1)
	t:eq(config.db_path, "bancho.db")
	t:eq(config.max_matches, 64)
	t:eq(config.allow_registration, true)
	t:eq(config.command_prefix, "!")
	t:eq(#config.channels, 6)
end

--- Overrides replace default values.
function test.overrides(t)
	local config = BanchoConfig({
		domain = "example.com",
		bot_name = "botty",
		max_matches = 128,
	})
	t:eq(config.domain, "example.com")
	t:eq(config.bot_name, "botty")
	t:eq(config.max_matches, 128)

	-- Unset fields retain defaults
	t:eq(config.bot_id, 1)
	t:eq(config.db_path, "bancho.db")
	t:eq(config.command_prefix, "!")
end

--- Nested table overrides deep-merge (same as ConfigModel).
--- Array elements merge by numeric key index.
function test.deep_merge(t)
	local config = BanchoConfig({
		cached_accuracies = { 80, 90 },
	})
	-- cached_accuracies defaults {50,60,70,80,90,95,99,100} merged with {80,90}
	-- index 1: 50 -> 80, index 2: 60 -> 90, indices 3-8 unchanged
	t:eq(config.cached_accuracies[1], 80)
	t:eq(config.cached_accuracies[2], 90)
	t:eq(config.cached_accuracies[3], 70)
	t:eq(config.cached_accuracies[8], 100)

	-- Other defaults preserved
	t:eq(config.domain, "rizu.su")
end

--- Scalar override replaces nested table entirely.
function test.scalar_replace(t)
	local config = BanchoConfig({
		cached_accuracies = 42,
	})
	t:eq(config.cached_accuracies, 42)
end

--- Merge combines two configs with overrides taking precedence.
function test.merge(t)
	local base = BanchoConfig({ domain = "base.com", bot_name = "base_bot" })
	local overrides = { domain = "override.com", max_matches = 200 }
	local result = BanchoConfig:merge(base, overrides)

	t:eq(result.domain, "override.com")
	t:eq(result.bot_name, "base_bot")
	t:eq(result.max_matches, 200)

	-- Original tables unmodified
	t:eq(base.domain, "base.com")
	t:eq(overrides.domain, "override.com")
end

--- Nil overrides returns defaults.
function test.nil_overrides(t)
	local config = BanchoConfig(nil)
	t:eq(config.domain, "rizu.su")
	t:eq(config.bot_name, "bot")
end

--- Defaults table is not mutated by new.
function test.defaults_immutable(t)
	local before_domain = BanchoConfig.defaults.domain
	local before_channels = #BanchoConfig.defaults.channels
	BanchoConfig({ domain = "test.com" })
	t:eq(BanchoConfig.defaults.domain, before_domain)
	t:eq(#BanchoConfig.defaults.channels, before_channels)
end

return test
