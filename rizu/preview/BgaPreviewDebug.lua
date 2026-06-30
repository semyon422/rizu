local BgaPreviewDebug = {}

require("rizu.preview.AsyncVideoProtocol")

---@class rizu.preview.BgaPreviewDebug: rizu.preview.IAsyncVideoLogger
---@field warn fun(...: any)
---@field warnQueueState fun(state: rizu.preview.AsyncVideoState, name: string, kind: string, time: number, extra: string?)
---@field warnMiss fun(event: rizu.preview.AsyncVideoFrameEvent)
---@field warnNonMonotonic fun(name: string, prev_time: number, frame_time: number, queue_size: integer)
---@field warnSlowPresent fun(name: string, queue_size: integer, frame_time: number, elapsed: number)
---@field warnSlowUpdate fun(frame_events: integer, control_events: integer, elapsed: number)
---@field warnWorkerOpenMissing fun(name: string, path: string?)
---@field warnWorkerOpenFailed fun(name: string, elapsed: number)
---@field warnWorkerReadMiss fun(name: string, reason: string, requested_time: number?, elapsed: number)
---@field warnWorkerReadAt fun(name: string, reason: string, requested_time: number?, frame_time: number)
---@field warnWorkerVerySlowRead fun(name: string, reason: string, requested_time: number?, frame_time: number, elapsed: number)

BgaPreviewDebug.path = "tmp/bga-preview-debug.log"

---@param ... any
function BgaPreviewDebug.warn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end

	local prefix = ""
	if love and love.timer and love.timer.getTime then
		prefix = ("%.3f "):format(love.timer.getTime())
	end
	local line = prefix .. table.concat(parts, "\t")
	print(line)
	if love and love.filesystem and love.filesystem.append then
		love.filesystem.append(BgaPreviewDebug.path, line .. "\n")
	end
end

---@param state rizu.preview.AsyncVideoState
---@param name string
---@param kind string
---@param time number
---@param extra string?
function BgaPreviewDebug:warnQueueState(state, name, kind, time, extra)
	local queue = state.queue
	local first_frame = queue[1]
	local last_frame = queue[#queue]
	self.warn(
		"video_main",
		kind,
		name,
		"time=" .. tostring(time),
		"queue=" .. tostring(#queue),
		"first=" .. tostring(first_frame and first_frame.frame_time),
		"last=" .. tostring(last_frame and last_frame.frame_time),
		"displayed=" .. tostring(state.displayed_frame_time),
		"pending=" .. tostring(state.pending),
		extra or ""
	)
end

---@param event rizu.preview.AsyncVideoFrameEvent
function BgaPreviewDebug:warnMiss(event)
	self.warn("video_main", "miss", event.video_name, "id=" .. tostring(event.request_id), "time=" .. tostring(event.requested_time))
end

---@param name string
---@param prev_time number
---@param frame_time number
---@param queue_size integer
function BgaPreviewDebug:warnNonMonotonic(name, prev_time, frame_time, queue_size)
	self.warn(
		"video_main",
		"non_monotonic",
		name,
		"prev=" .. tostring(prev_time),
		"frame=" .. tostring(frame_time),
		"queue=" .. tostring(queue_size)
	)
end

---@param name string
---@param queue_size integer
---@param frame_time number
---@param elapsed number
function BgaPreviewDebug:warnSlowPresent(name, queue_size, frame_time, elapsed)
	self.warn(
		"video_main",
		"slow_present",
		name,
		"queue=" .. tostring(queue_size),
		"frame=" .. tostring(frame_time),
		("%.3f"):format(elapsed)
	)
end

---@param frame_events integer
---@param control_events integer
---@param elapsed number
function BgaPreviewDebug:warnSlowUpdate(frame_events, control_events, elapsed)
	self.warn(
		"video_main",
		"slow_update",
		"frames=" .. tostring(frame_events),
		"control=" .. tostring(control_events),
		("%.3f"):format(elapsed)
	)
end

---@param name string
---@param path string?
function BgaPreviewDebug:warnWorkerOpenMissing(name, path)
	self.warn("video_worker", "open_missing", name, path)
end

---@param name string
---@param elapsed number
function BgaPreviewDebug:warnWorkerOpenFailed(name, elapsed)
	self.warn("video_worker", "open_failed", name, ("%.3f"):format(elapsed))
end

---@param name string
---@param reason string
---@param requested_time number?
---@param elapsed number
function BgaPreviewDebug:warnWorkerReadMiss(name, reason, requested_time, elapsed)
	self.warn("video_worker", "read_miss", name, "reason=" .. tostring(reason), "req=" .. tostring(requested_time), ("%.3f"):format(elapsed))
end

---@param name string
---@param reason string
---@param requested_time number?
---@param frame_time number
function BgaPreviewDebug:warnWorkerReadAt(name, reason, requested_time, frame_time)
	self.warn("video_worker", "readAt", name, "reason=" .. tostring(reason), "req=" .. tostring(requested_time), "frame=" .. tostring(frame_time))
end

---@param name string
---@param reason string
---@param requested_time number?
---@param frame_time number
---@param elapsed number
function BgaPreviewDebug:warnWorkerVerySlowRead(name, reason, requested_time, frame_time, elapsed)
	self.warn(
		"video_worker",
		"very_slow_read",
		name,
		"reason=" .. tostring(reason),
		"req=" .. tostring(requested_time),
		"frame=" .. tostring(frame_time),
		("%.3f"):format(elapsed)
	)
end

return BgaPreviewDebug
