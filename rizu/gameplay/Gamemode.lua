local class = require("class")

---Everything gameplay needs to know about one gamemode. Modes share audio, time,
---pauses and the replay frame format; the rest is theirs.
---Descriptors are also loaded by the chart worker thread: keep top-level requires light.
---@class rizu.gameplay.Gamemode
---@field name sea.Gamemode
local Gamemode = class()

---Turns a decoded chart into a playable one: fills ctx.chartdiff, ctx.state and ctx.diffcalc_context.
---@param ctx sea.ComputeContext
---@param replay_base sea.ReplayBase
---@param config rizu.GameplayChartConfig
function Gamemode.prepare(ctx, replay_base, config) end

---@return rizu.RhythmEngine
function Gamemode.createEngine()
	error("not implemented")
end

---Applies the play settings only this gamemode understands.
---@param engine rizu.RhythmEngine
---@param replay_base sea.ReplayBase
---@param settings rizu.config.Config
function Gamemode.configureEngine(engine, replay_base, settings) end

return Gamemode
