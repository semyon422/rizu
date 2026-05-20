
local LogicEngine = require("sphere.models.RhythmModel.LogicEngine")
local GraphicEngine = require("sphere.models.RhythmModel.GraphicEngine")
local table_util = require("table_util")

local Chart = require("chart.model.Chart")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Visual = require("chart.model.visual.Visual")
local Note = require("chart.format.notechart.Note")

local visualTimeInfo = {
	rate = 1,
	time = 0,
}

local logicEngine = LogicEngine()
local graphicEngine = GraphicEngine(visualTimeInfo, logicEngine)

logicEngine.eventTime = 0
logicEngine.timeRate = 1
logicEngine.inputOffset = 0

graphicEngine.range = {-2, 2}

logicEngine.timings = {
	ShortNote = {
		hit = {-0.1, 0.1},
		miss = {-0.2, 0.2}
	},
	LongNoteStart = {
		hit = {-0.1, 0.1},
		miss = {-0.2, 0.2},
	},
	LongNoteEnd = {
		hit = {-0.1, 0.1},
		miss = {-0.2, 0.2},
	}
}

logicEngine.check1024 = false

local auto_mt = {}

---@param n number
---@return table
local function auto(n)
	return setmetatable({n}, auto_mt)
end

---@param notes table
---@param events table
---@param states table
---@param graphicStates table?
local function test(notes, events, states, graphicStates)
	logicEngine.eventTime = 0  -- reset time on each test

	local chart = Chart()

	local layer = AbsoluteLayer()
	chart.layers.main = layer

	local visual = Visual()
	layer.visuals.main = visual

	chart.inputMode.key = 1

	for _, time in ipairs(notes) do
		local isAuto = type(time) == "table" and getmetatable(time) == auto_mt
		if type(time) == "number" or isAuto then
			if isAuto then
				time = time[1]
			end
			local p = layer:getPoint(time)
			local vp = visual:newPoint(p)

			local note = Note(vp, 1)

			note.type = "tap"
			if isAuto then
				note.type = "shade"
			end

			chart.notes:insert(note)
		elseif type(time) == "table" then
			local p = layer:getPoint(time[1])
			local vp = visual:newPoint(p)

			local startNote = Note(vp, 1)
			startNote.type = "hold"
			startNote.weight = 1
			chart.notes:insert(startNote)

			p = layer:getPoint(time[2])
			vp = visual:newPoint(p)

			local endNote = Note(vp, 1)
			endNote.type = "hold"
			endNote.weight = -1
			chart.notes:insert(endNote)
		end
	end

	chart:compute()

	logicEngine.chart = chart
	graphicEngine.chart = chart

	local newStates = {}
	logicEngine.scoreEngine = {
		receive = function(self, event)
			local eventCopy = {
				currentTime = event.currentTime,
				newState = event.newState,
				oldState = event.oldState,
				noteIndex = event.noteIndex,
			}
			-- print(require("inspect")(eventCopy))
			table.insert(newStates, eventCopy)
		end,
	}

	graphicEngine.visualTimeRate = 1

	logicEngine:load()
	graphicEngine:load()

	local newGraphicStates = {}

	local function press(time)
		logicEngine:receive({
			1,
			name = "keypressed",
			virtual = true,
			time = time
		})
	end
	local function release(time)
		logicEngine:receive({
			1,
			name = "keyreleased",
			virtual = true,
			time = time
		})
	end
	local function update()
		logicEngine:update()
	end
	local function updateGraphics(time)
		visualTimeInfo.time = time
		graphicEngine:update()
		local state = {}
		table.insert(newGraphicStates, state)
		for _, note in ipairs(graphicEngine.renderer.columnRenderers[1].notes) do
			if note.endTimeState then
				table.insert(state, {
					-note.startTimeState.scaledFakeVisualDeltaTime + time,
					-note.endTimeState.scaledFakeVisualDeltaTime + time,
				})
			else
				table.insert(state, -note.startTimeState.scaledVisualDeltaTime + time)
			end
		end
	end

	-- print("TEST")

	-- for t = events[1][1], events[#events][1], 0.01 do
	-- 	table.insert(events, {t, "tu"})
	-- end
	-- table.sort(events, function(a, b) return a[1] < b[1] end)

	-- print(require("inspect")(events))

	for _, event in ipairs(events) do
		local time = event[1]
		for char in event[2]:gmatch(".") do
			if char == "p" then
				press(time)
			elseif char == "r" then
				release(time)
			elseif char == "u" then
				update()
			elseif char == "g" then
				updateGraphics(time)
			elseif char == "t" then
				logicEngine.eventTime = time
			end
		end
	end

	-- print(require("inspect")(states))
	-- print(require("inspect")(newStates))

	if not states then return end
	assert(#states == #newStates)
	for i, event in ipairs(newStates) do
		assert(event.currentTime == states[i][1])
		assert(event.oldState == states[i][2])
		assert(event.newState == states[i][3])
		if states[i][4] then
			assert(event.noteIndex == states[i][4])
		end
	end

	if not graphicStates then
		return
	end

	-- print(require("inspect")(graphicStates))
	-- print(require("inspect")(newGraphicStates))

	assert(table_util.deepequal(graphicStates, newGraphicStates))
end

--[[
	Specs:

	press, release or update can change many states on one call
	press and release can affect the time of only one state change
	update should not affect the time of any state change
]]

-- 1 short note tests

---@param offset number
---@param rate number
local function test1sn(offset, rate)
test(
	{0},
	{{-1 * rate + offset, "p"}},
	{{-1 * rate + offset, "clear", "clear"}}
)

test(
	{0},
	{{-0.15 * rate + offset, "p"}},
	{{-0.15 * rate + offset, "clear", "missed"}}
)

test(
	{0},
	{{0 * rate + offset, "p"}},
	{{0 * rate + offset, "clear", "passed"}}
)

test(
	{0},
	{{0.15 * rate + offset, "p"}},
	{{0.15 * rate + offset, "clear", "missed"}}
)

test(
	{0},
	{{0.25 * rate + offset, "p"}},
	{{0.2 * rate + offset, "clear", "missed"}}
)

test(
	{0},
	{{1 * rate + offset, "tu"}},
	{{0.2 * rate + offset, "clear", "missed"}}
)
end
test1sn(0, 1)

-- exact boundaries, not used in gameplay because of 0.1 + 0.2 ~= 0.3

local function test1sn_bounds()
test(
	{0},
	{{-0.2, "p"}},
	{{-0.2, "clear", "missed"}}
)
test(
	{0},
	{{-0.1, "p"}},
	{{-0.1, "clear", "passed"}}
)
test(
	{0},
	{{0.1, "p"}},
	{{0.1, "clear", "passed"}}
)
test(
	{0},
	{{0.2, "p"}},
	{{0.2, "clear", "missed"}}
)
end
test1sn_bounds()

-- 2 short notes tests

test(
	{0, 0.3},
	{{0.15, "pp"}},
	{
		{0.15, "clear", "missed", 1},
		{0.15, "clear", "missed", 2},
	}
)

test(
	{0, 0.15},
	{{0.075, "pp"}},
	{
		{0.075, "clear", "passed", 1},
		{0.075, "clear", "passed", 2},
	}
)

test(
	{0, 0.25},
	{{0.25, "p"}},
	{
		{0.2, "clear", "missed", 1},
		{0.25, "clear", "passed", 2},
	}
)

test(
	{0, 0.15},
	{{0.15, "p"}},
	{
		{0.15, "clear", "missed", 1},
	}
)

test(
	{0, 0.15},
	{{0.15, "pp"}},
	{
		{0.15, "clear", "missed", 1},
		{0.15, "clear", "passed", 2},
	}
)

-- many short notes

local function testmsn()
	test(
		{0, 1, 2, 3},
		{{3, "p"}},
		{
			{0.2, "clear", "missed", 1},
			{1.2, "clear", "missed", 2},
			{2.2, "clear", "missed", 3},
			{3, "clear", "passed", 4},
		}
	)

	test(
		{0, auto(0.025), 0.05},
		{{0, "pp"}},
		{
			{0, "clear", "passed", 1},
			{0, "clear", "passed", 3},
		}
	)

	test(
		{0, auto(0.01), auto(0.02), 0.03},
		{{0, "pp"}},
		{
			{0, "clear", "passed", 1},
			{0, "clear", "passed", 4},
		}
	)
end
testmsn()

-- 1 long note tests

local function test1ln()
test(
	{{0, 1}},
	{{2, "tu"}},
	{
		{0.2, "clear", "startMissed"},
		{1.2, "startMissed", "endMissed"},
	}
)

test(
	{{0, 1}},
	{{0, "p"}, {1, "r"}},
	{
		{0, "clear", "startPassedPressed"},
		{1, "startPassedPressed", "endPassed"},
	}
)

test(
	{{0, 1}},
	{{-1, "p"}, {1, "r"}, {2, "tu"}},
	{
		{-1, "clear", "clear"},
		{0.2, "clear", "startMissed"},
		{1.2, "startMissed", "endMissed"},
	}
)

test(
	{{0, 1}},
	{{-0.15, "p"}},
	{{-0.15, "clear", "startMissedPressed"}}
)

test(
	{{0, 1}},
	{{0.15, "p"}},
	{{0.15, "clear", "startMissedPressed"}}
)

test(
	{{0, 1}},
	{{0.5, "p"}},
	{
		{0.2, "clear", "startMissed"},
		{0.5, "startMissed", "startMissedPressed"},
	}
)

test(
	{{0, 1}},
	{{0, "p"}, {0.85, "r"}},
	{
		{0, "clear", "startPassedPressed"},
		{0.85, "startPassedPressed", "endMissed"},
	}
)

test(
	{{0, 1}},
	{{0, "p"}, {1.15, "r"}},
	{
		{0, "clear", "startPassedPressed"},
		{1.15, "startPassedPressed", "endMissed"},
	}
)

test(
	{{0, 1}},
	{{0, "p"}, {1.25, "r"}},
	{
		{0, "clear", "startPassedPressed"},
		{1.2, "startPassedPressed", "endMissed"},
	}
)

test(
	{{0, 1}},
	{{0, "p"}, {0.85, "r"}},
	{
		{0, "clear", "startPassedPressed"},
		{0.85, "startPassedPressed", "endMissed"},
	}
)
end
test1ln()

-- long note + short note tests

local function test1lnsn()
test(
	{{0, 1}, 1},
	{{0, "p"}, {1, "rp"}},
	{
		{0, "clear", "startPassedPressed"},
		{1, "startPassedPressed", "endPassed"},
		{1, "clear", "passed"},
	}
)

test(
	{{0, 1}, 1},
	{{1, "tu"}},
	{
		{0.2, "clear", "startMissed"},
		{0.8, "startMissed", "endMissed"},
	}
)

test(
	{{0, 1}, 1},
	{{2, "tu"}},
	{
		{0.2, "clear", "startMissed"},
		{0.8, "startMissed", "endMissed"},
		{1.2, "clear", "missed"},
	}
)

test(
	{{0, 1}, 1},
	{{1, "p"}},
	{
		{0.2, "clear", "startMissed"},
		{0.8, "startMissed", "endMissed"},
		{1, "clear", "passed"},
	}
)

test(
	{{0, 1}, 1},
	{{-1, "p"}, {1, "r"}},
	{
		{-1, "clear", "clear"},
		{0.2, "clear", "startMissed"},
		{0.8, "startMissed", "endMissed"},
	}
)

test(
	{{0, 1}, 1},
	{{1, "tu"}, {10, "tu"}},
	{
		{0.2, "clear", "startMissed"},
		{0.8, "startMissed", "endMissed"},
		{1.2, "clear", "missed"},
	}
)

test(
	{{0, 1}, 1},
	{{10, "tu"}},
	{
		{0.2, "clear", "startMissed"},
		{0.8, "startMissed", "endMissed"},
		{1.2, "clear", "missed"},
	}
)

test(
	{{0, 1}, {2, 3}},
	{{4, "tu"}},
	{
		{0.2, "clear", "startMissed"},
		{1.2, "startMissed", "endMissed"},
		{2.2, "clear", "startMissed"},
		{3.2, "startMissed", "endMissed"},
	}
)
end
test1lnsn()

-- many notes

local function test1mln()
test(
	{{0, 0.001}, auto(0.025), 0.05},
	{{0, "prp"}},
	{
		{0, "clear", "startPassedPressed", 1},
		{0, "startPassedPressed", "endPassed", 1},
		{0, "clear", "passed", 3},
	}
)
test(
	{{0, 0.001}, auto(0.01), auto(0.02), 0.05},
	{{0, "prp"}},
	{
		{0, "clear", "startPassedPressed", 1},
		{0, "startPassedPressed", "endPassed", 1},
		{0, "clear", "passed", 4},
	}
)
end
test1mln()

-- nearest logic

logicEngine.nearest = true

test1sn(0, 1)
test1sn_bounds()
testmsn()

-- 2 short notes tests

test(
	{0, 0.3},
	{{0.14, "pp"}},
	{
		{0.14, "clear", "missed", 1},
		{0.14, "clear", "missed", 2},
	}
)

test(
	{0, 0.3},
	{{0.16, "pp"}},
	{
		{0.16, "clear", "missed", 2},
		{0.16, "clear", "missed", 1},
	}
)

test(
	{0, 0.3},
	{{0.15, "pp"}},
	{
		{0.15, "clear", "missed", 1},
		{0.15, "clear", "missed", 2},
	}
)

test(
	{0, 0.15},
	{{0.075, "pp"}},
	{
		{0.075, "clear", "passed", 1},
		{0.075, "clear", "passed", 2},
	}
)

test(
	{0, 0.15},
	{{0.07, "pp"}},
	{
		{0.07, "clear", "passed", 1},
		{0.07, "clear", "passed", 2},
	}
)

test(
	{0, 0.15},
	{{0.08, "pp"}},
	{
		{0.08, "clear", "passed", 2},
		{0.08, "clear", "passed", 1},
	}
)

test(
	{0, 0.25},
	{{0.25, "p"}},
	{
		{0.2, "clear", "missed", 1},
		{0.25, "clear", "passed", 2},
	}
)

test(
	{0, 0.15},
	{{0.15, "p"}},
	{
		{0.15, "clear", "passed", 2},
	}
)

test(
	{0, 0.15},
	{{0.15, "pp"}},
	{
		{0.15, "clear", "passed", 2},
		{0.15, "clear", "missed", 1},
	}
)

test1ln()
test1lnsn()
test1mln()

test(
	{{0, 0.1}, 0.1},
	{{0.04, "pr"}, {0.1, "p"}},
	{
		{0.04, "clear", "startPassedPressed"},
		{0.04, "startPassedPressed", "endPassed"},
		{0.1, "clear", "passed"},
	}
)

test(
	{{0, 0.1}, 0.1},
	{{0.06, "p"}},
	{
		{0.06, "clear", "passed"},
	}
)

test(
	{{0, 0.1}, 0.1},
	{{0.06, "ppr"}},
	{
		{0.06, "clear", "passed"},
		{0.06, "clear", "startPassedPressed"},
		{0.06, "startPassedPressed", "endPassed"},
	}
)


assert(0.03125 - 0.015625 == 0.015625)
test(
	{0, 0.015625, 0.03125}, -- exact in the middle
	{{0.015625, "ppp"}},
	{
		{0.015625, "clear", "passed", 2},
		{0.015625, "clear", "passed", 1},
		{0.015625, "clear", "passed", 3},
	}
)

test(
	{0, 0.01, 0.02},
	{{0.011, "ppp"}},
	{
		{0.011, "clear", "passed", 2},
		{0.011, "clear", "passed", 3},
		{0.011, "clear", "passed", 1},
	}
)

test(
	{0, 0.01, 0.02},
	{{0.001, "ppp"}},
	{
		{0.001, "clear", "passed", 1},
		{0.001, "clear", "passed", 2},
		{0.001, "clear", "passed", 3},
	}
)

test(
	{0, 0.01, 0.02},
	{{0.019, "ppp"}},
	{
		{0.019, "clear", "passed", 3},
		{0.019, "clear", "passed", 2},
		{0.019, "clear", "passed", 1},
	}
)

-- TODO: test multiple columns
-- 3 notes wrong order - no bug in a single column
test(
	{0, 0.015625, 0.3},
	{{0, "p"}, {0.3, "p"}},
	{
		{0, "clear", "passed", 1},
		{0.215625, "clear", "missed", 2},
		{0.3, "clear", "passed", 3},
	}
)

-- 1 short note input offset tests

local function test1sn_inputoffset()
logicEngine.inputOffset = 1
test1sn(1, 1)
logicEngine.inputOffset = 0
end
test1sn_inputoffset()

-- 1 short note time rate tests

local function test1sn_timerate()
logicEngine.timeRate = 2
test1sn(0, 2)
logicEngine.timeRate = 1
end
test1sn_timerate()

-- 1 short note time rate and input offset tests

local function test1sn_timerate_offset()
logicEngine.inputOffset = 1
logicEngine.timeRate = 2
test1sn(1, 2)
logicEngine.inputOffset = 0
logicEngine.timeRate = 1
end
test1sn_timerate_offset()

-- graphics test

test(
	{0},
	{{0, "pg"}},
	{{0, "clear", "passed"}},
	{{0}}
)

test(
	{{0, 1}},
	{{0, "pg"}, {1, "rg"}},
	{
		{0, "clear", "startPassedPressed"},
		{1, "startPassedPressed", "endPassed"},
	},
	{
		-- start/end scaledFakeVisualDeltaTime when g called
		{{0, 1}},  -- array of notes when g called
		{{1, 1}},
	}
)

test(
	{{0, 1}},
	{{-0.05, "pg"}, {0.5, "g"}, {1.05, "g"}, {1.06, "rg"}},
	{
		{-0.05, "clear", "startPassedPressed"},
		{1.06, "startPassedPressed", "endPassed"},
	},
	{
		{{0, 1}},
		{{0.5, 1}},
		{{1, 1}},
		{{1, 1}},
	}
)

-- grg - fix this!
test(
	{{0, 1}},
	{{0.05, "g"}, {0.06, "pg"}, {0.5, "grg"}, {0.6, "pg"}, {1, "rg"}},
	{
		{0.06, "clear", "startPassedPressed"},
		{0.5, "startPassedPressed", "startMissed"},
		{0.6, "startMissed", "startMissedPressed"},
		{1, "startMissedPressed", "endMissedPassed"},
	},
	{
		{{0, 1}},
		{{0.06, 1}},
		{{0.5, 1}},
		{{0.5, 1}},
		{{0.5, 1}},
		{{0.5, 1}},
	}
)

graphicEngine.visualOffset = 1

test(
	{0},
	{{0, "pg"}},
	{{0, "clear", "passed"}},
	{{1}}
)

test(
	{{0, 1}},
	{{0, "pg"}, {1, "g"}, {1, "rg"}},
	{
		{0, "clear", "startPassedPressed"},
		{1, "startPassedPressed", "endPassed"},
	},
	{
		{{1, 2}},
		{{1, 2}},
		{{2, 2}},
	}
)

test(
	{{0, 2}},
	{{0, "pg"}, {0.5, "g"}, {1.5, "g"}, {1.5, "rg"}},
	{
		{0, "clear", "startPassedPressed"},
		{1.5, "startPassedPressed", "startMissed"},
	},
	{
		{{1, 3}},
		{{1, 3}},
		{{1.5, 3}},
		{{1.5, 3}},
	}
)

graphicEngine.visualOffset = -1

test(
	{{0, 1}},
	-- use 0.0625 because of floating point error
	{{-2, "g"}, {-0.0625, "g"}, {-0.0625, "pg"}, {0.5, "g"}, {1, "rg"}},
	{
		{-0.0625, "clear", "startPassedPressed"},
		{1, "startPassedPressed", "endPassed"},
	},
	{
		{{-1, 0}},
		{{-1, 0}},
		{{-0.0625, 0}},
		{{0, 0}},
		{{0, 0}},
	}
)

graphicEngine.visualOffset = 1

--[[
	TODO:
	line 788
	add tests for LN + SV + all offsets
]]
