local class = require("class")
local ffi = require("ffi")
local needle = require("ai.needle")

local INPUT_WIDTH = 512
local OUTPUT_WIDTH = 512
local BATCH_ROWS = 461
local THREADS_PER_GROUP = 64
local ITERATIONS = 3

---@class rizu.ai.GpuProbeSupport
---@field glsl4 boolean

---@class rizu.ai.GpuProbeLimits
---@field shaderstoragebuffersize number

---@class rizu.ai.GpuProbeByteData
---@field getFFIPointer fun(self: rizu.ai.GpuProbeByteData): ffi.cdata*
---@field getFloat fun(self: rizu.ai.GpuProbeByteData, offset: integer): number

---@class rizu.ai.GpuProbeData
---@field newByteData fun(value: string|integer): rizu.ai.GpuProbeByteData

---@class rizu.ai.GpuProbeShader
---@field send fun(self: rizu.ai.GpuProbeShader, name: string, value: rizu.ai.GpuProbeBuffer|integer)

---@class rizu.ai.GpuProbeBuffer

---@class rizu.ai.GpuProbeReadback
---@field isComplete fun(self: rizu.ai.GpuProbeReadback): boolean
---@field hasError fun(self: rizu.ai.GpuProbeReadback): boolean
---@field getBufferData fun(self: rizu.ai.GpuProbeReadback): rizu.ai.GpuProbeByteData

---@class rizu.ai.GpuProbeGraphics
---@field getSupported fun(): rizu.ai.GpuProbeSupport
---@field getSystemLimits fun(): rizu.ai.GpuProbeLimits
---@field getRendererInfo fun(): string, string, string, string
---@field newComputeShader fun(source: string, options: {debugname: string}): rizu.ai.GpuProbeShader
---@field newBuffer fun(format: string, data: rizu.ai.GpuProbeByteData|integer, options: {shaderstorage: boolean, usage: string?, debugname: string}): rizu.ai.GpuProbeBuffer
---@field dispatchThreadgroups fun(shader: rizu.ai.GpuProbeShader, groups: integer)
---@field readbackBufferAsync fun(buffer: rizu.ai.GpuProbeBuffer, offset: integer, size: integer): rizu.ai.GpuProbeReadback

---@class rizu.ai.GpuProbeInt8Ptr: ffi.cdata*
---@field [integer] integer

---@class rizu.ai.GpuProbeFloatPtr: ffi.cdata*
---@field [integer] number

local COMPUTE_SOURCE = [[
#pragma language glsl4
layout(local_size_x = 64) in;

layout(std430) readonly buffer ProbeInput {
	float values[];
} probe_input;

layout(std430) readonly buffer ProbeWeights {
	uint values[];
} probe_weights;

layout(std430) writeonly buffer ProbeOutput {
	float values[];
} probe_output;

layout(std430) readonly buffer ProbeScales {
	float values[];
} probe_scales;

uniform int width;
uniform int output_width;
uniform int batch_rows;

int unpackQ8(uint packed, int component) {
	uint byte_value = (packed >> uint(component * 8)) & 255u;
	return byte_value > 127u ? int(byte_value) - 256 : int(byte_value);
}

void computemain() {
	uint output_index = love_GlobalThreadID.x;
	uint total_outputs = uint(batch_rows * output_width);
	if (output_index >= total_outputs) return;
	uint row = output_index / uint(output_width);
	uint output_column = output_index % uint(output_width);

	float sum = 0.0;
	uint weight_offset = output_column * uint(width / 4);
	uint input_row_offset = row * uint(width);
	for (int packed_index = 0; packed_index < width / 4; packed_index++) {
		uint packed = probe_weights.values[weight_offset + uint(packed_index)];
		uint input_offset = input_row_offset + uint(packed_index * 4);
		sum += probe_input.values[input_offset] * float(unpackQ8(packed, 0));
		sum += probe_input.values[input_offset + 1u] * float(unpackQ8(packed, 1));
		sum += probe_input.values[input_offset + 2u] * float(unpackQ8(packed, 2));
		sum += probe_input.values[input_offset + 3u] * float(unpackQ8(packed, 3));
	}
	probe_output.values[output_index] = sum * probe_scales.values[output_column];
}
]]

---@class rizu.ai.NeedleGpuProbe
---@operator call: rizu.ai.NeedleGpuProbe
---@field graphics rizu.ai.GpuProbeGraphics
---@field data rizu.ai.GpuProbeData
---@field now fun(): number
---@field state "idle"|"unsupported"|"waiting"|"ready"|"error"
---@field readback rizu.ai.GpuProbeReadback?
---@field shader rizu.ai.GpuProbeShader?
---@field input rizu.ai.GpuProbeBuffer?
---@field weights rizu.ai.GpuProbeBuffer?
---@field output rizu.ai.GpuProbeBuffer?
---@field scales rizu.ai.GpuProbeBuffer?
---@field expected_result number?
---@field error string?
---@field dispatch_started_at number
---@field upload_seconds number
---@field iteration integer
local NeedleGpuProbe = class()

---@param graphics? rizu.ai.GpuProbeGraphics
---@param data? rizu.ai.GpuProbeData
---@param now? fun(): number
function NeedleGpuProbe:new(graphics, data, now)
	self.graphics = graphics or love.graphics
	self.data = data or love.data
	self.now = now or love.timer.getTime
	self.state = "idle"
end

---@param message string
local function log(message)
	local line = "[Needle GPU] " .. message
	print(line)
	if love and love.filesystem then
		pcall(love.filesystem.append, "needle_gpu_probe.log", line .. "\n")
	end
end

function NeedleGpuProbe:release()
	self.readback = nil
	self.shader = nil
	self.input = nil
	self.weights = nil
	self.output = nil
	self.scales = nil
	self.expected_result = nil
	if self.state == "waiting" then self.state = "idle" end
end

---@param message string?
---@return boolean supported
function NeedleGpuProbe:checkSupported(message)
	local supported = self.graphics.getSupported()
	local limits = self.graphics.getSystemLimits()
	local renderer_ok, renderer_name, renderer_version, renderer_vendor, renderer_device = pcall(self.graphics.getRendererInfo)
	local renderer = "unknown"
	if renderer_ok then
		renderer = table.concat({renderer_name, renderer_version, renderer_vendor, renderer_device}, " / ")
	end
	log(("renderer=%s glsl4=%s shaderstoragebuffersize=%s"):format(
		renderer,
		tostring(supported.glsl4),
		tostring(limits.shaderstoragebuffersize)
	))
	if supported.glsl4 then return true end
	self.state = "unsupported"
	self.error = message or "GLSL 4 compute shaders are unavailable"
	log("unavailable: " .. self.error)
	return false
end

function NeedleGpuProbe:dispatch()
	self.dispatch_started_at = self.now()
	self.graphics.dispatchThreadgroups(self.shader, math.ceil(BATCH_ROWS * OUTPUT_WIDTH / THREADS_PER_GROUP))
	self.readback = self.graphics.readbackBufferAsync(self.output, 0, 4)
end

---@return boolean started
function NeedleGpuProbe:start()
	self:release()
	if not self:checkSupported() then return false end

	local started_at = self.now()
	local ok, err = pcall(function()
		self.shader = self.graphics.newComputeShader(COMPUTE_SOURCE, {debugname = "Needle Q8 Probe"})
		self.input = self.graphics.newBuffer(
			"float",
			self.data.newByteData(string.rep(string.char(0, 0, 128, 63), BATCH_ROWS * INPUT_WIDTH)),
			{shaderstorage = true, debugname = "Needle Q8 Probe Input"}
		)
		self.weights = self.graphics.newBuffer(
			"uint32",
			self.data.newByteData(string.rep(string.char(1, 1, 1, 1), OUTPUT_WIDTH * INPUT_WIDTH / 4)),
			{shaderstorage = true, usage = "static", debugname = "Needle Q8 Probe Weights"}
		)
		self.scales = self.graphics.newBuffer(
			"float",
			self.data.newByteData(string.rep(string.char(0, 0, 128, 63), OUTPUT_WIDTH)),
			{shaderstorage = true, usage = "static", debugname = "Needle Q8 Probe Scales"}
		)
		self.output = self.graphics.newBuffer("float", BATCH_ROWS * OUTPUT_WIDTH, {shaderstorage = true, debugname = "Needle Q8 Probe Output"})
		self.shader:send("ProbeInput", self.input)
		self.shader:send("ProbeWeights", self.weights)
		self.shader:send("ProbeOutput", self.output)
		self.shader:send("ProbeScales", self.scales)
		self.shader:send("width", INPUT_WIDTH)
		self.shader:send("output_width", OUTPUT_WIDTH)
		self.shader:send("batch_rows", BATCH_ROWS)
	end)
	if not ok then
		self.state = "error"
		self.error = tostring(err)
		log("error: " .. self.error)
		self:release()
		return false
	end
	self.upload_seconds = self.now() - started_at
	self.iteration = 1
	self:dispatch()
	self.state = "waiting"
	log(("prepared q8 %dx%d x %d dense projection in %.4fs; dispatching iteration 1/%d"):format(
		BATCH_ROWS, INPUT_WIDTH, OUTPUT_WIDTH, self.upload_seconds, ITERATIONS
	))
	return true
end

---@param model_path string
---@return boolean started
function NeedleGpuProbe:startModel(model_path)
	self:release()
	if not self:checkSupported() then return false end
	local started_at = self.now()
	---@type needle.Context?
	local context
	local ok, err = pcall(function()
		context = assert(needle.load(model_path))
		local q8_index = assert(context:find_tensor("encoder/layers/EncoderBlock_0/self_attn/q_proj/kernel.q8"))
		local scale_index = assert(context:find_tensor("encoder/layers/EncoderBlock_0/self_attn/q_proj/kernel.q8_scale"))
		local q8 = assert(context:tensor(q8_index))
		local scales = assert(context:tensor(scale_index))
		assert(q8.dtype_name == "i8" and q8.shape[1] >= 1 and q8.shape[2] == INPUT_WIDTH and q8.shape[3] == OUTPUT_WIDTH)
		assert(scales.dtype_name == "f32" and scales.shape[1] >= 1 and scales.shape[2] == OUTPUT_WIDTH)
		local q8_pointer = assert(context:tensor_data(q8_index))
		local scale_pointer = assert(context:tensor_data(scale_index))
		local source = ffi.cast("const signed char *", q8_pointer) --[[@as rizu.ai.GpuProbeInt8Ptr]]
		local weights_data = self.data.newByteData(INPUT_WIDTH * OUTPUT_WIDTH)
		local weights = ffi.cast("signed char *", weights_data:getFFIPointer()) --[[@as rizu.ai.GpuProbeInt8Ptr]]
		local expected_sum = 0
		for output = 0, OUTPUT_WIDTH - 1 do
			for input = 0, INPUT_WIDTH - 1 do
				local value = source[input * OUTPUT_WIDTH + output]
				weights[output * INPUT_WIDTH + input] = value
				if output == 0 then expected_sum = expected_sum + value end
			end
		end
		local scales_data = self.data.newByteData(OUTPUT_WIDTH * 4)
		ffi.copy(scales_data:getFFIPointer(), scale_pointer, OUTPUT_WIDTH * 4)
		local scale_values = ffi.cast("const float *", scale_pointer) --[[@as rizu.ai.GpuProbeFloatPtr]]
		self.expected_result = expected_sum * scale_values[0]

		self.shader = self.graphics.newComputeShader(COMPUTE_SOURCE, {debugname = "Needle Model Q8 Projection"})
		self.input = self.graphics.newBuffer(
			"float",
			self.data.newByteData(string.rep(string.char(0, 0, 128, 63), BATCH_ROWS * INPUT_WIDTH)),
			{shaderstorage = true, debugname = "Needle Model Q8 Projection Input"}
		)
		self.weights = self.graphics.newBuffer("uint32", weights_data, {shaderstorage = true, usage = "static", debugname = "Needle Model Q8 Projection Weights"})
		self.scales = self.graphics.newBuffer("float", scales_data, {shaderstorage = true, usage = "static", debugname = "Needle Model Q8 Projection Scales"})
		self.output = self.graphics.newBuffer("float", BATCH_ROWS * OUTPUT_WIDTH, {shaderstorage = true, debugname = "Needle Model Q8 Projection Output"})
		self.shader:send("ProbeInput", self.input)
		self.shader:send("ProbeWeights", self.weights)
		self.shader:send("ProbeScales", self.scales)
		self.shader:send("ProbeOutput", self.output)
		self.shader:send("width", INPUT_WIDTH)
		self.shader:send("output_width", OUTPUT_WIDTH)
		self.shader:send("batch_rows", BATCH_ROWS)
	end)
	if context then context:close() end
	if not ok then
		self.state = "error"
		self.error = tostring(err)
		log("model error: " .. self.error)
		self:release()
		return false
	end
	self.upload_seconds = self.now() - started_at
	self.iteration = 1
	self:dispatch()
	self.state = "waiting"
	log(("prepared real model q_proj layer 0 in %.4fs; expected first value=%.6f; dispatching iteration 1/%d"):format(
		self.upload_seconds, self.expected_result, ITERATIONS
	))
	return true
end

function NeedleGpuProbe:update()
	if self.state ~= "waiting" or not self.readback or not self.readback:isComplete() then return end
	if self.readback:hasError() then
		self.state = "error"
		self.error = "GPU readback failed"
		log("error: " .. self.error)
		return
	end
	local result = self.readback:getBufferData():getFloat(0)
	local elapsed = self.now() - self.dispatch_started_at
	local expected = self.expected_result or INPUT_WIDTH
	log(("iteration %d/%d: result=%.6f expected=%.6f async latency=%.4fs"):format(
		self.iteration, ITERATIONS, result, expected, elapsed
	))
	if math.abs(result - expected) > math.max(0.01, math.abs(expected) * 0.0001) then
		self.state = "error"
		self.error = "incorrect Q8 projection result"
		log("error: " .. self.error)
		return
	end
	self.iteration = self.iteration + 1
	if self.iteration <= ITERATIONS then
		self:dispatch()
		return
	end
	self.state = "ready"
	log("complete: warm Q8 dense-projection benchmark succeeded")
end

return NeedleGpuProbe
