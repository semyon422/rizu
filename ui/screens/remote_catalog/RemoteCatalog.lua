local Screen = require("gui.Screen")
local Label = require("ui.views.Label")
local Button = require("ui.views.Button")
local UiActions = require("ui.UiActions")
local RemoteCatalogList = require("ui.screens.remote_catalog.RemoteCatalogList")
local RemoteCatalogPreview = require("ui.screens.remote_catalog.RemoteCatalogPreview")
local RemoteCatalogLoader = require("rizu.library.RemoteCatalogLoader")
local RemoteAudioPreviewPlayer = require("rizu.preview.RemoteAudioPreviewPlayer")
local thread = require("thread")

---@class ui.screens.remote_catalog.RemoteCatalog : gui.Screen
---@operator call: ui.screens.remote_catalog.RemoteCatalog
local RemoteCatalog = Screen + {}

---@param bytes number
---@return string
local function formatBytes(bytes)
	if bytes >= 1024 * 1024 then
		return ("%.1f MiB"):format(bytes / 1024 / 1024)
	end
	return ("%.0f KiB"):format(bytes / 1024)
end

---@param ui ui.UserInterface
function RemoteCatalog:new(ui)
	Screen.new(self)
	self.ui = ui
	self.loader = RemoteCatalogLoader(ui.game.network, ui.game.fs)
	local BassProvider = require("rizu.engine.audio.bass.Provider")
	self.audio_player = RemoteAudioPreviewPlayer(ui.game.settings, BassProvider())
	self.loading = false
	self.preview_generation = 0

	self.title = self.root:add(Label({font_name = "bold", font_size = 36, text = "Remote catalog prototype"}))
	self.title:setPosition(48, 32)

	self.status = self.root:add(Label({font_name = "regular", font_size = 18, text = "Not loaded"}))
	self.status:setPosition(48, 86)

	self.list = self.root:add(RemoteCatalogList(function(item)
		self:selectItem(item)
	end))
	self.list:anchorFill(48, 128, 508, 96)

	self.preview = self.root:add(RemoteCatalogPreview())
	self.preview:setSize(412, 260):setAlignment(1, 0):setOffset(-48, 128)
	self.audio_status = self.root:add(Label({font_name = "regular", font_size = 16, text = "Audio preview idle"}))
	self.audio_status:setPosition(48, 400):setAlignmentX(1):setOffset(-48, 0)

	self.back = self.root:add(Button("Back", function()
		self.ui:setScreen(self.ui.main_menu)
	end))
	self.back:setSize(180, 52):setAlignment(0, 1):setOffset(48, -24)

	self.reload = self.root:add(Button("Reload", function()
		self:startDownload()
	end))
	self.reload:setSize(180, 52):setAlignment(1, 1):setOffset(-48, -24)
end

---@param item rizu.library.RemoteCatalogItem
function RemoteCatalog:selectItem(item)
	self.preview_generation = self.preview_generation + 1
	local generation = self.preview_generation
	self.audio_player:stop()
	self.audio_status:setText("Downloading audio preview...")
	thread.coro(function()
		local res, err = self.ui.game.network:download(item.preview_audio_url, {chunk_size = 64 * 1024})
		if generation ~= self.preview_generation then
			return
		end
		if not res then
			self.audio_status:setText("Audio error: " .. tostring(err))
			return
		end
		if res.status >= 400 then
			self.audio_status:setText("Audio error: HTTP " .. res.status)
			return
		end
		local played, play_err = self.audio_player:load(res.body)
		if not played then
			self.audio_status:setText("Audio decode error: " .. tostring(play_err))
			return
		end
		self.audio_status:setText(("Playing audio preview (%.0f KiB)"):format(#res.body / 1024))
	end)()

	if not item.background_url then
		self.preview:setImage(nil, "No background for this chart")
		return
	end
	self.preview:setImage(nil, "Loading background...")
	thread.coro(function()
		local image = self.ui.game.backgroundModel:loadImage(item.background_url, "http")
		if generation ~= self.preview_generation then
			if image then
				image:release()
			end
			return
		end
		if not image then
			self.preview:setImage(nil, "Could not load background")
			return
		end
		self.preview:setImage(image)
	end)()
end

---@param dt number
function RemoteCatalog:update(dt)
	Screen.update(self, dt)
	self.audio_player:update()
end

function RemoteCatalog:exit()
	self.preview_generation = self.preview_generation + 1
	self.audio_player:stop()
	Screen.exit(self)
	return true
end

function RemoteCatalog:unload()
	self.audio_player:stop()
	Screen.unload(self)
end

function RemoteCatalog:enter()
	if #self.list.items == 0 and not self.loading then
		self:startDownload()
	end
end

function RemoteCatalog:startDownload()
	if self.loading then
		return
	end
	self.loading = true
	self.preview_generation = self.preview_generation + 1
	self.audio_player:stop()
	self.audio_status:setText("Audio preview idle")
	self.preview:setImage(nil, "Loading catalog...")
	self.status:setText("Connecting to " .. self.loader.url)

	thread.coro(function()
		local items, err = self.loader:download(function(status)
			if status.state == "downloading" then
				local downloaded = status.downloaded or 0
				local total = status.total
				if total and total > 0 then
					self.status:setText(("Downloading catalog: %s / %s (%.0f%%)"):format(
						formatBytes(downloaded), formatBytes(total), downloaded / total * 100
					))
				else
					self.status:setText("Downloading catalog: " .. formatBytes(downloaded))
				end
			end
		end)
		self.loading = false
		if not items then
			self.status:setText("Catalog error: " .. tostring(err))
			return
		end
		self.list:setItems(items)
		if items[1] then
			self.list.selected_index = 1
			self:selectItem(items[1])
		else
			self.preview:setImage(nil, "Catalog is empty")
		end
		self.status:setText(("%d charts loaded from %s"):format(#items, self.loader.url))
	end)()
end

---@param inputs gui.Inputs
function RemoteCatalog:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu)
	end
end

return RemoteCatalog
