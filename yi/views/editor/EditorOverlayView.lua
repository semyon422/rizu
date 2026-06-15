local View = require("gui.View")
local gfx_util = require("gfx_util")
local spherefonts = require("sphere.assets.fonts")
local EditorGui = require("yi.views.editor.EditorGui")

local EditorLayout = require("yi.views.editor.EditorLayout")

---@class yi.views.editor.EditorOverlayView: gui.View
---@operator call: yi.views.editor.EditorOverlayView
---@field screen table
---@field gui yi.views.editor.EditorGui
---@field batch_comment string
---@field cursorX number
---@field cursorY number
---@field panelWidth number
---@field lineHeight number
local EditorOverlayView = View + {}

---@param screen table
function EditorOverlayView:new(screen)
	View.new(self)
	self.screen = screen
	self.gui = EditorGui()
	self.batch_comment = ""
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self:setSize(love.graphics.getDimensions())
end

function EditorOverlayView:load()
	self:setSize(love.graphics.getDimensions())
end

---@param screen_x number
---@param screen_y number
---@return boolean
function EditorOverlayView:isMouseOver(screen_x, screen_y)
	return self.gui:containsPoint(screen_x, screen_y)
end

---@param e gui.MouseDownEvent
function EditorOverlayView:onMouseDown(e)
	return self.gui:onMouseDown(e)
end

---@param e gui.MouseUpEvent
function EditorOverlayView:onMouseUp(e)
	return self.gui:onMouseUp(e)
end

---@param e gui.DragEvent
function EditorOverlayView:onDrag(e)
	return self.gui:onDrag(e)
end

---@param e gui.DragEndEvent
function EditorOverlayView:onDragEnd(e)
	return self.gui:onDragEnd(e)
end

---@param e gui.KeyDownEvent
function EditorOverlayView:onKeyDown(e)
	return self.gui:onKeyDown(e)
end

---@param e gui.TextInputEvent
function EditorOverlayView:onTextInput(e)
	return self.gui:onTextInput(e)
end

---@return rizu.editor.EditorViewContext
function EditorOverlayView:getOverlayContext()
	return self.screen.game.editorModel.context:getViewContext()
end

---@return rizu.editor.EditorBmsOverlayContext
function EditorOverlayView:getBmsOverlayContext()
	local screen = self.screen
	local overlayActionService = screen.editorViewServices.overlayActionService
	local overlayContext = self:getOverlayContext()
	local editorController = screen.game.editorController

	return {
		getBmsToolsContext = function()
			return overlayContext:getBmsToolsContext()
		end,
		applyBmsOffsetTempo = function()
			overlayActionService:applyBmsOffsetTempo(overlayContext)
		end,
		changeBmsOffset = function(_, delta)
			overlayActionService:changeBmsOffset(overlayContext, delta)
		end,
		sliceKeysounds = function()
			editorController:sliceKeysounds()
		end,
		exportBmsTemplate = function(_, columnsOut)
			editorController:exportBmsTemplate(columnsOut)
		end,
		exportUBmsC = function()
			editorController:exportUBmsC()
		end,
	}
end

---@return rizu.editor.EditorInfoOverlayContext
function EditorOverlayView:getInfoOverlayContext()
	local screen = self.screen
	local metadata = screen.game.editorModel.metadata
	local editorController = screen.game.editorController

	return {
		iterMetadata = function()
			return metadata:iter()
		end,
		setMetadata = function(_, key, value)
			metadata:set(key, value)
		end,
		save = function()
			editorController:save()
		end,
		saveToOsu = function()
			editorController:saveToOsu()
		end,
		saveToNanoChart = function()
			editorController:saveToNanoChart()
		end,
	}
end

---@param seconds number
---@return string
local function to_ms(seconds)
	return math.floor(seconds * 1000) .. "ms"
end

function EditorOverlayView:resetPanel()
	self.cursorX = 0
	self.cursorY = 55
	self.panelWidth = 400
	self.lineHeight = 55
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
end

---@param text string
function EditorOverlayView:text(text)
	self.gui:label(text, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
end

function EditorOverlayView:separator()
	self.cursorY = self.cursorY + 10
	love.graphics.setColor(1, 1, 1, 0.25)
	love.graphics.line(self.cursorX, self.cursorY, self.cursorX + self.panelWidth, self.cursorY)
	self.cursorY = self.cursorY + 10
end

---@param id string
---@param text string
---@param width number?
---@return boolean clicked
function EditorOverlayView:button(id, text, width)
	local clicked = self.gui:button(id, text, self.cursorX, self.cursorY, width or self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
	return clicked
end

---@param id string
---@param text string
---@return boolean clicked
function EditorOverlayView:smallButton(id, text)
	local clicked = self.gui:button(id, text, self.cursorX, self.cursorY, 90, self.lineHeight)
	self.cursorX = self.cursorX + 100
	return clicked
end

function EditorOverlayView:endRow()
	self.cursorX = 0
	self.cursorY = self.cursorY + self.lineHeight
end

---@param id string
---@param value number
---@param minValue number
---@param maxValue number
---@param step number
---@param label string
---@return number
function EditorOverlayView:slider(id, value, minValue, maxValue, step, label)
	local newValue = self.gui:slider(id, value, minValue, maxValue, step, label, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
	return newValue
end

---@param id string
---@param value string|number
---@param label string
---@return string
function EditorOverlayView:input(id, value, label)
	local newValue = self.gui:input(id, tostring(value), label, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
	return newValue
end

function EditorOverlayView:drawInfoTab()
	local screen = self.screen
	self:text("Chart info")

	local infoOverlayService = screen.editorViewServices.infoOverlayService
	local infoOverlayContext = self:getInfoOverlayContext()
	infoOverlayService:editMetadata(infoOverlayContext, function(key, value)
		return self:input(key .. " input", value, key)
	end)

	self:separator()

	if self:smallButton("save btn", "save") then
		infoOverlayService:save(infoOverlayContext)
	end
	if self:smallButton("save to osu btn", "save osu") then
		infoOverlayService:saveToOsu(infoOverlayContext)
	end
	self:endRow()
	if self:button("save to nanochart btn", "save to nanochart") then
		infoOverlayService:saveToNanoChart(infoOverlayContext)
	end

	love.graphics.push("all")
	love.graphics.setColor(1, 1, 1, 0.75)
	love.graphics.setFont(spherefonts.get("Noto Sans", 36))
	self.gui:label("The editor", 0, self.cursorY, self.panelWidth, 48)
	self.gui:label("is in development", 0, self.cursorY + 48, self.panelWidth, 48)
	love.graphics.pop()
	self.cursorY = self.cursorY + 96
end

function EditorOverlayView:drawAudioTab()
	local screen = self.screen
	local overlayContext = self:getOverlayContext()
	local audioState = screen.editorViewServices.audioOverlayService:getState(overlayContext)
	self:text("playing sounds: " .. audioState.playingCount)
	self:text("offsync: " .. to_ms(audioState.offsync))

	local audioSettingsOverlayService = screen.editorViewServices.audioSettingsOverlayService
	local audioSettingsState = audioSettingsOverlayService:getState(overlayContext)
	local a = audioSettingsState.audio
	local v = a.volume
	if a.volumeType == "linear" then
		audioSettingsOverlayService:setVolume(overlayContext, "master", self:slider("v.master", v.master, 0, 1, 0.01, ("master %0.2f"):format(v.master)))
		audioSettingsOverlayService:setVolume(overlayContext, "music", self:slider("v.music", v.music, 0, 1, 0.01, ("music %0.2f"):format(v.music)))
		audioSettingsOverlayService:setVolume(overlayContext, "keysounds", self:slider("v.keysounds", v.keysounds, 0, 1, 0.01, ("keysounds %0.2f"):format(v.keysounds)))
		audioSettingsOverlayService:setVolume(overlayContext, "metronome", self:slider("v.metronome", v.metronome, 0, 1, 0.01, ("metronome %0.2f"):format(v.metronome)))
	else
		audioSettingsOverlayService:setVolume(overlayContext, "master", self:slider("v.master", v.master, -60, 0, 1, ("master %ddB"):format(v.master)))
		audioSettingsOverlayService:setVolume(overlayContext, "music", self:slider("v.music", v.music, -60, 0, 1, ("music %ddB"):format(v.music)))
		audioSettingsOverlayService:setVolume(overlayContext, "keysounds", self:slider("v.keysounds", v.keysounds, -60, 0, 1, ("keysounds %ddB"):format(v.keysounds)))
		audioSettingsOverlayService:setVolume(overlayContext, "metronome", self:slider("v.metronome", v.metronome, -60, 0, 1, ("metronome %ddB"):format(v.metronome)))
	end

	self:separator()
	self:text("audio modes")
	self:text("primary: " .. a.mode.primary)
	self:text("secondary: " .. a.mode.secondary)

	self:separator()
	local ed = audioSettingsState.editor
	audioSettingsOverlayService:setAudioOffset(overlayContext, self:slider("ed.audioOffset", ed.audioOffset * 1000, -200, 200, 1, ("main audio offset %dms"):format(ed.audioOffset * 1000)) / 1000)
	audioSettingsOverlayService:setWaveformOffset(overlayContext, self:slider("ed.waveformOffset", ed.waveformOffset * 1000, -200, 200, 1, ("waveform offset %dms"):format(ed.waveformOffset * 1000)) / 1000)

	self:separator()
	self:text("waveform")
	local wf = audioSettingsState.waveform
	audioSettingsOverlayService:setWaveformOpacity(overlayContext, self:slider("wf.opacity", wf.opacity, 0, 1, 0.01, ("opacity %0.2f"):format(wf.opacity)))
	audioSettingsOverlayService:setWaveformScale(overlayContext, self:slider("wf.scale", wf.scale, 0, 1, 0.01, ("scale %0.2f"):format(wf.scale)))

	self:separator()
	if self:button("set as preview", "set this moment as a preview") then
		screen.editorViewServices.overlayActionService:setPreviewTimeToSession(overlayContext)
	end
end

function EditorOverlayView:drawTimingsTab()
	local screen = self.screen
	local overlayContext = self:getOverlayContext()
	local timingOverlayService = screen.editorViewServices.timingOverlayService
	local overlayActionService = screen.editorViewServices.overlayActionService

	local dtp = timingOverlayService:getPoint(overlayContext)

	if self:smallButton("prev tp", "<") and dtp.prev then
		timingOverlayService:scrollPrev(overlayContext)
	end
	if self:smallButton("next tp", ">") and dtp.next then
		timingOverlayService:scrollNext(overlayContext)
	end
	self:endRow()
	self:text(tostring(dtp))

	timingOverlayService:setShowTimings(
		overlayContext,
		self.gui:checkbox("show timings", timingOverlayService:isShowTimings(overlayContext), "show timings", self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	)
	self.cursorY = self.cursorY + self.lineHeight

	if self:button("ncbt", "detect tempo and offset") then
		overlayActionService:detectTempoOffset(overlayContext)
	end
	if overlayActionService:hasDetectedTempoOffset(overlayContext) and self:button("ncbt apply", "apply") then
		overlayActionService:applyNcbt(overlayContext)
	end

	self:separator()

	local vertex = dtp._vertex
	if dtp.vertex then
		self:text("Tempo: " .. dtp.vertex:getTempo() .. " bpm")
	end

	if not timingOverlayService:isGrabbed(overlayContext) then
		if not vertex then
			if self:button("split button", "split") then
				timingOverlayService:split(overlayContext, dtp)
			end
		elseif self:button("grab vertex button", "grab") then
			timingOverlayService:grab(overlayContext, vertex)
		end
	elseif self:button("drop vertex button", "drop") then
		timingOverlayService:drop(overlayContext)
	end

	if vertex and not timingOverlayService:isGrabbed(overlayContext) then
		if self:button("merge vertex button", "merge") then
			timingOverlayService:merge(overlayContext, vertex.point)
		end
		local beats = vertex.beats
		local newBeats = self:slider("update vertex", beats, 1, 64, 1, "beats " .. beats)
		if beats ~= newBeats then
			timingOverlayService:update(overlayContext, vertex, newBeats)
		end
	end

	self:separator()

	local totalBeats, avgBeatDuration = overlayActionService:getTotalBeats(overlayContext)
	self:text("Total beats: " .. totalBeats)
	self:text("Average tempo: " .. 60 / avgBeatDuration .. " bpm")

	self:separator()

	local vp = timingOverlayService:getCommentVisualPoint(overlayContext, dtp)
	if vp then
		vp.temp_comment = self:input("vp comment", vp.temp_comment or vp.comment, "comment")
		if self:button("save comment", "save") then
			screen.editorViewServices.overlayActionService:setVisualPointComment(vp, vp.temp_comment)
		end
		if self:button("reset comment", "reset") then
			screen.editorViewServices.overlayActionService:resetVisualPointComment(vp)
		end
	end
end

function EditorOverlayView:drawNotesTab()
	local screen = self.screen
	local overlayContext = self:getOverlayContext()
	local notesOverlayService = screen.editorViewServices.notesOverlayService
	local notesState = notesOverlayService:getState(overlayContext)

	local logSpeed = self:slider("editor speed", notesState.logSpeed, -30, 50, 1, "speed " .. notesState.logSpeed)
	if logSpeed ~= notesState.logSpeed then
		notesOverlayService:setLogSpeed(overlayContext, logSpeed)
	end
	notesOverlayService:setSnap(
		overlayContext,
		self:slider("snap select", notesState.snap, 1, notesState.maxSnap, 1, "snap " .. notesState.snap)
	)
	notesOverlayService:setLockSnap(
		overlayContext,
		self.gui:checkbox("lock snap", notesState.lockSnap, "lock snap", self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	)
	self.cursorY = self.cursorY + self.lineHeight
	notesOverlayService:setTool(
		overlayContext,
		self.gui:combo("tool select", notesState.tool, notesState.tools, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	)
	self.cursorY = self.cursorY + self.lineHeight
	self:text("Use qwer to select tool")

	for i = 1, #notesState.tools do
		local key = ("qwerty"):sub(i, i)
		if self.gui:consumeKey(key) then
			notesOverlayService:setToolForHotkey(overlayContext, key)
		end
	end

	if self:button("changeType", "change type") then
		screen.editorViewServices.overlayActionService:changeSelectedNoteType(overlayContext)
	end

	if notesState.hasSelectedNotes and self:button("scroll to note", "scroll to") then
		screen.editorViewServices.overlayActionService:scrollToFirstSelectedNote(overlayContext)
	end

	self:separator()

	self.batch_comment = self:input("vps comment", self.batch_comment, "comment")
	if self:button("save comment notes", "save") then
		screen.editorViewServices.overlayActionService:setSelectedNotesComment(overlayContext, self.batch_comment)
	end
	if self:button("reset comment notes", "reset") then
		screen.editorViewServices.overlayActionService:resetSelectedNotesComment(overlayContext)
	end

	if notesState.selectedNoteSound then
		self:text(notesState.selectedNoteSound)
	end
end

function EditorOverlayView:drawBmsTab()
	local screen = self.screen
	local bmsOverlayService = screen.editorViewServices.bmsOverlayService
	local bmsOverlayContext = self:getBmsOverlayContext()

	local bms_tools = bmsOverlayService:getBmsToolsContext(bmsOverlayContext)
	self:text("BMS creation tools")

	bmsOverlayService:setOffsetTempo(
		bmsOverlayContext,
		tonumber(self:input("offset", bms_tools.offset, "offset")) or 0,
		tonumber(self:input("tempo", bms_tools.tempo, "tempo")) or 120
	)

	if self:button("bms apply tempo", "apply") then
		bmsOverlayService:applyOffsetTempo(bmsOverlayContext)
	end

	self:text("offset")
	if self:smallButton("bms add offset", "+1ms") then
		bmsOverlayService:changeOffset(bmsOverlayContext, 0.001)
	end
	if self:smallButton("bms sub offset", "-1ms") then
		bmsOverlayService:changeOffset(bmsOverlayContext, -0.001)
	end
	self:endRow()

	if self:button("slice keysounds", "slice keysounds") then
		bmsOverlayService:sliceKeysounds(bmsOverlayContext)
	end

	bmsOverlayService:setBeatOffset(
		bmsOverlayContext,
		tonumber(self:input("beat_offset", bms_tools.beat_offset, "beat offset")) or 0
	)
	if self:button("create bms template 5K", "create bms template 5K") then
		bmsOverlayService:exportBmsTemplate(bmsOverlayContext, 5)
	end
	if self:button("create bms template 7K", "create bms template 7K") then
		bmsOverlayService:exportBmsTemplate(bmsOverlayContext, 7)
	end
	if self:button("create bms template 10K", "create bms template 10K") then
		bmsOverlayService:exportBmsTemplate(bmsOverlayContext, 10)
	end
	if self:button("export ubmsc", "export ubmsc") then
		bmsOverlayService:exportUBmsC(bmsOverlayContext)
	end
end

function EditorOverlayView:drawActiveTab()
	local state = self.screen.editorViewServices.overlayActionService:getOverlayState(self:getOverlayContext())

	if state == "info" then
		self:drawInfoTab()
	elseif state == "audio" then
		self:drawAudioTab()
	elseif state == "timings" then
		self:drawTimingsTab()
	elseif state == "notes" then
		self:drawNotesTab()
	elseif state == "bms" then
		self:drawBmsTab()
	end
end

function EditorOverlayView:drawLoading()
	if self.screen.game.editorModel:isResourcesLoaded() then
		return
	end

	local w, h = EditorLayout:move("base")
	love.graphics.setColor(1, 1, 1, 0.5)
	love.graphics.setFont(spherefonts.get("Noto Sans", 160))
	gfx_util.printFrame("loading", 0, 0, w, h, "center", "center")
end

function EditorOverlayView:draw()
	local screen = self.screen
	local editorModel = screen.game.editorModel
	local _, h = EditorLayout:move("base")

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	love.graphics.setLineStyle("smooth")

	local overlayActionService = screen.editorViewServices.overlayActionService
	local overlayContext = self:getOverlayContext()
	overlayActionService:setOverlayState(
		overlayContext,
		self.gui:tabs("editor overlay tabs", overlayActionService:getOverlayState(overlayContext), editorModel.states, 0, 0, 400, 55)
	)

	love.graphics.setColor(0, 0, 0, 0.35)
	love.graphics.rectangle("fill", 0, 55, 420, h - 55)
	love.graphics.setColor(1, 1, 1, 1)
	self:resetPanel()
	self:drawActiveTab()
	self:drawLoading()
	self.gui:finishFrame()
end

return EditorOverlayView
