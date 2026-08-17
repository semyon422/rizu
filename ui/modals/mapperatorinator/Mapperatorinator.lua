local Button = require("ui.views.Button")
local Checkbox = require("ui.views.form.Checkbox")
local Colors = require("ui.Colors")
local ControlFactory = require("ui.modals.config.ControlFactory")
local FilePicker = require("rizu.mapperatorinator.FilePicker")
local FlowContainer = require("gui.layout.FlowContainer")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local Label = require("ui.views.Label")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local MapperatorinatorConfig = require("rizu.mapperatorinator.Config")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local Section = require("ui.modals.config.Section")
local SectionItem = require("ui.modals.config.SectionItem")
local Slider = require("ui.views.form.Slider")
local Textbox = require("ui.views.form.Textbox")

---@class ui.modals.mapperatorinator.Mapperatorinator : ui.ModalView
---@operator call: ui.modals.mapperatorinator.Mapperatorinator
local Mapperatorinator = ModalView + {}

local WIDTH = 1120
local HEIGHT = 820
local SIDEBAR_WIDTH = 310
local FORM_WIDTH = 720
local CONTENT_X = 350
local CONTENT_Y = 112
local CONTENT_HEIGHT = 545
local keys = MapperatorinatorConfig.keys

---@param text string
---@param action fun()
---@param width number?
---@return ui.views.Button
local function smallButton(text, action, width)
	local button = Button(text, action)
	button:setSize(width or 200, 48)
	return button
end

---@param text string
---@return ui.views.Label
local function note(text)
	local label = Label({font_name = "regular", font_size = 16, text = text, color = Colors.text_muted})
	label:setSize(FORM_WIDTH, math.max(label.offset_max[2] - label.offset_min[2], 24))
	return label
end

---@param config rizu.config.Config
---@param key string
---@param name string
---@param placeholder string?
---@return ui.views.form.Textbox
local function stringControl(config, key, name, placeholder)
	return Textbox({
		label = name,
		text = config:getString(key),
		placeholder = placeholder,
		width = FORM_WIDTH,
		on_change = function(value) config:setString(key, value) end,
	})
end

---@param config rizu.config.Config
---@param key string
---@param name string
---@return ui.views.form.Checkbox
local function booleanControl(config, key, name)
	return Checkbox({
		text = name,
		checked = config:getBoolean(key),
		on_change = function(value) config:setBoolean(key, value) end,
	})
end

---@param config rizu.config.Config
---@param key string
---@param name string
---@param format? fun(value: number): string
---@return ui.views.form.Slider
local function numberControl(config, key, name, format)
	local definition = config:getDefinition(key)
	return Slider({
		label = name,
		value = config:getNumber(key),
		min = definition.min,
		max = definition.max,
		step = definition.step,
		width = FORM_WIDTH,
		value_format = format,
		on_change = function(value) config:setNumber(key, value) end,
	})
end

---@param name string
---@param icon gui.Sprite
---@param build fun(): gui.View[]
---@return ui.modals.config.Section
local function makeSection(name, icon, build)
	return Section({name = name, icon = icon, build = build})
end

---@param workflow rizu.mapperatorinator.Workflow
---@param config rizu.config.Config
---@param on_close fun()
function Mapperatorinator:new(workflow, config, on_close)
	ModalView.new(self)
	self.workflow = workflow
	self.config = config
	self.on_close = on_close
	self.audio_path = ""
	self.file_picker = FilePicker()
	self.host_fs = LinuxFilesystem()
	self.settings_invalidated = false

	self:setSize(WIDTH, HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(true)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	local sprites = Resources.sprites
	local modal_sprites = {
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	}
	self.background = NineSliceUsage(modal_sprites)
	self.content_background = NineSliceUsage(modal_sprites)

	local title = self:add(Label({font_name = "bold", font_size = 32, text = "Mapperatorinator"}))
	title:setOffset(32, 24)
	local subtitle = self:add(Label({
		font_name = "regular", font_size = 16,
		text = "Native controls for Mapperatorinator generation — review AI output before publishing.",
		color = Colors.text_muted,
	}))
	subtitle:setOffset(32, 68)

	self.sections = self:createSections()
	self.selected_section = self.sections[1]
	self.section_list = FlowContainer({direction = "column", gap = 3})
	for _, section in ipairs(self.sections) do
		self.section_list:add(SectionItem(section, function(selected)
			self.selected_section = selected
			self:invalidateSettings()
		end))
	end
	self.section_list:fitContent()
	self.section_list:setOffset(14, CONTENT_Y)
	self:add(self.section_list)

	self.form = Form({direction = "column", gap = 18, padding = {0, 10, 0, 20}})
	self.scroll_view = self:add(ScrollView(self.form))
	self.scroll_view:anchorFixed(CONTENT_X, CONTENT_Y, FORM_WIDTH + 2, CONTENT_HEIGHT)
	self.form_selection = self.scroll_view:add(FormSelection(self.form))
	self:rebuildSettings()

	self.status_label = self:add(Label({
		font_name = "regular", font_size = 16, text = workflow.status,
		color = Colors.text_muted, align = "center",
	}))
	self.status_label:anchorFixed(CONTENT_X, 675, FORM_WIDTH, 44)

	self.generate_button = self:add(Button("Generate", function() self:generate() end))
	self.generate_button:setSize(250, 58)
	self.generate_button:setOffset(430, 742)
	self.close_button = self:add(Button("Close", on_close))
	self.close_button:setSize(180, 58)
	self.close_button:setOffset(715, 742)
end

---@return ui.modals.config.Section[]
function Mapperatorinator:createSections()
	local config = self.config
	local sprites = Resources.sprites
	return {
		makeSection("Paths", sprites.icon_folder, function()
			local choose_row = FlowContainer({direction = "row", gap = 12})
			choose_row:add(smallButton("Reference .osu", function()
				self:choosePath(keys.reference_path, "Select reference beatmap", {"osu! beatmaps | *.osu"})
			end, 210))
			choose_row:add(smallButton("LoRA", function()
				self:choosePath(keys.lora_path, "Select LoRA weights")
			end, 150))
			choose_row:add(smallButton("Background", function()
				self:choosePath(keys.background_path, "Select background image", {"Images | *.png *.jpg *.jpeg *.webp"})
			end, 190))
			choose_row:fitContent()
			return {
				note("Audio: " .. (self.audio_path ~= "" and self.audio_path or "not selected")),
				stringControl(config, keys.repository_path, "Mapperatorinator repository"),
				stringControl(config, keys.python_path, "Python executable"),
				stringControl(config, keys.reference_path, "Reference beatmap (.osu)", "Optional"),
				stringControl(config, keys.lora_path, "LoRA weights", "Optional"),
				stringControl(config, keys.background_path, "Background image", "Optional"),
				choose_row,
			}
		end),
		makeSection("Basic", sprites.icon_play, function()
			return {
				ControlFactory.choice(config, keys.model, {name = "Model", width = FORM_WIDTH}),
				ControlFactory.choice(config, keys.gamemode, {name = "Game mode", width = FORM_WIDTH}),
				numberControl(config, keys.difficulty, "Target difficulty", function(value) return ("%.1f★"):format(value) end),
			}
		end),
		makeSection("Metadata", sprites.icon_layers, function()
			return {
				stringControl(config, keys.title, "Title"),
				stringControl(config, keys.title_unicode, "Title (Unicode)"),
				stringControl(config, keys.artist, "Artist"),
				stringControl(config, keys.artist_unicode, "Artist (Unicode)"),
				stringControl(config, keys.creator, "Creator"),
				stringControl(config, keys.version, "Difficulty name / version"),
				stringControl(config, keys.source, "Source"),
				stringControl(config, keys.tags, "Tags"),
				stringControl(config, keys.preview_time, "Preview time (ms)", "Blank for automatic"),
			}
		end),
		makeSection("Difficulty", sprites.icon_zap, function()
			return {
				numberControl(config, keys.hp_drain_rate, "HP drain rate"),
				numberControl(config, keys.circle_size, "Circle size"),
				numberControl(config, keys.overall_difficulty, "Overall difficulty"),
				numberControl(config, keys.approach_rate, "Approach rate"),
				numberControl(config, keys.slider_multiplier, "Slider multiplier"),
				numberControl(config, keys.slider_tick_rate, "Slider tick rate"),
				numberControl(config, keys.keycount, "Mania key count", function(value) return ("%dK"):format(value) end),
			}
		end),
		makeSection("Style", sprites.icon_brush, function()
			return {
				numberControl(config, keys.year, "Style year", function(value) return tostring(value) end),
				stringControl(config, keys.beatmap_id, "Beatmap ID style", "Optional integer"),
				stringControl(config, keys.mapper_id, "Mapper ID style", "Optional integer"),
				stringControl(config, keys.hold_note_ratio, "Hold-note ratio", "Optional number"),
				stringControl(config, keys.scroll_speed_ratio, "Scroll-speed-change ratio", "Optional number"),
			}
		end),
		makeSection("Generation", sprites.icon_clock, function()
			return {
				stringControl(config, keys.seed, "Random seed", "Blank for random"),
				numberControl(config, keys.cfg_scale, "Classifier-free guidance scale"),
				numberControl(config, keys.temperature, "Sampling temperature"),
				numberControl(config, keys.top_p, "Top-p threshold"),
				stringControl(config, keys.start_time, "Start time (ms)", "Blank for song start"),
				stringControl(config, keys.end_time, "End time (ms)", "Blank for song end"),
			}
		end),
		makeSection("Runtime", sprites.icon_gear, function()
			return {
				ControlFactory.choice(config, keys.device, {name = "Device", width = FORM_WIDTH}),
				ControlFactory.choice(config, keys.precision, {name = "Precision", width = FORM_WIDTH}),
				ControlFactory.choice(config, keys.attn_implementation, {name = "Attention implementation", width = FORM_WIDTH}),
				booleanControl(config, keys.hitsounded, "Add hitsounds"),
				booleanControl(config, keys.super_timing, "Use super timing"),
				booleanControl(config, keys.generate_positions, "Generate standard/catch positions with diffusion"),
				booleanControl(config, keys.export_osz, "Also export an .osz package"),
			}
		end),
		makeSection("Reference", sprites.icon_puzzle, function()
			return {
				note("These options use the managed copy of the reference beatmap; the original file is never overwritten."),
				booleanControl(config, keys.context_timing, "Use reference timing as context"),
				booleanControl(config, keys.context_kiai, "Use reference kiai as context"),
				booleanControl(config, keys.context_gd, "Use reference as guest-difficulty context"),
				booleanControl(config, keys.context_no_hs, "Use reference without hitsounds as context"),
				booleanControl(config, keys.add_to_beatmap, "Add generated content to reference map"),
				booleanControl(config, keys.overwrite_reference_beatmap, "Overwrite managed reference copy with result"),
			}
		end),
		makeSection("Descriptors", sprites.icon_funnel, function()
			return {
				note("Enter descriptor values separated by commas. Values match Mapperatorinator's user-tag and OMDB descriptor datasets."),
				stringControl(config, keys.descriptors, "Desired descriptors", "e.g. skillset/tech, style/geometric"),
				stringControl(config, keys.negative_descriptors, "Descriptors to avoid", "Used by classifier-free guidance"),
			}
		end),
		makeSection("Presets", sprites.icon_download, function()
			local row = FlowContainer({direction = "row", gap = 14})
			row:add(smallButton("Import", function() self:importPreset() end, 190))
			row:add(smallButton("Export", function() self:exportPreset() end, 190))
			row:add(smallButton("Reset", function() self:resetPreset() end, 190))
			row:fitContent()
			return {
				note("Import or export all native Mapperatorinator settings as JSON. These presets are separate from Mapperatorinator's Hydra YAML files."),
				row,
			}
		end),
	}
end

function Mapperatorinator:invalidateSettings()
	self.settings_invalidated = true
end

function Mapperatorinator:rebuildSettings()
	self.settings_invalidated = false
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form:clearRows()
	local header = Label({font_name = "bold", font_size = 32, text = self.selected_section.name})
	self.form:add(header)
	for _, control in ipairs(self.selected_section:build()) do
		self.form:add(control)
	end
	self.form:fitContent()
end

---@param key string
---@param title string
---@param filters string[]?
function Mapperatorinator:choosePath(key, title, filters)
	local path, err = self.file_picker:open(title, filters)
	if path then
		self.config:setString(key, path)
		self:invalidateSettings()
	elseif err then
		self.workflow.status = err
	end
end

function Mapperatorinator:importPreset()
	self.form:closeActiveDropdown()
	local path, picker_err = self.file_picker:open("Import Mapperatorinator preset", {"JSON presets | *.json"})
	if not path then
		if picker_err then self.workflow.status = picker_err end
		return
	end
	local content, read_err = self.host_fs:read(path)
	if not content then
		self.workflow.status = "Could not read preset: " .. tostring(read_err)
	elseif not self.config:deserialize(content) then
		self.workflow.status = "The selected preset is invalid or incompatible."
	else
		self.config:save()
		self.workflow.status = "Imported Mapperatorinator preset."
		self:invalidateSettings()
	end
end

function Mapperatorinator:exportPreset()
	local path, picker_err = self.file_picker:save(
		"Export Mapperatorinator preset", "mapperatorinator-preset.json", {"JSON presets | *.json"}
	)
	if not path then
		if picker_err then self.workflow.status = picker_err end
		return
	end
	if not path:lower():match("%.json$") then path = path .. ".json" end
	local ok, err = self.host_fs:write(path, self.config:serialize())
	self.workflow.status = ok and "Exported Mapperatorinator preset." or "Could not export preset: " .. tostring(err)
end

function Mapperatorinator:resetPreset()
	self.form:closeActiveDropdown()
	MapperatorinatorConfig.reset(self.config)
	self.config:save()
	self.workflow.status = "Reset Mapperatorinator settings to defaults."
	self:invalidateSettings()
end

---@param path string
function Mapperatorinator:setAudioPath(path)
	self.audio_path = path
	self.workflow.status = "Configure Mapperatorinator, then generate."
	if self.selected_section == self.sections[1] then self:invalidateSettings() end
end

function Mapperatorinator:generate()
	local ok, err = self.workflow:start(self.audio_path, self.config)
	if not ok then
		self.workflow.status = assert(err)
	else
		self.config:save()
	end
end

---@param dt number
function Mapperatorinator:update(dt)
	if self.settings_invalidated then self:rebuildSettings() end
	self.status_label:setText(self.workflow.status)
	self.status_label:setSize(FORM_WIDTH, 44)
	self.generate_button.text = self.workflow:isBusy() and "Working…" or "Generate"
end

function Mapperatorinator:show()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function Mapperatorinator:hide()
	self.form:closeActiveDropdown()
	self.config:save()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Mapperatorinator:draw()
	Painter.setColorTable(Colors.panel_alt)
	self.background:draw(self.width, self.height)
	Painter.setColorTable(Colors.panel)
	love.graphics.push()
	love.graphics.translate(SIDEBAR_WIDTH, 96)
	self.content_background:draw(WIDTH - SIDEBAR_WIDTH, 630)
	love.graphics.pop()
end

return Mapperatorinator
