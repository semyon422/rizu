local Config = require("rizu.config.Config")

---@class rizu.mapperatorinator.Config.Keys
local keys = {
	repository_path = "mapperatorinator.repository_path",
	python_path = "mapperatorinator.python_path",
	lora_path = "mapperatorinator.paths.lora",
	reference_path = "mapperatorinator.paths.reference",
	background_path = "mapperatorinator.paths.background",
	model = "mapperatorinator.basic.model",
	gamemode = "mapperatorinator.gamemode",
	difficulty = "mapperatorinator.difficulty",
	title = "mapperatorinator.metadata.title",
	title_unicode = "mapperatorinator.metadata.title_unicode",
	artist = "mapperatorinator.metadata.artist",
	artist_unicode = "mapperatorinator.metadata.artist_unicode",
	creator = "mapperatorinator.metadata.creator",
	version = "mapperatorinator.metadata.version",
	source = "mapperatorinator.metadata.source",
	tags = "mapperatorinator.metadata.tags",
	preview_time = "mapperatorinator.metadata.preview_time",
	hp_drain_rate = "mapperatorinator.difficulty.hp_drain_rate",
	circle_size = "mapperatorinator.difficulty.circle_size",
	overall_difficulty = "mapperatorinator.difficulty.overall_difficulty",
	approach_rate = "mapperatorinator.difficulty.approach_rate",
	slider_multiplier = "mapperatorinator.difficulty.slider_multiplier",
	slider_tick_rate = "mapperatorinator.difficulty.slider_tick_rate",
	keycount = "mapperatorinator.keycount",
	year = "mapperatorinator.year",
	mapper_id = "mapperatorinator.style.mapper_id",
	beatmap_id = "mapperatorinator.style.beatmap_id",
	hold_note_ratio = "mapperatorinator.style.hold_note_ratio",
	scroll_speed_ratio = "mapperatorinator.style.scroll_speed_ratio",
	descriptors = "mapperatorinator.descriptors.positive",
	negative_descriptors = "mapperatorinator.descriptors.negative",
	seed = "mapperatorinator.generation.seed",
	cfg_scale = "mapperatorinator.generation.cfg_scale",
	temperature = "mapperatorinator.generation.temperature",
	top_p = "mapperatorinator.generation.top_p",
	start_time = "mapperatorinator.generation.start_time",
	end_time = "mapperatorinator.generation.end_time",
	device = "mapperatorinator.generation.device",
	precision = "mapperatorinator.generation.precision",
	attn_implementation = "mapperatorinator.generation.attn_implementation",
	export_osz = "mapperatorinator.options.export_osz",
	hitsounded = "mapperatorinator.options.hitsounded",
	super_timing = "mapperatorinator.options.super_timing",
	generate_positions = "mapperatorinator.options.generate_positions",
	add_to_beatmap = "mapperatorinator.options.add_to_beatmap",
	overwrite_reference_beatmap = "mapperatorinator.options.overwrite_reference_beatmap",
	context_timing = "mapperatorinator.context.timing",
	context_kiai = "mapperatorinator.context.kiai",
	context_gd = "mapperatorinator.context.gd",
	context_no_hs = "mapperatorinator.context.no_hs",
}

local MapperatorinatorConfig = {keys = keys}

---@param config rizu.config.Config
---@param mappings {[1]: string, [2]: string}[]
local function migrate(config, mappings)
	local content = config.fs:read(config.path)
	if not content then return end
	local migrated = content
	local count = 0
	for _, mapping in ipairs(mappings) do
		local pattern = '"' .. mapping[1]:gsub("([^%w])", "%%%1") .. '"'
		local replacements
		migrated, replacements = migrated:gsub(pattern, '"' .. mapping[2] .. '"')
		count = count + replacements
	end
	if count > 0 and config:deserialize(migrated) then
		config:save()
	end
end

---@param filesystem fs.IFilesystem
---@param home string?
---@return rizu.config.Config
function MapperatorinatorConfig.create(filesystem, home)
	home = home or os.getenv("HOME") or ""
	local config = Config(filesystem, "userdata/mapperatorinator.json")

	config:setDefaultString(keys.repository_path, home .. "/code/Mapperatorinator")
	config:setDefaultString(keys.python_path, home .. "/code/Mapperatorinator/.venv/bin/python")
	config:setDefaultString(keys.lora_path, "")
	config:setDefaultString(keys.reference_path, "")
	config:setDefaultString(keys.background_path, "")

	config:setDefaultChoice(keys.model, "v32", {"v28", "v29", "v30", "v31", "v32-mini", "v32"})
	config:setDefaultChoice(keys.gamemode, "osu!mania", {"osu!mania", "osu!standard", "osu!taiko", "osu!catch"})
	config:setDefaultNumber(keys.difficulty, 5, 0.1, 15, 0.1)

	config:setDefaultString(keys.title, "")
	config:setDefaultString(keys.title_unicode, "")
	config:setDefaultString(keys.artist, "")
	config:setDefaultString(keys.artist_unicode, "")
	config:setDefaultString(keys.creator, "Mapperatorinator")
	config:setDefaultString(keys.version, "Mapperatorinator")
	config:setDefaultString(keys.source, "")
	config:setDefaultString(keys.tags, "")
	config:setDefaultString(keys.preview_time, "")

	config:setDefaultNumber(keys.hp_drain_rate, 5, 0, 10, 0.1)
	config:setDefaultNumber(keys.circle_size, 4, 0, 10, 0.1)
	config:setDefaultNumber(keys.overall_difficulty, 8, 0, 10, 0.1)
	config:setDefaultNumber(keys.approach_rate, 9, 0, 10, 0.1)
	config:setDefaultNumber(keys.slider_multiplier, 1.4, 0.1, 3.6, 0.1)
	config:setDefaultNumber(keys.slider_tick_rate, 1, 0.5, 4, 0.5)
	config:setDefaultNumber(keys.keycount, 4, 1, 18, 1)

	config:setDefaultNumber(keys.year, 2024, 2007, 2024, 1)
	config:setDefaultString(keys.mapper_id, "")
	config:setDefaultString(keys.beatmap_id, "")
	config:setDefaultString(keys.hold_note_ratio, "")
	config:setDefaultString(keys.scroll_speed_ratio, "")
	config:setDefaultString(keys.descriptors, "")
	config:setDefaultString(keys.negative_descriptors, "")

	config:setDefaultString(keys.seed, "")
	config:setDefaultNumber(keys.cfg_scale, 1, 0, 10, 0.1)
	config:setDefaultNumber(keys.temperature, 0.9, 0, 2, 0.01)
	config:setDefaultNumber(keys.top_p, 0.9, 0, 1, 0.01)
	config:setDefaultString(keys.start_time, "")
	config:setDefaultString(keys.end_time, "")
	config:setDefaultChoice(keys.device, "auto", {"auto", "cuda", "cpu", "mps"})
	config:setDefaultChoice(keys.precision, "bf16", {"bf16", "fp16", "fp32", "amp"})
	config:setDefaultChoice(keys.attn_implementation, "auto", {"auto", "eager", "sdpa", "flash_attention_2"})

	config:setDefaultBoolean(keys.export_osz, false)
	config:setDefaultBoolean(keys.hitsounded, true)
	config:setDefaultBoolean(keys.super_timing, false)
	config:setDefaultBoolean(keys.generate_positions, false)
	config:setDefaultBoolean(keys.add_to_beatmap, false)
	config:setDefaultBoolean(keys.overwrite_reference_beatmap, false)
	config:setDefaultBoolean(keys.context_timing, false)
	config:setDefaultBoolean(keys.context_kiai, false)
	config:setDefaultBoolean(keys.context_gd, false)
	config:setDefaultBoolean(keys.context_no_hs, false)

	migrate(config, {
		{"mapperatorinator.paths.repository", keys.repository_path},
		{"mapperatorinator.paths.python", keys.python_path},
		{"mapperatorinator.basic.gamemode", keys.gamemode},
		{"mapperatorinator.basic.difficulty", keys.difficulty},
		{"mapperatorinator.difficulty.keycount", keys.keycount},
		{"mapperatorinator.style.year", keys.year},
	})
	return config
end

---@param config rizu.config.Config
function MapperatorinatorConfig.reset(config)
	assert(config:deserialize("{}"), "failed to reset Mapperatorinator config")
end

return MapperatorinatorConfig
