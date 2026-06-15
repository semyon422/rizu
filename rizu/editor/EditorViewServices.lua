local class = require("class")
local EditorActionService = require("rizu.editor.EditorActionService")
local EditorAudioOverlayService = require("rizu.editor.EditorAudioOverlayService")
local EditorAudioSettingsOverlayService = require("rizu.editor.EditorAudioSettingsOverlayService")
local EditorBmsOverlayService = require("rizu.editor.EditorBmsOverlayService")
local EditorChartSliderService = require("rizu.editor.EditorChartSliderService")
local EditorFooterService = require("rizu.editor.EditorFooterService")
local EditorInfoOverlayService = require("rizu.editor.EditorInfoOverlayService")
local EditorNotesOverlayService = require("rizu.editor.EditorNotesOverlayService")
local EditorOnsetsService = require("rizu.editor.EditorOnsetsService")
local EditorOverlayActionService = require("rizu.editor.EditorOverlayActionService")
local EditorOverlayContextFactory = require("rizu.editor.EditorOverlayContextFactory")
local EditorOverlayShellService = require("rizu.editor.EditorOverlayShellService")
local EditorScrollInputService = require("rizu.editor.EditorScrollInputService")
local EditorTimingOverlayService = require("rizu.editor.EditorTimingOverlayService")
local EditorWaveformService = require("rizu.editor.EditorWaveformService")

---@class rizu.editor.EditorViewServicesDeps
---@field actionService rizu.editor.EditorActionService?
---@field audioOverlayService rizu.editor.EditorAudioOverlayService?
---@field audioSettingsOverlayService rizu.editor.EditorAudioSettingsOverlayService?
---@field bmsOverlayService rizu.editor.EditorBmsOverlayService?
---@field chartSliderService rizu.editor.EditorChartSliderService?
---@field footerService rizu.editor.EditorFooterService?
---@field infoOverlayService rizu.editor.EditorInfoOverlayService?
---@field notesOverlayService rizu.editor.EditorNotesOverlayService?
---@field onsetsService rizu.editor.EditorOnsetsService?
---@field overlayActionService rizu.editor.EditorOverlayActionService?
---@field overlayContextFactory rizu.editor.EditorOverlayContextFactory?
---@field overlayShellService rizu.editor.EditorOverlayShellService?
---@field scrollInputService rizu.editor.EditorScrollInputService?
---@field timingOverlayService rizu.editor.EditorTimingOverlayService?
---@field waveformService rizu.editor.EditorWaveformService?

---@class rizu.editor.EditorViewServices
---@operator call: rizu.editor.EditorViewServices
---@field actionService rizu.editor.EditorActionService
---@field audioOverlayService rizu.editor.EditorAudioOverlayService
---@field audioSettingsOverlayService rizu.editor.EditorAudioSettingsOverlayService
---@field bmsOverlayService rizu.editor.EditorBmsOverlayService
---@field chartSliderService rizu.editor.EditorChartSliderService
---@field footerService rizu.editor.EditorFooterService
---@field infoOverlayService rizu.editor.EditorInfoOverlayService
---@field notesOverlayService rizu.editor.EditorNotesOverlayService
---@field onsetsService rizu.editor.EditorOnsetsService
---@field overlayActionService rizu.editor.EditorOverlayActionService
---@field overlayContextFactory rizu.editor.EditorOverlayContextFactory
---@field overlayShellService rizu.editor.EditorOverlayShellService
---@field scrollInputService rizu.editor.EditorScrollInputService
---@field timingOverlayService rizu.editor.EditorTimingOverlayService
---@field waveformService rizu.editor.EditorWaveformService
local EditorViewServices = class()

---@param deps rizu.editor.EditorViewServicesDeps?
function EditorViewServices:new(deps)
	deps = deps or {}
	self.actionService = deps.actionService or EditorActionService()
	self.audioOverlayService = deps.audioOverlayService or EditorAudioOverlayService()
	self.audioSettingsOverlayService = deps.audioSettingsOverlayService or EditorAudioSettingsOverlayService()
	self.bmsOverlayService = deps.bmsOverlayService or EditorBmsOverlayService()
	self.chartSliderService = deps.chartSliderService or EditorChartSliderService()
	self.footerService = deps.footerService or EditorFooterService()
	self.infoOverlayService = deps.infoOverlayService or EditorInfoOverlayService()
	self.notesOverlayService = deps.notesOverlayService or EditorNotesOverlayService()
	self.onsetsService = deps.onsetsService or EditorOnsetsService()
	self.overlayActionService = deps.overlayActionService or EditorOverlayActionService()
	self.overlayContextFactory = deps.overlayContextFactory or EditorOverlayContextFactory()
	self.overlayShellService = deps.overlayShellService or EditorOverlayShellService()
	self.scrollInputService = deps.scrollInputService or EditorScrollInputService()
	self.timingOverlayService = deps.timingOverlayService or EditorTimingOverlayService()
	self.waveformService = deps.waveformService or EditorWaveformService()
end

return EditorViewServices
