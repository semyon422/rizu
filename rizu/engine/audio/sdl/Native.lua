local ffi = require("ffi")

ffi.cdef [[
	typedef uint32_t SDL_InitFlags;
	typedef uint32_t SDL_AudioDeviceID;
	typedef uint16_t SDL_AudioFormat;

	typedef struct SDL_AudioSpec {
		SDL_AudioFormat format;
		int channels;
		int freq;
	} SDL_AudioSpec;

	typedef struct SDL_AudioStream SDL_AudioStream;
	typedef void (*SDL_AudioStreamCallback)(void *userdata, SDL_AudioStream *stream, int additional_amount, int total_amount);

	bool SDL_SetHint(const char *name, const char *value);
	bool SDL_InitSubSystem(SDL_InitFlags flags);
	SDL_InitFlags SDL_WasInit(SDL_InitFlags flags);
	const char *SDL_GetCurrentAudioDriver(void);
	SDL_AudioDeviceID *SDL_GetAudioPlaybackDevices(int *count);
	const char *SDL_GetAudioDeviceName(SDL_AudioDeviceID devid);
	bool SDL_GetAudioDeviceFormat(SDL_AudioDeviceID devid, SDL_AudioSpec *spec, int *sample_frames);
	SDL_AudioStream *SDL_OpenAudioDeviceStream(SDL_AudioDeviceID devid, const SDL_AudioSpec *spec, SDL_AudioStreamCallback callback, void *userdata);
	SDL_AudioDeviceID SDL_GetAudioStreamDevice(SDL_AudioStream *stream);
	int SDL_GetAudioStreamQueued(SDL_AudioStream *stream);
	bool SDL_PutAudioStreamData(SDL_AudioStream *stream, const void *buf, int len);
	bool SDL_ClearAudioStream(SDL_AudioStream *stream);
	bool SDL_PauseAudioStreamDevice(SDL_AudioStream *stream);
	bool SDL_ResumeAudioStreamDevice(SDL_AudioStream *stream);
	void SDL_DestroyAudioStream(SDL_AudioStream *stream);
	const char *SDL_GetError(void);
	void SDL_free(void *mem);
]]

---@class rizu.audio.sdl.AudioSpec
---@field format integer
---@field channels integer
---@field freq integer

---@class rizu.audio.sdl.DeviceIds: ffi.cdata*
---@field [integer] integer

---@class rizu.audio.sdl.NativeFunctions
---@field SDL_SetHint fun(name: string, value: string): boolean
---@field SDL_InitSubSystem fun(flags: integer): boolean
---@field SDL_WasInit fun(flags: integer): integer
---@field SDL_GetCurrentAudioDriver fun(): ffi.cdata*?
---@field SDL_GetAudioPlaybackDevices fun(count: ffi.cdata*): rizu.audio.sdl.DeviceIds?
---@field SDL_GetAudioDeviceName fun(device_id: integer): ffi.cdata*?
---@field SDL_GetAudioDeviceFormat fun(device_id: integer, spec: ffi.cdata*, sample_frames: ffi.cdata*): boolean
---@field SDL_OpenAudioDeviceStream fun(device_id: integer, spec: ffi.cdata*, callback: nil, userdata: nil): ffi.cdata*?
---@field SDL_GetAudioStreamDevice fun(stream: ffi.cdata*): integer
---@field SDL_GetAudioStreamQueued fun(stream: ffi.cdata*): integer
---@field SDL_PutAudioStreamData fun(stream: ffi.cdata*, data: ffi.cdata*, bytes: integer): boolean
---@field SDL_ClearAudioStream fun(stream: ffi.cdata*): boolean
---@field SDL_PauseAudioStreamDevice fun(stream: ffi.cdata*): boolean
---@field SDL_ResumeAudioStreamDevice fun(stream: ffi.cdata*): boolean
---@field SDL_DestroyAudioStream fun(stream: ffi.cdata*)
---@field SDL_GetError fun(): ffi.cdata*?
---@field SDL_free fun(memory: ffi.cdata*)

---@type rizu.audio.sdl.NativeFunctions
local C = ffi.C

---@class rizu.audio.sdl.DeviceStatus
---@field id integer
---@field name string
---@field driver string
---@field sample_rate integer
---@field channels integer
---@field sample_frames integer

---@class rizu.audio.sdl.Stream
---@field handle ffi.cdata*
---@field device rizu.audio.sdl.DeviceStatus

local Native = {}

local SDL_INIT_AUDIO = 0x10
local SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK = 0xFFFFFFFF
local SDL_AUDIO_F32LE = 0x8120
local configured_sample_frames = 0

---@return string error
function Native.getError()
	local ptr = C.SDL_GetError()
	return ptr ~= nil and ffi.string(ptr) or "Unknown SDL error"
end

---@param sample_frames integer
---@return rizu.audio.sdl.DeviceStatus? status
---@return string? error
function Native.initPipeWire(sample_frames)
	if jit.os ~= "Linux" then
		return nil, "SDL3 PipeWire is only available on Linux"
	end
	if C.SDL_WasInit(SDL_INIT_AUDIO) == 0 then
		if not C.SDL_SetHint("SDL_AUDIO_DRIVER", "pipewire") then
			return nil, Native.getError()
		end
		if not C.SDL_SetHint("SDL_AUDIO_DEVICE_SAMPLE_FRAMES", tostring(sample_frames)) then
			return nil, Native.getError()
		end
		if not C.SDL_InitSubSystem(SDL_INIT_AUDIO) then
			return nil, Native.getError()
		end
	end

	local driver_ptr = C.SDL_GetCurrentAudioDriver()
	local driver = driver_ptr ~= nil and ffi.string(driver_ptr) or ""
	if driver ~= "pipewire" then
		return nil, "SDL initialized the " .. driver .. " audio driver instead of pipewire"
	end

	---@type {[0]: integer}
	local count = ffi.new("int[1]")
	local devices = C.SDL_GetAudioPlaybackDevices(count)
	local device_id = SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK
	local device_name = "Default playback device"
	if devices ~= nil then
		if count[0] > 0 then
			device_id = tonumber(devices[0])
			local name_ptr = C.SDL_GetAudioDeviceName(devices[0])
			if name_ptr ~= nil then
				device_name = ffi.string(name_ptr)
			end
		end
		C.SDL_free(devices)
	end

	---@type {[0]: rizu.audio.sdl.AudioSpec}
	local spec = ffi.new("SDL_AudioSpec[1]")
	---@type {[0]: integer}
	local actual_frames = ffi.new("int[1]")
	if not C.SDL_GetAudioDeviceFormat(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, spec, actual_frames) then
		return nil, Native.getError()
	end

	local device_sample_frames = actual_frames[0]
	if device_sample_frames <= 0 then
		device_sample_frames = sample_frames
	end
	configured_sample_frames = device_sample_frames
	return {
		id = device_id,
		name = device_name,
		driver = driver,
		sample_rate = spec[0].freq,
		channels = spec[0].channels,
		sample_frames = device_sample_frames,
	}
end

---@param sample_rate integer
---@param channels integer
---@return rizu.audio.sdl.Stream
function Native.open(sample_rate, channels)
	---@type {[0]: rizu.audio.sdl.AudioSpec}
	local spec = ffi.new("SDL_AudioSpec[1]")
	spec[0].format = SDL_AUDIO_F32LE
	spec[0].channels = channels
	spec[0].freq = sample_rate
	local handle = C.SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, spec, nil, nil)
	assert(handle ~= nil, Native.getError())

	---@type {[0]: rizu.audio.sdl.AudioSpec}
	local device_spec = ffi.new("SDL_AudioSpec[1]")
	---@type {[0]: integer}
	local sample_frames = ffi.new("int[1]")
	local device_id = tonumber(C.SDL_GetAudioStreamDevice(handle))
	assert(C.SDL_GetAudioDeviceFormat(device_id, device_spec, sample_frames), Native.getError())
	local name_ptr = C.SDL_GetAudioDeviceName(device_id)
	local driver_ptr = C.SDL_GetCurrentAudioDriver()
	local device_sample_frames = sample_frames[0]
	if device_sample_frames <= 0 then
		device_sample_frames = configured_sample_frames
	end
	return {
		handle = handle,
		device = {
			id = device_id,
			name = name_ptr ~= nil and ffi.string(name_ptr) or "Default playback device",
			driver = driver_ptr ~= nil and ffi.string(driver_ptr) or "",
			sample_rate = device_spec[0].freq,
			channels = device_spec[0].channels,
			sample_frames = device_sample_frames,
		},
	}
end

---@param stream rizu.audio.sdl.Stream
---@return integer bytes
function Native.getQueued(stream)
	local bytes = C.SDL_GetAudioStreamQueued(stream.handle)
	assert(bytes >= 0, Native.getError())
	return bytes
end

---@param stream rizu.audio.sdl.Stream
---@param data ffi.cdata*
---@param bytes integer
function Native.put(stream, data, bytes)
	assert(C.SDL_PutAudioStreamData(stream.handle, data, bytes), Native.getError())
end

---@param stream rizu.audio.sdl.Stream
function Native.clear(stream)
	assert(C.SDL_ClearAudioStream(stream.handle), Native.getError())
end

---@param stream rizu.audio.sdl.Stream
function Native.play(stream)
	assert(C.SDL_ResumeAudioStreamDevice(stream.handle), Native.getError())
end

---@param stream rizu.audio.sdl.Stream
function Native.pause(stream)
	assert(C.SDL_PauseAudioStreamDevice(stream.handle), Native.getError())
end

---@param stream rizu.audio.sdl.Stream
function Native.close(stream)
	C.SDL_DestroyAudioStream(stream.handle)
end

return Native
