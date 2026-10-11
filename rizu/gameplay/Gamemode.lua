local class = require("class")

---Everything gameplay needs to know about one gamemode. Modes share audio, time,
---pauses and the replay frame format; the rest is theirs.
---Descriptors are also loaded by the chart worker thread: keep top-level requires light.
---@class rizu.gameplay.Gamemode
---@field name sea.Gamemode
---@field saves_scores boolean Plays produce a chartplay, a result screen and a server submission.
---@field deferred_input boolean Inputs carry their own timestamps and are resolved before deadlines.
---@field uses_pointer boolean
local Gamemode = class()

Gamemode.saves_scores = false
Gamemode.deferred_input = true
Gamemode.uses_pointer = false

---Turns a decoded chart into a playable one: fills ctx.chartdiff, ctx.state and ctx.diffcalc_context.
---@param ctx sea.ComputeContext
---@param replay_base sea.ReplayBase
---@param config rizu.GameplayChartConfig
function Gamemode.prepare(ctx, replay_base, config) end

---@return rizu.RhythmEngine
function Gamemode.createEngine()
	error("not implemented")
end

---@class rizu.gameplay.GamemodeInput
---@field transform fun(self: rizu.gameplay.GamemodeInput, event: table): rizu.VirtualInputEvent?
---@field move (fun(self: rizu.gameplay.GamemodeInput, x: number, y: number): rizu.VirtualInputEvent)? Pointer modes only.

---Translates raw window events into the virtual inputs the engine and replays use.
---@param input_config table
---@param input_mode string
---@return rizu.gameplay.GamemodeInput
function Gamemode.createInput(input_config, input_mode)
	error("not implemented")
end

---Applies the play settings only this gamemode understands.
---@param engine rizu.RhythmEngine
---@param replay_base sea.ReplayBase
---@param settings rizu.config.Config
function Gamemode.configureEngine(engine, replay_base, settings) end

return Gamemode
