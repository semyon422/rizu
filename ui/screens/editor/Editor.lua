local Screen = require("gui.Screen")
local RhythmView = require("sphere.views.RhythmView")
local EditorRhythmView = require("ui.screens.editor.EditorRhythmView")
local EditorRhythmBox = require("ui.screens.editor.EditorRhythmBox")
local Label = require("ui.views.Label")
local Colors = require("ui.Colors")
local EditorFooterService = require("rizu.editor.view.EditorFooterService")
local UiActions = require("ui.UiActions")
local thread = require("thread")

---@class ui.screens.editor.Editor : gui.Screen
---@operator call: ui.screens.editor.Editor
---@field rhythm_view ui.screens.editor.EditorRhythmView?
---@field rhythm_box ui.screens.editor.EditorRhythmBox
---@field footer_service rizu.editor.EditorFooterService
local Editor = Screen + {}

---@param ui ui.UserInterface
function Editor:new(ui)
	Screen.new(self)
	self.ui = ui
	self.game = ui.game
	self.editor_loaded = false
	self.loading = false
	self.footer_service = EditorFooterService()
	self.rhythm_box = self.root:add(EditorRhythmBox(self.game))

end

---@param inputs gui.Inputs
function Editor:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.song_select)
	elseif self.editor_loaded and inputs:consumeActionJustPressed(UiActions.editor_toggle_playback) then
		self:togglePlayback()
	end
end

function Editor:load()
	local notice = self.root:add(Label({
		font_name = "bold",
		font_size = 24,
		text = "EDITOR WORK IN PROGRESS!!! Please wait for the editor and skins update",
		color = Colors.text,
	}))
	notice:setAlignment(0.5, 0)
	notice:setPivot(0.5, 0)
	notice:setOffset(0, 20)

	local exitHint = self.root:add(Label({
		font_name = "regular",
		font_size = 20,
		text = "Press ESCAPE to exit",
		color = Colors.text_muted,
	}))
	exitHint:setAlignment(0.5, 0)
	exitHint:setPivot(0.5, 0)
	exitHint:setOffset(0, 54)

	Screen.load(self)
end

function Editor:enter()
	if self.loading or self.editor_loaded then
		return
	end

	self.loading = true
	thread.coro(function()
		local ok, err = xpcall(function()
			self.game.editorController:load()
			self:createRhythmView()
		end, debug.traceback)
		self.loading = false
		if not ok then
			self.rhythm_view = nil
			error(err)
		end
		self.editor_loaded = true
	end)()
end

function Editor:togglePlayback()
	local context = self.game.editorModel.context:getViewContext()
	self.footer_service:togglePlayback(context)
end

function Editor:createRhythmView()
	local playfield = self.game.noteSkinModel.noteSkin.playField
	local transform
	for _, view in ipairs(self:flattenViews(playfield)) do
		if RhythmView * view and view.subscreen == "gameplay" and view.isNotesView == true then
			transform = view.transform
			break
		end
	end
	assert(transform, "note skin has no gameplay notes view")

	self.rhythm_view = EditorRhythmView({
		game = self.game,
		transform = transform,
		subscreen = "editor",
	})
	self.rhythm_box:bind(self.rhythm_view)
end

---@param views table
---@param out table[]?
---@return table[]
function Editor:flattenViews(views, out)
	out = out or {}
	for _, view in ipairs(views) do
		if #view == 0 or type(view[1]) ~= "table" then
			out[#out + 1] = view
		else
			self:flattenViews(view, out)
		end
	end
	return out
end

---@return boolean can_exit
function Editor:exit()
	if self.editor_loaded then
		self.rhythm_box:unbind()
		self.rhythm_view = nil
		self.game.editorController:unload()
		self.editor_loaded = false
	end
	self.loading = false
	return Screen.exit(self)
end

---@param dt number
function Editor:update(dt)
	if not self.editor_loaded then
		return
	end
	Screen.update(self, dt)
end

function Editor:draw()
	if self.editor_loaded then
		Screen.draw(self)
	end
end

---@param event {name: string, time: number, [integer]: any}
function Editor:receive(event)
	if not self.editor_loaded then
		return
	end
	self.game.editorController:receive(event)
end

return Editor
