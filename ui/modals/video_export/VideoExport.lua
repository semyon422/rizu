local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local Label = require("ui.views.Label")
local ChartInfo = require("ui.screens.song_select_v2.ChartInfo")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---Saves the notes preview of the selected chart as an animated WebP without audio on a black background.
---This modal owns the frame: the game only supplies the encoder, so everything drawn here (the
---notes, a title) comes from the user interface and a custom UI draws its own.
---@class ui.modals.video_export.VideoExport : ui.ModalView
---@operator call: ui.modals.video_export.VideoExport
---@field api rizu.api.GameApi
---@field on_close fun()
---@field size_index integer
---@field fps_index integer
---@field length_index integer
local VideoExport = ModalView + {}

local WIDTH = 620
local HEIGHT = 384
local PADDING = 36
local BAR_Y = 282
local BAR_HEIGHT = 10

local SIZES = {{640, 360}, {960, 540}, {1280, 720}}
local FPS = {15, 30, 60}
local LENGTHS = {5, 10, 15, 30}

---@param api rizu.api.GameApi
---@param on_close fun()
function VideoExport:new(api, on_close)
	ModalView.new(self)
	self.api = api
	self.on_close = on_close
	self.size_index = 1
	self.fps_index = 2 -- 30 fps
	self.length_index = 1
	self.locked = false
	self.available = false
	self.status_text = ""
	self.shown_state = nil
	self:setSize(WIDTH, HEIGHT):setAlignment(0.5, 0.5):setPivot(0.5, 0.5)
	self:setOpacity(0):setVisible(false):setClip(true)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	})

	self.title = self:add(Label({font_name = "bold", font_size = 32, text = "Export chart preview"}))
	self.title:setPosition(PADDING, 28)

	local content_width = WIDTH - PADDING * 2
	self.size_button = self:add(Button("", function() self:cycle("size_index", SIZES) end, {
		variant = "secondary", shape = "capsule", font_size = 18,
	}))
	self.size_button:setSize(content_width, 44):setPosition(PADDING, 92)
	self.fps_button = self:add(Button("", function() self:cycle("fps_index", FPS) end, {
		variant = "secondary", shape = "capsule", font_size = 18,
	}))
	self.fps_button:setSize(content_width, 44):setPosition(PADDING, 146)
	self.length_button = self:add(Button("", function() self:cycle("length_index", LENGTHS) end, {
		variant = "secondary", shape = "capsule", font_size = 18,
	}))
	self.length_button:setSize(content_width, 44):setPosition(PADDING, 200)

	self.status = self:add(Label({
		font_name = "regular", font_size = 17, color = Colors.muted, text = "", align = "center",
	}))
	self.status:setSize(content_width, 28):setPosition(PADDING, 248)

	self.start_button = self:add(Button("Export", function() self:startExport() end, {
		variant = "primary", shape = "capsule", font_size = 18,
	}))
	self.start_button:setSize(200, 48):setPosition(WIDTH - PADDING - 200, HEIGHT - 48 - 28)
	self.close_button = self:add(Button("Close", function() self:requestClose() end, {
		variant = "secondary", shape = "capsule", font_size = 18,
	}))
	self.close_button:setSize(200, 48):setPosition(PADDING, HEIGHT - 48 - 28)

	self:refreshTexts()
end

---@private
---@param key string
---@param list table
function VideoExport:cycle(key, list)
	if self.locked then return end
	self[key] = self[key] % #list + 1
	self:refreshTexts()
end

---Where the export starts and how many seconds follow it: from the chart's audio preview position (the
---`preview_time` of the chartview) to the end of the audio range, moved back when too little would be left.
---@private
---@return number start
---@return number length
function VideoExport:getRange()
	local _, first, last = self.api.media:getPreviewTime()
	local chart = self.api.charts:getSelectedChart() ---@type table?
	local start = chart and tonumber(chart.preview_time) or first
	if start <= 0 then start = first end
	start = math.max(first, math.min(start, last - LENGTHS[1]))
	return start, math.max(last - start, 0)
end

---@private
---@return number
function VideoExport:getLength()
	local _, available = self:getRange()
	return math.min(LENGTHS[self.length_index], available)
end

---@private
function VideoExport:refreshTexts()
	local size = SIZES[self.size_index]
	self.size_button.text = ("Size: %dx%d"):format(size[1], size[2])
	self.fps_button.text = ("Frame rate: %d fps"):format(FPS[self.fps_index])
	self.length_button.text = ("Length: %d s"):format(LENGTHS[self.length_index])
end

---@private
function VideoExport:releaseNotesPreview()
	if self.notes_preview then self.notes_preview:release() end
	self.notes_preview, self.notes_error = nil, nil
end

---Called by the modal manager before it shows the modal.
function VideoExport:open()
	self.api.video_export:refresh()
	self.available = self.api.video_export:isAvailable()
	-- The note skin loads in the background while the user picks the options.
	self:releaseNotesPreview()
	local chart = self.api.charts:getSelectedChart()
	if chart then
		self.notes_preview, self.notes_error = self.api.media:createNotesPreview(chart)
	end
	self:updateTexts()
end

---@private
function VideoExport:startExport()
	local export = self.api.video_export
	if self.locked or not self.available then return end
	local chart = self.api.charts:getSelectedChart()
	local start = self:getRange()
	local length = self:getLength()
	if not chart or length <= 0 then
		self.status_text = "Nothing to export: the chart has no preview."
		return
	end

	local notes_preview = self.notes_preview
	if not notes_preview then
		self.status_text = tostring(self.notes_error or "Nothing to export: the chart has no preview.")
		return
	end
	if not notes_preview:isReady() then
		self.status_text = notes_preview:getError() or "The note skin is still loading, try again in a moment."
		return
	end

	local size = SIZES[self.size_index]
	local formatter = ChartviewFormatter(chart, self.api.settings)
	local details = {
		title = formatter:getTitle(),
		artist = formatter:getArtist(),
		chart_name = formatter:getName() or "",
	}
	details.difficulty, details.patterns, details.cells = ChartInfo.collect(formatter)
	local name = ("%s - %s [%s]"):format(chart.artist or "", chart.title or "", chart.name or "")
	local ok, err = export:start({
		width = size[1],
		height = size[2],
		fps = FPS[self.fps_index],
		duration = length,
		start_time = start,
		path = export:makePath(name),
		draw = function(time, dt, width, height)
			self:drawFrame(notes_preview, details, time, dt, width, height)
		end,
	})
	if not ok then
		self.status_text = tostring(err)
		return
	end
	self.locked = true
end

---@class ui.modals.video_export.VideoExport.Details
---@field title string
---@field artist string
---@field chart_name string
---@field difficulty {value: string, postfix: string, color: gui.Color}
---@field patterns string
---@field cells {value: string, label: string}[]

---One frame of the video. The canvas is cleared to black, everything else is drawn here.
---@private
---@param notes_preview rizu.video_export.NotesPlayer
---@param details ui.modals.video_export.VideoExport.Details
---@param time number
---@param dt number
---@param width integer
---@param height integer
function VideoExport:drawFrame(notes_preview, details, time, dt, width, height)
	notes_preview:draw(time, dt, width, height)
	self:drawDetails(details, width, height)
	self:drawChartInfo(details, height)
end

---A bold font at the size for this frame. The fonts are made at the final pixel size, because scaling a
---font drawn at 720p up to a bigger frame blurs the glyphs.
---@param size number Pixels in a 720 pixel tall frame.
---@param scale number
---@param name string? `cjk_bold` by default.
---@return love.Font
local function boldFont(size, scale, name)
	return Resources.getFont(name or "cjk_bold", math.floor(size * scale + 0.5))
end

---The difficulty, patterns and facts the song select shows, in a column from the top left.
---@private
---@param details ui.modals.video_export.VideoExport.Details
---@param height integer
function VideoExport:drawChartInfo(details, height)
	local lg = love.graphics
	local scale = height / 720
	local label_font = boldFont(24, scale, "bold")
	local postfix_font = boldFont(24, scale, "bold")
	local big_font = boldFont(96, scale, "bold")
	local value_font = boldFont(40, scale, "bold")
	local cell_label_font = boldFont(22, scale, "bold")
	local x = math.floor(20 * scale)

	lg.setFont(label_font)
	Painter.setColorTable(Colors.muted)
	local y = math.floor(16 * scale)
	lg.print("DIFFICULTY", x, y)
	lg.setFont(postfix_font)
	Painter.setColorTable(Colors.accent)
	lg.print(details.difficulty.postfix, x + label_font:getWidth("DIFFICULTY") + 16 * scale,
		y + label_font:getBaseline() - postfix_font:getBaseline())

	y = y + label_font:getHeight()
	lg.setFont(big_font)
	Painter.setColorTable(details.difficulty.color)
	lg.print(details.difficulty.value, x - 3 * scale, y)
	y = y + big_font:getHeight()

	lg.setFont(postfix_font)
	Painter.setColorTable(Colors.muted)
	lg.print(details.patterns, x, y)
	y = y + postfix_font:getHeight() + 14 * scale

	-- The cells: value, then its caption on the same baseline.
	local value_width = 0
	for _, cell in ipairs(details.cells) do
		value_width = math.max(value_width, value_font:getWidth(cell.value))
	end
	for _, cell in ipairs(details.cells) do
		lg.setFont(value_font)
		Painter.setColorTable(Colors.text)
		lg.print(cell.value, x, y)
		lg.setFont(cell_label_font)
		Painter.setColorTable(Colors.muted)
		lg.print(cell.label, x + value_width + 16 * scale, y + value_font:getBaseline() - cell_label_font:getBaseline())
		y = y + value_font:getHeight()
	end

	Painter.setColorRgb(1, 1, 1, 1)
end

---The title, artist and chart name the way the song select panel draws them, anchored to the bottom left.
---Sizes follow the frame height: the panel's sizes are for a 720 pixel tall frame.
---@private
---@param details ui.modals.video_export.VideoExport.Details
---@param width integer
---@param height integer
function VideoExport:drawDetails(details, width, height)
	local lg = love.graphics
	local scale = height / 720
	local title_font = boldFont(60, scale)
	local artist_font = boldFont(32, scale)
	local chart_name_font = boldFont(26, scale)
	local shadow = math.max(1, math.floor(2 * scale + 0.5))

	local x = math.floor(20 * scale)
	local y = height - title_font:getHeight() - artist_font:getHeight() - math.floor(16 * scale)

	lg.setFont(title_font)
	Painter.setColorRgb(0, 0, 0, 0.25)
	lg.print(details.title, x + shadow, y + shadow)
	Painter.setColorTable(Colors.text)
	lg.print(details.title, x, y)

	local artist_y = y + title_font:getHeight()
	lg.setFont(artist_font)
	Painter.setColorRgb(0, 0, 0, 0.25)
	lg.print(details.artist, x + shadow, artist_y + shadow)
	Painter.setColorTable(Colors.accent)
	lg.print(details.artist, x, artist_y)

	if details.chart_name ~= "" then
		local name_x = x + artist_font:getWidth(details.artist) + 24 * scale
		-- Share the artist's baseline, the fonts differ in size.
		local name_y = artist_y + artist_font:getBaseline() - chart_name_font:getBaseline()
		lg.setFont(chart_name_font)
		Painter.setColorRgb(0, 0, 0, 0.25)
		lg.print(details.chart_name, name_x + shadow, name_y + shadow)
		Painter.setColorTable(Colors.text)
		lg.print(details.chart_name, name_x, name_y)
	end

	Painter.setColorRgb(1, 1, 1, 1)
end

---@private
function VideoExport:requestClose()
	if self.locked then return end
	self.on_close()
end

---@private
function VideoExport:updateTexts()
	local export = self.api.video_export
	local state = export:getState()
	local text
	if not self.available then
		text = "ffmpeg was not found. Install it and make sure it is on your PATH."
	elseif state == "running" then
		text = ("Rendering… %d%%"):format(math.floor(export:getProgress() * 100))
	elseif state == "finishing" then
		text = "Encoding… this can take a moment."
	elseif state == "failed" then
		text = "Export failed: " .. tostring(export:getError())
	elseif state == "done" and self.finished then
		text = "Saved to " .. tostring(export:getOutputPath())
	else
		text = self.status_text
	end
	if text ~= self.status_text_shown then
		self.status_text_shown = text
		self.status:setText(text)
	end
	self.start_button.text = self.available and "Export" or "Retry"
end

---@param dt number
function VideoExport:update(dt)
	local export = self.api.video_export
	if self.locked then
		export:update()
		if not export:isRunning() then
			self.locked = false
			self.finished = export:getState() == "done"
		end
	end
	self:updateTexts()
end

function VideoExport:show()
	self.finished = false
	self.status_text = ""
	self:setVisible(true)
	self:fadeIn(0.25, "OutCubic")
end

function VideoExport:hide()
	self.api.video_export:cancel()
	self:releaseNotesPreview()
	self:transformTo("opacity", 0, 0.18, "InCubic", function()
		self:setVisible(false)
	end)
end

function VideoExport:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)

	local export = self.api.video_export
	local x, w = PADDING, WIDTH - PADDING * 2
	Painter.setColorTable(Colors.surface)
	Resources.sprites.pixel:draw(x, BAR_Y, 0, w, BAR_HEIGHT)
	local progress = export:getProgress()
	if progress > 0 then
		Painter.setColorTable(Colors.accent)
		Resources.sprites.pixel:draw(x, BAR_Y, 0, w * progress, BAR_HEIGHT)
	end
	Painter.setColorRgb(1, 1, 1, 1)
end

return VideoExport
