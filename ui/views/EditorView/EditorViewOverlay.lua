local just = require("just")
local spherefonts = require("sphere.assets.fonts")
local imgui = require("imgui")
local Fraction = require("ncdk.Fraction")
local gfx_util = require("gfx_util")

local Layout = require("ui.views.EditorView.Layout")

local tabs = {}

---@param t number
---@return string
local function to_ms(t)
	return math.floor(t * 1000) .. "ms"
end

---@param self table
function tabs.info(self)
	---@type rizu.editor.EditorModel
	local editorModel = self.game.editorModel

	imgui.setSize(400, 1080, 400, 55)
	imgui.text("Chart info")

	for k, v in editorModel.metadata:iter() do
		v = imgui.input(k .. " input", v, k)
		editorModel.metadata:set(k, v)
	end

	imgui.separator()

	if imgui.button("save btn", "save") then
		self.game.editorController:save()
	end
	just.sameline()
	if imgui.button("save to osu btn", "save to osu") then
		self.game.editorController:saveToOsu()
	end
	if imgui.button("save to nanochart btn", "save to nanochart") then
		self.game.editorController:saveToNanoChart()
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
	local editorModel = self.game.editorModel

	local playing = 0
	for _ in pairs(editorModel.audioManager.sources) do
		playing = playing + 1
	end
	imgui.text("playing sounds: " .. playing)
	imgui.text("offsync: " .. to_ms(editorModel.timer:getAudioOffsync() or 0))

	local settings = self.game.configModel.configs.settings
	local a = settings.audio
	local v = a.volume
	if a.volumeType == "linear" then
		v.master = imgui.slider1("v.master", v.master, "%0.2f", 0, 1, 0.01, "master")
		v.music = imgui.slider1("v.music", v.music, "%0.2f", 0, 1, 0.01, "music")
		v.keysounds = imgui.slider1("v.keysounds", v.keysounds, "%0.2f", 0, 1, 0.01, "keysounds")
		v.metronome = imgui.slider1("v.metronome", v.metronome, "%0.2f", 0, 1, 0.01, "metronome")
	elseif a.volumeType == "logarithmic" then
		local logk = 20 / math.log(10)
		v.master = imgui.logslider("v.master", v.master, "%ddB", -60, 0, 1, logk, "master")
		v.music = imgui.logslider("v.music", v.music, "%ddB", -60, 0, 1, logk, "music")
		v.keysounds = imgui.logslider("v.keysounds", v.keysounds, "%ddB", -60, 0, 1, logk, "keysounds")
		v.metronome = imgui.logslider("v.metronome", v.metronome, "%ddB", -60, 0, 1, logk, "metronome")
	end

	imgui.separator()
	local mode = a.mode
	imgui.text("audio modes")
	imgui.text("primary: " .. mode.primary)
	imgui.text("secondary: " .. mode.secondary)

	imgui.separator()

	local ed = settings.editor
	ed.audioOffset = imgui.slider1("ed.audioOffset", ed.audioOffset * 1000, "%dms", -200, 200, 1, "main audio offset") / 1000
	ed.waveformOffset = imgui.slider1("ed.waveformOffset", ed.waveformOffset * 1000, "%dms", -200, 200, 1, "waveform offset") / 1000

	imgui.separator()
	imgui.text("waveform")
	local wf = self.game.configModel.configs.settings.editor.waveform
	wf.opacity = imgui.slider1("wf.opacity", wf.opacity, "%0.2f", 0, 1, 0.01, "opacity")
	wf.scale = imgui.slider1("wf.scale", wf.scale, "%0.2f", 0, 1, 0.01, "scale")

	imgui.separator()
	local md = self.game.editorModel.chartmeta
	if imgui.button("set as preview", "set this moment as a preview") then
		md.preview_time = editorModel.session.point.absoluteTime
	end
end

local velocity = "1"
local expand = {"0", "1"}

---@param self table
function tabs.timings(self)
	local editorModel = self.game.editorModel
	local editor = self.game.configModel.configs.settings.editor
	local layer = editorModel.layer

	local dtp = editorModel.session.point

	if imgui.button("prev tp", "<") and dtp.prev then
		editorModel.scroller:scrollTimePoint(dtp.prev)
	end
	just.sameline()
	if imgui.button("next tp", ">") and dtp.next then
		editorModel.scroller:scrollTimePoint(dtp.next)
	end
	just.sameline()
	imgui.label("dtp label", tostring(dtp))

	editor.showTimings = imgui.checkbox("show timings", editor.showTimings, "show timings")

	if imgui.button("ncbt", "detect tempo and offset") then
		editorModel:detectTempoOffset()
	end
	if editorModel.ncbtContext.tempo then
		just.sameline()
		if imgui.button("ncbt apply", "apply") then
			editorModel:applyNcbt()
		end
	end

	imgui.separator()

	local vertex = dtp._vertex
	local intervalManager = editorModel.intervalManager

	if dtp.vertex then
		imgui.text("Tempo: " .. dtp.vertex:getTempo() .. " bpm")
	end

	if not intervalManager:isGrabbed() then
		if not vertex then
			if imgui.button("split button", "split") then
				intervalManager:split(dtp)
			end
		elseif imgui.button("grab vertex button", "grab") then
			intervalManager:grab(vertex)
		end
	else
		if imgui.button("drop vertex button", "drop") then
			intervalManager:drop()
		end
	end
	if vertex and not intervalManager:isGrabbed() then
		just.sameline()
		if imgui.button("merge vertex button", "merge") then
			intervalManager:merge(vertex.point)
			editorModel.scroller:scrollSecondsDelta(0)
		end
		local beats = vertex.beats
		local newBeats = imgui.intButtons("update vertex", beats, 1, "beats")
		if beats ~= newBeats then
			intervalManager:update(vertex, newBeats)
		end
	end

	imgui.separator()

	local totalBeats, avgBeatDuration = editorModel:getTotalBeats()
	imgui.text("Total beats: " .. totalBeats)
	imgui.text("Average tempo: " .. 60 / avgBeatDuration .. " bpm")

	imgui.separator()

	local p
	if dtp.next then
		p = dtp.next.prev
	elseif dtp.prev then
		p = dtp.prev.prev
	end
	---@cast p ncdk2.IntervalPoint

	if p and p.absoluteTime == dtp.absoluteTime then
		local vp = editorModel.visual:getPoint(p)
		vp.temp_comment = imgui.input("vp comment", vp.temp_comment or vp.comment, "comment")
		if imgui.button("save comment", "save") then
			if vp.temp_comment == "" then
				vp.temp_comment = nil
			end
			vp.comment = vp.temp_comment
		end
		if imgui.button("reset comment", "reset") then
			vp.comment = nil
			vp.temp_comment = nil
		end
	end


	do return end

	just.row(true)
	velocity = imgui.input("velocity input", velocity, "velocity")
	if imgui.button("add velocity button", "add") then
		layer:getVelocityData(dtp, tonumber(velocity))
	end

	just.row(true)
	expand[1] = imgui.input("expand n input", expand[1])
	imgui.unindent()
	imgui.label("/ label", "/")
	expand[2] = imgui.input("expand d input", expand[2], "expand")
	if imgui.button("add expand button", "add") then
		layer:getExpandData(dtp, Fraction(tonumber(expand[1]), tonumber(expand[2])))
	end

	just.row()

	if dtp._velocityData then
		imgui.label("velocity label", "Velocity: " .. dtp._velocityData.currentSpeed .. " x")
		just.sameline()
		if imgui.button("remove velocity button", "remove") then
			layer:removeVelocityData(dtp)
		end
	end
	if dtp._expandData then
		imgui.label("expand label", "Expand: " .. dtp._expandData.duration .. " beats")
		just.sameline()
		if imgui.button("remove expand button", "remove") then
			layer:removeExpandData(dtp)
		end
	end
end

local qwerty = "qwerty"

local batch_comment = ""

---@param self table
function tabs.notes(self)
	local editorModel = self.game.editorModel
	local editor = self.game.configModel.configs.settings.editor

	local logSpeed = imgui.slider1("editor speed", editorModel:getLogSpeed(), "%d", -30, 50, 1, "speed")
	if logSpeed ~= editorModel:getLogSpeed() then
		editorModel:setLogSpeed(logSpeed)
	end
	editor.snap = imgui.slider1("snap select", editor.snap, "%d", 1, editorModel.max_snap, 1, "snap")
	editor.lockSnap = imgui.checkbox("lock snap", editor.lockSnap, "lock snap")
	editor.tool = imgui.combo("tool select", editor.tool, editorModel.tools, nil, "tool")
	imgui.text("Use qwer to select tool")

	for i = 1, #editorModel.tools do
		if just.keypressed(qwerty:sub(i, i)) then
			editor.tool = editorModel.tools[i]
		end
	end

	if imgui.button("changeType", "change type") then
		editorModel.noteManager:changeType()
	end

	local _, note = next(editorModel.visualEngine.selectedNotes)
	if note and imgui.button("scroll to note", "scroll to") then
		editorModel.scroller:scrollPoint(note.startNote.visualPoint.point)
	end

	imgui.separator()

	batch_comment = imgui.input("vps comment", batch_comment, "comment")
	if imgui.button("save comment notes", "save") then
		if batch_comment == "" then
			batch_comment = nil
		end
		for _, note in pairs(editorModel.visualEngine.selectedNotes) do
			note.startNote.visualPoint.comment = batch_comment
		end
	end
	if imgui.button("reset comment notes", "reset") then
		for _, note in pairs(editorModel.visualEngine.selectedNotes) do
			note.startNote.visualPoint.comment = nil
		end
	end

	local _, sel_note = next(editorModel.visualEngine.selectedNotes)
	if sel_note then
		local sounds = sel_note.startNote.sounds
		if sounds and sounds[1] then
			imgui.text(sounds[1][1])
		end
	end
end

---@param self table
function tabs.bms(self)
	local editorModel = self.game.editorModel
	local editor = self.game.configModel.configs.settings.editor

	local bms_tools = editorModel.bmsToolsContext
	imgui.text("BMS creation tools")

	bms_tools.offset = tonumber(imgui.input("offset", bms_tools.offset, "offset")) or 0
	bms_tools.tempo = tonumber(imgui.input("tempo", bms_tools.tempo, "tempo")) or 120

	if imgui.button("bms apply tempo", "apply") then
		bms_tools:resetOffsetTempo(editorModel.layer)
	end

	imgui.text("offset")
	if imgui.button("bms add offset", "+1ms") then
		bms_tools.offset = bms_tools.offset + 0.001
		bms_tools:resetOffsetTempo(editorModel.layer)
	end
	just.sameline()
	if imgui.button("bms sub offset", "-1ms") then
		bms_tools.offset = bms_tools.offset - 0.001
		bms_tools:resetOffsetTempo(editorModel.layer)
	end

	if imgui.button("slice keysounds", "slice keysounds") then
		self.game.editorController:sliceKeysounds()
	end

	bms_tools.beat_offset = tonumber(imgui.input("beat_offset", bms_tools.beat_offset, "beat offset")) or 0
	if imgui.button("create bms template 5K", "create bms template 5K") then
		self.game.editorController:exportBmsTemplate(5)
	end
	if imgui.button("create bms template 7K", "create bms template 7K") then
		self.game.editorController:exportBmsTemplate(7)
	end
	if imgui.button("create bms template 10K", "create bms template 10K") then
		self.game.editorController:exportBmsTemplate(10)
	end
	if imgui.button("export ubmsc", "export ubmsc") then
		self.game.editorController:exportUBmsC()
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

	editorModel.session.state = imgui.tabs("editor overlay tabs", editorModel.session.state, editorModel.states)
	love.graphics.setColor(1, 1, 1, 1)
	imgui.setSize(400, h, 200, lineHeight)
	tabs[editorModel.session.state](self)

	if not editorModel.resourcesLoaded then
		w, h = Layout:move("base")
		love.graphics.setColor(1, 1, 1, 0.5)
		love.graphics.setFont(spherefonts.get("Noto Sans", 160))
		gfx_util.printFrame("loading", 0, 0, w, h, "center", "center")
	end
end
