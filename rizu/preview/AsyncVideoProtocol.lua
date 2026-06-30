local AsyncVideoProtocol = {}

---@class rizu.preview.AsyncVideoFrame
---@field frame_time number
---@field image_data love.ImageData
---@field width integer
---@field height integer
---@field frame_rate number?
---@field ended boolean?

---@class rizu.preview.AsyncVideoLoadEvent
---@field type "load"
---@field generation integer
---@field video_names string[]
---@field video_paths {[string]: string}

---@class rizu.preview.AsyncVideoFrameRequestEvent
---@field type "frame"
---@field generation integer
---@field video_name string
---@field request_id integer
---@field time number
---@field frame_duration number
---@field count integer

---@class rizu.preview.AsyncVideoStopEvent
---@field type "stop"|"unload"

---@class rizu.preview.AsyncVideoLoadedEvent
---@field type "loaded"
---@field generation integer

---@class rizu.preview.AsyncVideoFrameEvent
---@field type "frame"
---@field generation integer
---@field video_name string
---@field request_id integer
---@field requested_time number
---@field frame_time number?
---@field width integer?
---@field height integer?
---@field frame_rate number?
---@field image_data love.ImageData?
---@field ended boolean?

---@class rizu.preview.AsyncVideoBatchDoneEvent
---@field type "batch_done"
---@field generation integer
---@field video_name string
---@field request_id integer
---@field requested_time number
---@field sent integer

---@alias rizu.preview.AsyncVideoInputEvent rizu.preview.AsyncVideoLoadEvent|rizu.preview.AsyncVideoFrameRequestEvent|rizu.preview.AsyncVideoStopEvent
---@alias rizu.preview.AsyncVideoOutputEvent rizu.preview.AsyncVideoLoadedEvent|rizu.preview.AsyncVideoFrameEvent|rizu.preview.AsyncVideoBatchDoneEvent

---@class rizu.preview.IAsyncVideoTransport
---@field start fun(self: rizu.preview.IAsyncVideoTransport, id: string)
---@field send fun(self: rizu.preview.IAsyncVideoTransport, event: rizu.preview.AsyncVideoInputEvent)
---@field pop fun(self: rizu.preview.IAsyncVideoTransport): rizu.preview.AsyncVideoOutputEvent?
---@field checkError fun(self: rizu.preview.IAsyncVideoTransport)
---@field isRunning fun(self: rizu.preview.IAsyncVideoTransport): boolean
---@field stop fun(self: rizu.preview.IAsyncVideoTransport)

---@class rizu.preview.IAsyncVideoLogger
---@field warnQueueState fun(self: rizu.preview.IAsyncVideoLogger, state: rizu.preview.AsyncVideoState, name: string, kind: string, time: number, extra: string?)
---@field warnMiss fun(self: rizu.preview.IAsyncVideoLogger, event: rizu.preview.AsyncVideoFrameEvent)
---@field warnNonMonotonic fun(self: rizu.preview.IAsyncVideoLogger, name: string, prev_time: number, frame_time: number, queue_size: integer)
---@field warnSlowPresent fun(self: rizu.preview.IAsyncVideoLogger, name: string, queue_size: integer, frame_time: number, elapsed: number)
---@field warnSlowUpdate fun(self: rizu.preview.IAsyncVideoLogger, frame_events: integer, control_events: integer, elapsed: number)

return AsyncVideoProtocol
