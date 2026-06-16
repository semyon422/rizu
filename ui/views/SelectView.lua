local just = require("just")
local ScreenView = require("ui.views.ScreenView")

local Layout = require("ui.views.SelectView.Layout")
local SelectViewConfig = require("ui.views.SelectView.SelectViewConfig")
local NotechartsSubscreen = require("ui.views.SelectView.NotechartsSubscreen")
local CollectionsSubscreen = require("ui.views.SelectView.CollectionsSubscreen")
local Background = require("ui.views.SelectView.Background")
local ChartPreviewView = require("sphere.views.SelectView.ChartPreviewView")

local ChartmetaKey = require("sea.chart.ChartmetaKey")

---@class ui.SelectView: ui.ScreenView
---@operator call: ui.SelectView
local SelectView = ScreenView + {}

SelectView.subscreen = "notecharts"
SelectView.searchMode = "filter"

function SelectView:load()
	self.game.selectionCoordinator:activatePreview()
	self.game.chartSelector:setChanged()
	self.chartPreviewView = ChartPreviewView(self.game, self.ui)
	self.chartPreviewView:load()
end

function SelectView:beginUnload()
end

function SelectView:unload()
	if self.chartPreviewView then
		self.chartPreviewView:unload()
	end
end

---@param dt number
function SelectView:update(dt)
	if self.chartPreviewView then
		self.chartPreviewView:update(dt)
	end
end

---@param event table
function SelectView:receive(event)
	if self.chartPreviewView then
		self.chartPreviewView:receive(event)
	end
end

function SelectView:draw()
	just.container("select container", true)

	Layout:draw()
	Background(self)
	if self.chartPreviewView then
		self.chartPreviewView:draw()
	end
	SelectViewConfig(self)

	local kp = just.keypressed
	if kp("f1") then self.gameView:setModal(require("ui.views.ModifierView.ModifierView"))
	elseif kp("f2") then self.game.chartSelector:scrollRandom()
	elseif kp("lctrl") then self:changeSearchMode()
	end
	if self.subscreen == "notecharts" then
		if kp("return") then self:play()
		elseif kp("tab") then self:switchToCollections()
		end
		NotechartsSubscreen(self)
	elseif self.subscreen == "collections" then
		if kp("tab") then self:switchToNoteCharts()
		end
		CollectionsSubscreen(self)
	end

	just.container()
end

function SelectView:play()
	local chartSelector = self.game.chartSelector
	if not chartSelector:notechartExists() then
		return
	end

	local multiplayerModel = self.game.multiplayerModel
	if multiplayerModel.client:isInRoom() and not multiplayerModel.client.is_playing then
		local chartmeta_key = ChartmetaKey()
		chartmeta_key.hash = chartSelector.chartview.hash
		chartmeta_key.index = chartSelector.chartview.index

		multiplayerModel.client:updateChartmetaKey(chartmeta_key)
		self:changeScreen("multiplayerView")
		return
	end

	self:changeScreen("gameplayView")
end

function SelectView:result()
	if self.game.chartSelector:notechartExists() and self.game.scoreSelector.chartplay then
		self:changeScreen("resultView")
	end
end

function SelectView:edit()
	if not self.game.chartSelector:notechartExists() then
		return
	end
end

function SelectView:switchToNoteCharts()
	self.subscreen = "notecharts"
	self.searchMode = "filter"
	self.game.chartSelector:noDebounceRefresh()
	just.focus()
end

function SelectView:switchToCollections()
	self.subscreen = "collections"
	just.focus()
end

function SelectView:changeSearchMode()
	if self.searchMode == "filter" then
		self.searchMode = "lamp"
	else
		self.searchMode = "filter"
	end
end

return SelectView
