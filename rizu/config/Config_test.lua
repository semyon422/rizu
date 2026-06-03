local Config = require("rizu.config.Config")
local Checkbox = require("rizu.config.kinds.Checkbox")
local Choice = require("rizu.config.kinds.Choice")
local Range = require("rizu.config.kinds.Range")
local Textbox = require("rizu.config.kinds.Textbox")
local ConfigManager = require("rizu.config.ConfigManager")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

function test.automatic_discovery(t)
	local schema = {
		audio = {
			levels = {
				master = Range(0.5, 0, 1, 0.01),
			}
		},
		graphics = {
			modes = {
				fullscreen = Checkbox(false),
			}
		}
	}

	local config = Config(schema)
	t:eq(config.settings_map[schema.audio.levels.master], true)
	t:eq(config.settings_map[schema.graphics.modes.fullscreen], true)
	t:eq(config.setting_to_path[schema.audio.levels.master], "audio.levels.master")
	t:eq(config.setting_to_path[schema.graphics.modes.fullscreen], "graphics.modes.fullscreen")
end

function test.immediate_settings(t)
	local schema = {
		audio = {
			options = {
				sound_enabled = Checkbox(false)
			}
		}
	}
	local config = Config(schema)
	local sound_enabled = schema.audio.options.sound_enabled

	t:eq(config:get(sound_enabled), false)

	local event_fired = false
	local updated_setting = nil
	config.onChanged:add({
		receive = function(self, setting)
			event_fired = true
			updated_setting = setting
		end
	})

	config:set(sound_enabled, true)
	t:eq(config:get(sound_enabled), true)
	t:eq(event_fired, true)
	t:eq(updated_setting, sound_enabled)

	event_fired = false
	config:set(sound_enabled, true)
	t:eq(event_fired, false)
end

function test.deferred_settings(t)
	local schema = {
		graphics = {
			options = {
				resolution = Choice("1920x1080", {"1920x1080", "1280x720"}):setDeferred(true)
			}
		}
	}
	local config = Config(schema)
	local resolution = schema.graphics.options.resolution

	t:eq(config:get(resolution), "1920x1080")

	local event_fired = false
	config.onChanged:add({
		receive = function(self, setting)
			event_fired = true
		end
	})

	config:set(resolution, "1280x720")
	t:eq(config:get(resolution), "1280x720")
	t:eq(config.persistent_values[resolution], nil)
	t:eq(event_fired, false)

	config:commit()
	t:eq(config:get(resolution), "1280x720")
	t:eq(config.persistent_values[resolution], "1280x720")
	t:eq(event_fired, true)
end

function test.discard_deferred(t)
	local schema = {
		graphics = {
			options = {
				resolution = Choice("1920x1080", {"1920x1080", "1280x720"}):setDeferred(true)
			}
		}
	}
	local config = Config(schema)
	local resolution = schema.graphics.options.resolution

	config:set(resolution, "1280x720")
	t:eq(config:get(resolution), "1280x720")

	config:discard()
	t:eq(config:get(resolution), "1920x1080")
end

function test.serialization_and_deserialization(t)
	local schema = {
		audio = {
			volume = {
				master = Range(0.5, 0, 1, 0.1),
			}
		},
		gameplay = {
			speed = {
				scroll = Range(5.0, 1, 10, 0.5),
			}
		}
	}
	local config = Config(schema)
	config:set(schema.audio.volume.master, 0.8)
	config:set(schema.gameplay.speed.scroll, 4.5)

	local serialized = config:serialize()
	t:eq(type(serialized), "string")

	-- Deserialize into a new config
	local config2 = Config(schema)
	local success = config2:deserialize(serialized)
	t:eq(success, true)
	t:eq(config2:get(schema.audio.volume.master), 0.8)
	t:eq(config2:get(schema.gameplay.speed.scroll), 4.5)
end

function test.config_manager(t)
	local schema = {
		audio = {
			volume = {
				master = Range(0.5, 0, 1, 0.1),
			}
		}
	}
	local config = Config(schema)
	config:set(schema.audio.volume.master, 0.5)

	local temp_filepath = "tmp_config_test.json"
	local manager = ConfigManager(FakeFilesystem())
	local save_ok = manager:save(temp_filepath, config)
	t:eq(save_ok, true)

	local config2 = Config(schema)
	local load_ok = manager:load(temp_filepath, config2)
	t:eq(load_ok, true)
	t:eq(config2:get(schema.audio.volume.master), 0.5)

	local registered = manager:register("test", schema, temp_filepath)
	registered:set(schema.audio.volume.master, 0.8)
	manager:saveById("test")
	
	local registered2 = manager:register("test2", schema, temp_filepath)
	manager:loadById("test2")
	t:eq(registered2:get(schema.audio.volume.master), 0.8)

	manager.fs:remove(temp_filepath)
end

function test.type_validation(t)
	local schema = {
		audio = {
			volume = {
				master = Range(0.5, 0, 1, 0.1),
			}
		},
		graphics = {
			mode = {
				fullscreen = Checkbox(false),
			}
		},
		misc = {
			user = {
				username = Textbox(""),
			},
			style = {
				theme = Choice("New", {"Old", "New"}),
			}
		}
	}
	local config = Config(schema)

	-- Valid calls
	config:set(schema.audio.volume.master, 0.7)
	config:set(schema.graphics.mode.fullscreen, true)
	config:set(schema.misc.user.username, "Antigravity")
	config:set(schema.misc.style.theme, "New")

	t:eq(config:getNumber(schema.audio.volume.master), 0.7)
	t:eq(config:getBoolean(schema.graphics.mode.fullscreen), true)
	t:eq(config:getString(schema.misc.user.username), "Antigravity")
	t:eq(config:getString(schema.misc.style.theme), "New")

	-- Invalid getNumber (only accepts ranges)
	t:has_error(function()
		config:getNumber(schema.graphics.mode.fullscreen)
	end)
	t:has_error(function()
		config:getNumber(schema.misc.user.username)
	end)

	-- Invalid getBoolean (only accepts checkboxes)
	t:has_error(function()
		config:getBoolean(schema.audio.volume.master)
	end)
	t:has_error(function()
		config:getBoolean(schema.misc.style.theme)
	end)

	-- Invalid getString (only accepts textboxes and choices)
	t:has_error(function()
		config:getString(schema.audio.volume.master)
	end)
	t:has_error(function()
		config:getString(schema.graphics.mode.fullscreen)
	end)

	-- Valid setters
	config:setNumber(schema.audio.volume.master, 0.9)
	config:setBoolean(schema.graphics.mode.fullscreen, false)
	config:setString(schema.misc.user.username, "Foo")

	t:eq(config:getNumber(schema.audio.volume.master), 0.9)
	t:eq(config:getBoolean(schema.graphics.mode.fullscreen), false)
	t:eq(config:getString(schema.misc.user.username), "Foo")

	-- Invalid setters
	t:has_error(function()
		config:setNumber(schema.audio.volume.master, "0.9") -- Wrong type
	end)
	t:has_error(function()
		config:setNumber(schema.graphics.mode.fullscreen, 1) -- Wrong setting
	end)

	t:has_error(function()
		config:setBoolean(schema.graphics.mode.fullscreen, "false") -- Wrong type
	end)
	t:has_error(function()
		config:setBoolean(schema.audio.volume.master, true) -- Wrong setting
	end)

	t:has_error(function()
		config:setString(schema.misc.user.username, 123) -- Wrong type
	end)
	t:has_error(function()
		config:setString(schema.audio.volume.master, "hello") -- Wrong setting
	end)
end
return test
