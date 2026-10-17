local class = require("class")
local table_util = require("table_util")

---Everything gameplay needs to know about one gamemode. Modes share audio, time,
---pauses and the replay frame format; the rest is theirs.
---Descriptors are singletons: call their methods on the class itself.
---They are also loaded by the chart worker thread: keep top-level requires light.
---@class rizu.gameplay.Gamemode
---@field name sea.Gamemode
---@field ReplayBase rizu.gameplay.ReplayBase|sea.ReplayBase Class of this gamemode's replay base.
---@field saves_scores boolean Plays produce a chartplay, a result screen and a server submission.
---@field deferred_input boolean Inputs carry their own timestamps and are resolved before deadlines.
---@field uses_pointer boolean
---@field resource_paths string[] Searched for chart resources after the chart directory.
local Gamemode = class()

Gamemode.saves_scores = false
Gamemode.deferred_input = true
Gamemode.uses_pointer = false
Gamemode.resource_paths = {"userdata/hitsounds"}

---Makes this gamemode's replay base out of one of any gamemode, or out of its plain data.
---Only the rate carries over between gamemodes.
---@param source rizu.gameplay.ReplayBase|sea.ReplayBase
---@return rizu.gameplay.ReplayBase|sea.ReplayBase
function Gamemode:createReplayBase(source)
	local base = self.ReplayBase()
	if source.mode == self.name then
		table_util.copy(source, base)
	else
		base.rate = source.rate
	end
	return base
end

---@param source rizu.gameplay.ReplayBase|sea.ReplayBase
---@return rizu.gameplay.ReplayBase|sea.ReplayBase
function Gamemode:getReplayBase(source)
	if self.ReplayBase * source then
		return source
	end
	return self:createReplayBase(source)
end

---Turns a decoded chart into a playable one: fills ctx.chartdiff, ctx.state and ctx.diffcalc_context.
---@param ctx sea.ComputeContext
---@param replay_base rizu.gameplay.ReplayBase|sea.ReplayBase
---@param config rizu.GameplayChartConfig
function Gamemode:prepare(ctx, replay_base, config) end

---@param replay_base (rizu.gameplay.ReplayBase|sea.ReplayBase)?
---@return rizu.RhythmEngine
function Gamemode:createEngine(replay_base)
	error("not implemented")
end

---@class rizu.gameplay.GamemodeInput
---@field transform fun(self: rizu.gameplay.GamemodeInput, event: table): rizu.VirtualInputEvent?
---@field move (fun(self: rizu.gameplay.GamemodeInput, x: number, y: number): rizu.VirtualInputEvent)? Pointer modes only.

---Translates raw window events into the virtual inputs the engine and replays use.
---@param input_config table
---@param input_mode string
---@return rizu.gameplay.GamemodeInput
function Gamemode:createInput(input_config, input_mode)
	error("not implemented")
end

---Applies the play settings only this gamemode understands.
---@param engine rizu.RhythmEngine
---@param replay_base rizu.gameplay.ReplayBase|sea.ReplayBase
---@param settings rizu.config.Config
function Gamemode:configureEngine(engine, replay_base, settings) end

return Gamemode
