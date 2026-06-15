local class = require("class")
local EditorActionService = require("rizu.editor.view.EditorActionService")
local EditorAudioOverlayService = require("rizu.editor.view.overlays.EditorAudioOverlayService")
local EditorAudioSettingsOverlayService = require("rizu.editor.view.overlays.EditorAudioSettingsOverlayService")
local EditorBmsOverlayService = require("rizu.editor.view.overlays.EditorBmsOverlayService")
local EditorChartSliderService = require("rizu.editor.view.EditorChartSliderService")
local EditorFooterService = require("rizu.editor.view.EditorFooterService")
local EditorInfoOverlayService = require("rizu.editor.view.overlays.EditorInfoOverlayService")
local EditorNotesOverlayService = require("rizu.editor.view.overlays.EditorNotesOverlayService")
local EditorOnsetsService = require("rizu.editor.view.EditorOnsetsService")
local EditorOverlayActionService = require("rizu.editor.view.overlays.EditorOverlayActionService")
local EditorOverlayContextFactory = require("rizu.editor.view.overlays.EditorOverlayContextFactory")
local EditorOverlayShellService = require("rizu.editor.view.overlays.EditorOverlayShellService")
local EditorScrollInputService = require("rizu.editor.view.EditorScrollInputService")
local EditorSnapGridService = require("rizu.editor.view.EditorSnapGridService")
local EditorTimingOverlayService = require("rizu.editor.view.overlays.EditorTimingOverlayService")
local EditorWaveformService = require("rizu.editor.view.EditorWaveformService")

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
---@field snapGridService rizu.editor.EditorSnapGridService?
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
---@field snapGridService rizu.editor.EditorSnapGridService
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
	self.snapGridService = deps.snapGridService or EditorSnapGridService()
	self.timingOverlayService = deps.timingOverlayService or EditorTimingOverlayService()
	self.waveformService = deps.waveformService or EditorWaveformService()
end

return EditorViewServices
