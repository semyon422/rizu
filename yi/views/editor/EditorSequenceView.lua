local View = require("gui.View")
local EditorRhythmView = require("yi.views.editor.EditorRhythmView")
local RhythmView = require("sphere.views.RhythmView")

---@param views table
---@param out table?
---@return table
local function flattenViews(views, out)
	out = out or {}
	for _, view in ipairs(views) do
		if #view == 0 or type(view[1]) ~= "table" then
			table.insert(out, view)
		else
			flattenViews(view, out)
		end
	end
	return out
end

---@param view table
---@return boolean
local function isGameplayNotesView(view)
	return RhythmView * view and view.subscreen == "gameplay" and view.isNotesView == true
end

---@param view table
---@return yi.views.editor.EditorRhythmView
local function createEditorRhythmView(view)
	return EditorRhythmView({
		transform = view.transform,
		subscreen = "editor",
	})
end

---@param views table[]
---@return table[]
local function withEditorRhythmViews(views)
	---@type table[]
	local out = {}
	for _, view in ipairs(views) do
		table.insert(out, view)
		if isGameplayNotesView(view) then
			table.insert(out, createEditorRhythmView(view))
		end
	end
	return out
end

---@class yi.views.editor.EditorSequenceView: gui.View
---@operator call: yi.views.editor.EditorSequenceView
---@field screen table
---@field sequenceViews table[]
---@field viewById {[string]: table}
---@field iterating boolean?
---@field abortIterating boolean?
---@field missingEditorNotesView boolean
local EditorSequenceView = View + {}

---@param screen table
function EditorSequenceView:new(screen)
	View.new(self)
	self.screen = screen
	self.sequenceViews = {}
	self.viewById = {}
	self.missingEditorNotesView = false
	screen.editor_sequence_view = self
	self:setSize(love.graphics.getDimensions())
end

function EditorSequenceView:load()
	self:setSize(love.graphics.getDimensions())
	self:setPlayfield(self.screen.game.noteSkinModel.noteSkin.playField)
	self:loadSequenceViews()
end

---@param playfield table
function EditorSequenceView:setPlayfield(playfield)
	self.sequenceViews = withEditorRhythmViews(flattenViews(playfield))
	self.missingEditorNotesView = true
	self.viewById = {}
	for _, view in ipairs(self.sequenceViews) do
		if EditorRhythmView * view then
			self.missingEditorNotesView = false
		end
		view.sequenceView = self
		view.game = self.screen.game
		view.screenView = self
		if view.id then
			self.viewById[view.id] = view
		end
	end
end

function EditorSequenceView:loadSequenceViews()
	if self.iterating then
		self.abortIterating = true
	end
	for _, view in ipairs(self.sequenceViews) do
		if view.load then
			view:load()
		end
	end
end

function EditorSequenceView:unload()
	if self.iterating then
		self.abortIterating = true
	end
	for _, view in ipairs(self.sequenceViews) do
		if view.unload then
			view:unload()
		end
	end
end

---@param method string
---@param ... any?
function EditorSequenceView:callMethod(method, ...)
	if self.iterating then
		return
	end
	self.iterating = true
	for _, view in ipairs(self.sequenceViews) do
		if view[method] and not view.hidden and (not view.subscreen or view.subscreen == "editor") then
			view[method](view, ...)
		end
		if self.abortIterating then
			break
		end
	end
	self.abortIterating = false
	self.iterating = false
end

---@param dt number
function EditorSequenceView:update(dt)
	self:callMethod("update", dt)
end

---@param event table
function EditorSequenceView:receive(event)
	self:callMethod("receive", event)
end

function EditorSequenceView:draw()
	self:callMethod("draw")
end

return EditorSequenceView
