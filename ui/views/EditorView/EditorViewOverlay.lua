local just = require("just")
local spherefonts = require("sphere.assets.fonts")
local imgui = require("imgui")
local gfx_util = require("gfx_util")

local Layout = require("ui.views.EditorView.Layout")

local tabs = {}

---@param self table
---@return rizu.editor.EditorViewContext
local function getOverlayContext(self)
	return self.game.editorModel.context:getViewContext()
end

---@param self table
---@return rizu.editor.EditorBmsOverlayContext
local function getBmsOverlayContext(self)
	local overlayActionService = self.editorViewServices.overlayActionService
	local overlayContext = getOverlayContext(self)
	local editorController = self.game.editorController

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

---@param self table
---@return rizu.editor.EditorInfoOverlayContext
local function getInfoOverlayContext(self)
	local metadata = self.game.editorModel.metadata
	local editorController = self.game.editorController

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

---@param t number
---@return string
local function to_ms(t)
	return math.floor(t * 1000) .. "ms"
end

---@param self table
function tabs.info(self)
	imgui.setSize(400, 1080, 400, 55)
	imgui.text("Chart info")

	local infoOverlayService = self.editorViewServices.infoOverlayService
	local infoOverlayContext = getInfoOverlayContext(self)
	infoOverlayService:editMetadata(infoOverlayContext, function(key, value)
		return imgui.input(key .. " input", value, key)
	end)

	imgui.separator()

	if imgui.button("save btn", "save") then
		infoOverlayService:save(infoOverlayContext)
	end
	just.sameline()
	if imgui.button("save to osu btn", "save to osu") then
		infoOverlayService:saveToOsu(infoOverlayContext)
	end
	if imgui.button("save to nanochart btn", "save to nanochart") then
		infoOverlayService:saveToNanoChart(infoOverlayContext)
	end

	love.graphics.push("all")
	love.graphics.setColor(1, 1, 1, 0.75)
	love.graphics.setFont(spherefonts.get("Noto Sans", 36))
	imgui.text("The editor")
	imgui.text("is in development")
	love.graphics.pop()
end

---@param self table
function tabs.audio(self)
	local audioState = self.editorViewServices.audioOverlayService:getState(getOverlayContext(self))
	imgui.text("playing sounds: " .. audioState.playingCount)
	imgui.text("offsync: " .. to_ms(audioState.offsync))

	local audioSettingsOverlayService = self.editorViewServices.audioSettingsOverlayService
	local audioSettingsOverlayContext = getOverlayContext(self)
	local audioSettingsState = audioSettingsOverlayService:getState(audioSettingsOverlayContext)
	local a = audioSettingsState.audio
	local v = a.volume
	if a.volumeType == "linear" then
		audioSettingsOverlayService:setVolume(audioSettingsOverlayContext, "master", imgui.slider1("v.master", v.master, "%0.2f", 0, 1, 0.01, "master"))
		audioSettingsOverlayService:setVolume(audioSettingsOverlayContext, "music", imgui.slider1("v.music", v.music, "%0.2f", 0, 1, 0.01, "music"))
		audioSettingsOverlayService:setVolume(audioSettingsOverlayContext, "keysounds", imgui.slider1("v.keysounds", v.keysounds, "%0.2f", 0, 1, 0.01, "keysounds"))
		audioSettingsOverlayService:setVolume(audioSettingsOverlayContext, "metronome", imgui.slider1("v.metronome", v.metronome, "%0.2f", 0, 1, 0.01, "metronome"))
	elseif a.volumeType == "logarithmic" then
		local logk = 20 / math.log(10)
		audioSettingsOverlayService:setVolume(audioSettingsOverlayContext, "master", imgui.logslider("v.master", v.master, "%ddB", -60, 0, 1, logk, "master"))
		audioSettingsOverlayService:setVolume(audioSettingsOverlayContext, "music", imgui.logslider("v.music", v.music, "%ddB", -60, 0, 1, logk, "music"))
		audioSettingsOverlayService:setVolume(audioSettingsOverlayContext, "keysounds", imgui.logslider("v.keysounds", v.keysounds, "%ddB", -60, 0, 1, logk, "keysounds"))
		audioSettingsOverlayService:setVolume(audioSettingsOverlayContext, "metronome", imgui.logslider("v.metronome", v.metronome, "%ddB", -60, 0, 1, logk, "metronome"))
	end

	imgui.separator()
	local mode = a.mode
	imgui.text("audio modes")
	imgui.text("primary: " .. mode.primary)
	imgui.text("secondary: " .. mode.secondary)

	imgui.separator()

	local ed = audioSettingsState.editor
	audioSettingsOverlayService:setAudioOffset(audioSettingsOverlayContext, imgui.slider1("ed.audioOffset", ed.audioOffset * 1000, "%dms", -200, 200, 1, "main audio offset") / 1000)
	audioSettingsOverlayService:setWaveformOffset(audioSettingsOverlayContext, imgui.slider1("ed.waveformOffset", ed.waveformOffset * 1000, "%dms", -200, 200, 1, "waveform offset") / 1000)

	imgui.separator()
	imgui.text("waveform")
	local wf = audioSettingsState.waveform
	audioSettingsOverlayService:setWaveformOpacity(audioSettingsOverlayContext, imgui.slider1("wf.opacity", wf.opacity, "%0.2f", 0, 1, 0.01, "opacity"))
	audioSettingsOverlayService:setWaveformScale(audioSettingsOverlayContext, imgui.slider1("wf.scale", wf.scale, "%0.2f", 0, 1, 0.01, "scale"))

	imgui.separator()
	if imgui.button("set as preview", "set this moment as a preview") then
		self.editorViewServices.overlayActionService:setPreviewTimeToSession(getOverlayContext(self))
	end
end

---@param self table
function tabs.timings(self)
	local overlayContext = getOverlayContext(self)
	local timingOverlayService = self.editorViewServices.timingOverlayService

	local dtp = timingOverlayService:getPoint(overlayContext)

	if imgui.button("prev tp", "<") and dtp.prev then
		timingOverlayService:scrollPrev(overlayContext)
	end
	just.sameline()
	if imgui.button("next tp", ">") and dtp.next then
		timingOverlayService:scrollNext(overlayContext)
	end
	just.sameline()
	imgui.label("dtp label", tostring(dtp))

	timingOverlayService:setShowTimings(
		overlayContext,
		imgui.checkbox("show timings", timingOverlayService:isShowTimings(overlayContext), "show timings")
	)

	local overlayActionService = self.editorViewServices.overlayActionService
	if imgui.button("ncbt", "detect tempo and offset") then
		overlayActionService:detectTempoOffset(overlayContext)
	end
	if overlayActionService:hasDetectedTempoOffset(overlayContext) then
		just.sameline()
		if imgui.button("ncbt apply", "apply") then
			overlayActionService:applyNcbt(overlayContext)
		end
	end

	imgui.separator()

	local vertex = dtp._vertex

	if dtp.vertex then
		imgui.text("Tempo: " .. dtp.vertex:getTempo() .. " bpm")
	end

	if not timingOverlayService:isGrabbed(overlayContext) then
		if not vertex then
			if imgui.button("split button", "split") then
				timingOverlayService:split(overlayContext, dtp)
			end
		elseif imgui.button("grab vertex button", "grab") then
			timingOverlayService:grab(overlayContext, vertex)
		end
	else
		if imgui.button("drop vertex button", "drop") then
			timingOverlayService:drop(overlayContext)
		end
	end
	if vertex and not timingOverlayService:isGrabbed(overlayContext) then
		just.sameline()
		if imgui.button("merge vertex button", "merge") then
			timingOverlayService:merge(overlayContext, vertex.point)
		end
		local beats = vertex.beats
		local newBeats = imgui.intButtons("update vertex", beats, 1, "beats")
		if beats ~= newBeats then
			timingOverlayService:update(overlayContext, vertex, newBeats)
		end
	end

	imgui.separator()

	local totalBeats, avgBeatDuration = overlayActionService:getTotalBeats(overlayContext)
	imgui.text("Total beats: " .. totalBeats)
	imgui.text("Average tempo: " .. 60 / avgBeatDuration .. " bpm")

	imgui.separator()

	local vp = timingOverlayService:getCommentVisualPoint(overlayContext, dtp)
	if vp then
		vp.temp_comment = imgui.input("vp comment", vp.temp_comment or vp.comment, "comment")
		if imgui.button("save comment", "save") then
			self.editorViewServices.overlayActionService:setVisualPointComment(vp, vp.temp_comment)
		end
		if imgui.button("reset comment", "reset") then
			self.editorViewServices.overlayActionService:resetVisualPointComment(vp)
		end
	end
end

local batch_comment = ""

---@param self table
function tabs.notes(self)
	local overlayContext = getOverlayContext(self)
	local notesOverlayService = self.editorViewServices.notesOverlayService
	local notesState = notesOverlayService:getState(overlayContext)

	local logSpeed = imgui.slider1("editor speed", notesState.logSpeed, "%d", -30, 50, 1, "speed")
	if logSpeed ~= notesState.logSpeed then
		notesOverlayService:setLogSpeed(overlayContext, logSpeed)
	end
	notesOverlayService:setSnap(
		overlayContext,
		imgui.slider1("snap select", notesState.snap, "%d", 1, notesState.maxSnap, 1, "snap")
	)
	notesOverlayService:setLockSnap(
		overlayContext,
		imgui.checkbox("lock snap", notesState.lockSnap, "lock snap")
	)
	notesOverlayService:setTool(
		overlayContext,
		imgui.combo("tool select", notesState.tool, notesState.tools, nil, "tool")
	)
	imgui.text("Use qwer to select tool")

	for i = 1, #notesState.tools do
		local key = ("qwerty"):sub(i, i)
		if just.keypressed(key) then
			notesOverlayService:setToolForHotkey(overlayContext, key)
		end
	end

	if imgui.button("changeType", "change type") then
		self.editorViewServices.overlayActionService:changeSelectedNoteType(overlayContext)
	end

	if notesState.hasSelectedNotes and imgui.button("scroll to note", "scroll to") then
		self.editorViewServices.overlayActionService:scrollToFirstSelectedNote(overlayContext)
	end

	imgui.separator()

	batch_comment = imgui.input("vps comment", batch_comment, "comment")
	if imgui.button("save comment notes", "save") then
		self.editorViewServices.overlayActionService:setSelectedNotesComment(overlayContext, batch_comment)
	end
	if imgui.button("reset comment notes", "reset") then
		self.editorViewServices.overlayActionService:resetSelectedNotesComment(overlayContext)
	end

	if notesState.selectedNoteSound then
		imgui.text(notesState.selectedNoteSound)
	end
end

---@param self table
function tabs.bms(self)
	local bmsOverlayService = self.editorViewServices.bmsOverlayService
	local bmsOverlayContext = getBmsOverlayContext(self)

	local bms_tools = bmsOverlayService:getBmsToolsContext(bmsOverlayContext)
	imgui.text("BMS creation tools")

	bmsOverlayService:setOffsetTempo(
		bmsOverlayContext,
		tonumber(imgui.input("offset", bms_tools.offset, "offset")) or 0,
		tonumber(imgui.input("tempo", bms_tools.tempo, "tempo")) or 120
	)

	if imgui.button("bms apply tempo", "apply") then
		bmsOverlayService:applyOffsetTempo(bmsOverlayContext)
	end

	imgui.text("offset")
	if imgui.button("bms add offset", "+1ms") then
		bmsOverlayService:changeOffset(bmsOverlayContext, 0.001)
	end
	just.sameline()
	if imgui.button("bms sub offset", "-1ms") then
		bmsOverlayService:changeOffset(bmsOverlayContext, -0.001)
	end

	if imgui.button("slice keysounds", "slice keysounds") then
		bmsOverlayService:sliceKeysounds(bmsOverlayContext)
	end

	bmsOverlayService:setBeatOffset(
		bmsOverlayContext,
		tonumber(imgui.input("beat_offset", bms_tools.beat_offset, "beat offset")) or 0
	)
	if imgui.button("create bms template 5K", "create bms template 5K") then
		bmsOverlayService:exportBmsTemplate(bmsOverlayContext, 5)
	end
	if imgui.button("create bms template 7K", "create bms template 7K") then
		bmsOverlayService:exportBmsTemplate(bmsOverlayContext, 7)
	end
	if imgui.button("create bms template 10K", "create bms template 10K") then
		bmsOverlayService:exportBmsTemplate(bmsOverlayContext, 10)
	end
	if imgui.button("export ubmsc", "export ubmsc") then
		bmsOverlayService:exportUBmsC(bmsOverlayContext)
	end
end

return function(self)
	local editorModel = self.game.editorModel
	local w, h = Layout:move("base")

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	love.graphics.setLineStyle("smooth")

	local lineHeight = 55
	imgui.setSize(400, h, 200, lineHeight)
	love.graphics.setColor(1, 1, 1, 1)

	local overlayActionService = self.editorViewServices.overlayActionService
	local overlayContext = getOverlayContext(self)
	overlayActionService:setOverlayState(
		overlayContext,
		imgui.tabs("editor overlay tabs", overlayActionService:getOverlayState(overlayContext), editorModel.states)
	)
	love.graphics.setColor(1, 1, 1, 1)
	imgui.setSize(400, h, 200, lineHeight)
	tabs[overlayActionService:getOverlayState(overlayContext)](self)

	if not editorModel:isResourcesLoaded() then
		w, h = Layout:move("base")
		love.graphics.setColor(1, 1, 1, 0.5)
		love.graphics.setFont(spherefonts.get("Noto Sans", 160))
		gfx_util.printFrame("loading", 0, 0, w, h, "center", "center")
	end
end
