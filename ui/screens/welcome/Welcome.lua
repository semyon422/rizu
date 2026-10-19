local Colors = require("ui.Colors")
local ChartFolderRow = require("ui.screens.welcome.ChartFolderRow")
local FlowContainer = require("gui.layout.FlowContainer")
local IconTextButton = require("ui.views.IconTextButton")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local LanguageTile = require("ui.screens.welcome.LanguageTile")
local MainMenuBackground = require("ui.screens.main_menu.MainMenuBackground")
local Panel = require("ui.views.Panel")
local Path = require("Path")
local Resources = require("ui.Resources")
local Screen = require("gui.Screen")
local Settings = require("rizu.config.Settings")
local Slider = require("ui.views.form.Slider")
local UiConfig = require("ui.UiConfig")
local View = require("gui.View")

---The first screen a newcomer sees: language, volume and the charts they already have.
---@class ui.screens.welcome.Welcome : gui.Screen
---@operator call: ui.screens.welcome.Welcome
---@field volume ui.views.Label
---@field volume_number gui.layout.FlowContainer
---@field volume_slider ui.views.form.Slider
---@field rows gui.layout.FlowContainer
---@field row_by_location {[integer]: ui.screens.welcome.ChartFolderRow}
---@field known_locations {[integer]: true}?
---@field scan_queue integer[] Locations to scan after the current scan, by id.
---@field scanning integer? The location this screen started scanning.
---@field scan_started boolean The game has reported the scan of `scanning`.
---@field right gui.layout.FlowContainer
---@field status ui.views.Label
---@field private other_games rizu.api.OtherGame[]? nil where the game cannot search for them.
---@field private locations_observer fun()?
---@field private volume_observer fun()?
---@field private cache_observer fun()?
local Welcome = Screen + {}

local GAME_ICONS = {["osu!"] = "game_osu", Etterna = "game_etterna", Quaver = "game_quaver"}

local EDGE = 72
local FOOTER_BOTTOM = 40
local COLUMN_WIDTH = 840
local COLUMN_TOP = 290
local RIGHT_X = 1010
local LANGUAGES_PER_ROW = 3

---@param path string
---@return string
local function normalizePath(path)
	return tostring(Path(path):normalize():toFile())
end

---@param text string
---@return ui.views.Label
local function sectionLabel(text)
	return Label({font_name = "bold", font_size = 20, text = text, color = Colors.muted})
end

---@param ui ui.UserInterface
function Welcome:new(ui)
	Screen.new(self)
	self.ui = ui
	self.root:setPivot(0.5, 0.5)
	-- Installed games do not change while the game runs.
	self.other_games = ui.api.library:findOtherGames()
	self.row_by_location = {}
	self.scan_queue = {}
	self.scanning = nil
	self.scan_started = false
	local localization = ui.localization

	self.root:add(MainMenuBackground(Resources.images.main_menu_bg)):anchorFill(0, 0, 0, 0)
	self.root:add(Image(Resources.sprites.result_v2_scrim_horizontal, "fit")):anchorFill(0, 0, 0, 0)

	local logo = self.root:add(Image(Resources.sprites.logo_rizu, "fit"))
	logo:setSize(307, 120):setPosition(EDGE, 48)
	local subtitle = self.root:add(FlowContainer({direction = "row", gap = 18, align = "baseline"}))
	subtitle:setPosition(EDGE, 188)
	subtitle:add(Label({font_name = "regular", font_size = 32, text = localization:get("welcome.welcome"), color = Colors.accent}))
	subtitle:add(Label({font_name = "regular", font_size = 32, text = localization:get("welcome.subtitle")}))
	subtitle:fitContent()

	local left = self.root:add(FlowContainer({direction = "column", gap = 18}))
	left:setPosition(EDGE, COLUMN_TOP)

	left:add(sectionLabel(localization:get("welcome.language")))
	local languages = left:add(FlowContainer({direction = "column", gap = 12}))
	local language = ui.config:getChoice(UiConfig.keys.language)
	---@type gui.layout.FlowContainer?
	local language_row
	for i, locale in ipairs(ui.config:getChoices(UiConfig.keys.language)) do
		if (i - 1) % LANGUAGES_PER_ROW == 0 then
			if language_row then language_row:fitContent() end
			language_row = languages:add(FlowContainer({direction = "row", gap = 12}))
		end
		language_row:add(LanguageTile(locale, locale == language, function()
			if locale == language then return end
			ui.config:setChoice(UiConfig.keys.language, locale)
			ui.config:save()
			ui.api.app:requestReload()
		end))
	end
	if language_row then language_row:fitContent() end
	languages:fitContent()

	left:add(View()):setSize(0, 38)
	local volume_header = left:add(FlowContainer({direction = "row", gap = 12, align = "baseline"}))
	volume_header:add(sectionLabel(localization:get("welcome.master_volume")))
	volume_header:add(Label({font_name = "medium", font_size = 22, text = localization:get("welcome.volume_hint"), color = Colors.accent}))
	volume_header:fitContent()

	local settings = ui.api.settings
	local volume_key = Settings.keys.audio.volume_master
	local volume_row = left:add(View())
	volume_row:setSize(COLUMN_WIDTH, 130)
	local number = volume_row:add(FlowContainer({direction = "row", gap = 6, align = "baseline"}))
	self.volume_number = number
	self.volume = number:add(Label({font_name = "bold", font_size = 120, text = "0", color = Colors.grade_s}))
	number:add(Label({font_name = "bold", font_size = 52, text = "%", color = Colors.grade_s}))
	number:fitContent()
	self.volume_slider = volume_row:add(Slider({
		label = "",
		value = settings:getNumber(volume_key),
		width = 540,
		on_change = function(value) settings:setNumber(volume_key, value) end,
	}))
	self.volume_slider:setPosition(COLUMN_WIDTH - 540, 66)
	left:fitContent()

	local right = self.root:add(FlowContainer({direction = "column", gap = 18}))
	right:setPosition(RIGHT_X, COLUMN_TOP)
	right:add(sectionLabel(localization:get(self.other_games and "welcome.other_games" or "welcome.chart_folders")))
	self.rows = right:add(FlowContainer({direction = "column", gap = 6}))
	right:add(IconTextButton({
		text = localization:get("welcome.add_folder"),
		icon = Resources.sprites.icon_folder,
		icon_color = Colors.accent,
		font_size = 18,
		on_click = function() ui.modal_manager:attachLocationEditor() end,
	}))
	self.status = right:add(Label({font_name = "regular", font_size = 18, text = "", color = Colors.danger}))
	self.right = right

	local continue = self.root:add(IconTextButton({
		text = localization:get("welcome.continue"),
		icon = Resources.sprites.icon_play,
		icon_after = true,
		variant = "success",
		font_size = 18,
		gap = 14,
		padding_left = 44,
		padding_right = 34,
		on_click = function() self:finish() end,
	}))
	continue:setAlignment(1, 1):addPosition(-EDGE, -FOOTER_BOTTOM)
end

---@param volume number
function Welcome:showVolume(volume)
	self.volume:setText(tostring(math.floor(volume * 100 + 0.5)))
	self.volume_slider:setValue(volume)
	self.volume_number:fitContent()
end

function Welcome:load()
	Screen.load(self)
	local settings, volume_key = self.ui.api.settings, Settings.keys.audio.volume_master
	self:showVolume(settings:getNumber(volume_key))
	-- Alt + Wheel changes it while the screen is open.
	self.volume_observer = settings:subscribeNumber(volume_key, function(volume) self:showVolume(volume) end)
	local library = self.ui.api.library
	self.locations_observer = library:on("locations_changed", function() self:refresh() end)
	self.cache_observer = library:on("cache_status_changed", function(status) self:onCacheStatus(status) end)
end

function Welcome:unload()
	if self.locations_observer then
		self.locations_observer()
		self.locations_observer = nil
	end
	if self.volume_observer then
		self.volume_observer()
		self.volume_observer = nil
	end
	if self.cache_observer then
		self.cache_observer()
		self.cache_observer = nil
	end
	Screen.unload(self)
end

---Lists the games found on this computer and the folders already added, and queues new folders for a scan.
function Welcome:refresh()
	local localization = self.ui.localization
	local library = self.ui.api.library
	self.rows:clear()
	self.row_by_location = {}

	local first_refresh = not self.known_locations
	---@type {[integer]: true}
	local known = {}
	---@type {[string]: rizu.api.Location}
	local by_path = {}
	for _, location in ipairs(library:getLocations()) do
		-- The game's own folder and remote catalogs are not chosen by the player.
		if not location.is_internal and not location.url then
			by_path[normalizePath(library:getLocationPath(location))] = location
			known[location.id] = true
			if not first_refresh and not self.known_locations[location.id] then
				table.insert(self.scan_queue, location.id)
			end
		end
	end
	self.known_locations = known

	---@param name string
	---@param path string
	---@param icon gui.Sprite?
	local function addRow(name, path, icon)
		local location = by_path[normalizePath(path)]
		local row = self.rows:add(ChartFolderRow({
			width = COLUMN_WIDTH,
			name = name,
			path = path,
			icon = icon,
			added = location ~= nil,
			add_text = localization:get("welcome.mount"),
			added_text = localization:get("welcome.mounted"),
			on_add = not location and function()
				local ok, err = library:addLocation(name, path)
				self.status:setText(ok and "" or localization:get("welcome.mount_error", {name = name, error = tostring(err)}))
			end or nil,
		}))
		if location then
			self.row_by_location[location.id] = row
			by_path[normalizePath(path)] = nil
		end
	end

	if self.other_games then
		for _, game in ipairs(self.other_games) do
			local icon = GAME_ICONS[game.name]
			addRow(game.name, game.songs, icon and Resources.sprites[icon])
		end
	end
	for path, location in pairs(by_path) do
		addRow(location.name, path)
	end

	if #self.rows.children == 0 then
		local empty = self.rows:add(View())
		empty:setSize(COLUMN_WIDTH, ChartFolderRow.HEIGHT)
		empty:add(Panel({color = {Colors.surface[1], Colors.surface[2], Colors.surface[3], 0.5}})):anchorFill(0, 0, 0, 0)
		local hint = empty:add(Label({font_name = "regular", font_size = 22, text = localization:get("welcome.add_folder_hint"), color = Colors.muted}))
		hint:setAlignment(0.5, 0.5):setPivot(0.5, 0.5)
	end
	self.rows:fitContent()
	self.right:fitContent()

	self:showScanStates()
	self:scanNext()
end

---@private
function Welcome:showScanStates()
	local localization = self.ui.localization
	local library = self.ui.api.library
	---@type {[integer]: true}
	local queued = {}
	for _, id in ipairs(self.scan_queue) do queued[id] = true end
	for _, location in ipairs(library:getLocations()) do
		local row = self.row_by_location[location.id]
		if row and location.id == self.scanning then
			row:setState(localization:get("welcome.scanning"), Colors.accent)
		elseif row and queued[location.id] then
			row:setState(localization:get("welcome.waiting"), Colors.muted)
		elseif row then
			row:setState(localization:get("welcome.charts", {count = library:getLocationInfo(location).charts}))
		end
	end
end

---Scans the next queued folder, unless the game is already scanning something.
---@private
function Welcome:scanNext()
	local library = self.ui.api.library
	if self.scanning or #self.scan_queue == 0 or library:getCacheStatus().stage ~= "idle" then
		return
	end
	local id = table.remove(self.scan_queue, 1)
	for _, location in ipairs(library:getLocations()) do
		if location.id == id then
			self.scanning = id
			self.scan_started = false
			-- Only one scan runs at a time: started while another runs, this would stop it instead.
			library:toggleCacheUpdate(location)
			break
		end
	end
	self:showScanStates()
end

---@param status rizu.api.CacheStatus
function Welcome:onCacheStatus(status)
	if status.stage ~= "idle" then
		local scanning = self.scanning
		if not scanning then return end
		self.scan_started = true
		local row = self.row_by_location[scanning]
		if row then
			local progress = status.total > 0 and ("%d / %d"):format(status.current, status.total) or tostring(status.current)
			row:setState(self.ui.localization:get("welcome.scanning_progress", {progress = progress}), Colors.accent)
		end
		return
	end
	-- An idle status before the scan started is the previous scan ending.
	if self.scanning and self.scan_started then
		self.scanning = nil
	end
	-- Lists the folders again with their new chart counts.
	if self.ui.screen_manager.input_screen == self then
		self:refresh()
	else
		self:scanNext()
	end
end

---Leaves for the main menu; the screen is not shown again.
function Welcome:finish()
	self.ui.config:setBoolean(UiConfig.keys.show_welcome, false)
	self.ui.config:save()
	-- Charts scanned while the screen was open are listed only after the list is queried again.
	self.ui.api.charts:refresh()
	self.ui:setScreen(self.ui.main_menu, true)
end

function Welcome:enter()
	self:refresh()
	-- Settles in from slightly larger and leaves growing, while the main menu grows in under it.
	self.root:setOpacity(0):setScale(1.03, 1.03)
	self.root:fadeIn(0.4, "OutQuart")
	self.root:scaleTo(1, 1, 0.4, "OutQuart")
end

function Welcome:exit()
	Screen.exit(self)
	self.root:fadeOut(0.3, "OutCubic")
	self.root:scaleTo(1.05, 1.05, 0.3, "OutCubic")
	return true
end

return Welcome
