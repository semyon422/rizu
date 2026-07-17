local class = require("class")
local ffi = require("ffi")
local needle = require("ai.needle")

local SEQ_LEN = 8
local D_MODEL = 512
local HEADS = 8
local KV_HEADS = 4
local HEAD_DIM = 64

local DENSE_SOURCE = [[
#pragma language glsl4
layout(local_size_x = 64) in;
layout(std430) readonly buffer Input { float values[]; } input_buffer;
layout(std430) readonly buffer Weights { uint values[]; } weights_buffer;
layout(std430) readonly buffer Scales { float values[]; } scales_buffer;
layout(std430) writeonly buffer Output { float values[]; } output_buffer;
uniform int input_width; uniform int output_width; uniform int rows;
shared float input_tile[512];
int q8(uint packed, int component) { uint v = (packed >> uint(component * 8)) & 255u; return v > 127u ? int(v) - 256 : int(v); }
void computemain() {
	uint lane = gl_LocalInvocationID.x;
	uint blocks = uint((output_width + 63) / 64);
	uint row = gl_WorkGroupID.x / blocks;
	uint column = (gl_WorkGroupID.x % blocks) * 64u + lane;
	uint input_base = row * uint(input_width);
	for (uint i = lane; i < uint(input_width); i += 64u) input_tile[i] = input_buffer.values[input_base + i];
	barrier();
	if (row >= uint(rows) || column >= uint(output_width)) return;
	float sum = 0.0; uint weight_base = column * uint(input_width / 4);
	for (int i = 0; i < input_width / 4; i++) { uint w = weights_buffer.values[weight_base + uint(i)]; uint x = input_base + uint(i * 4);
		sum += input_tile[uint(i * 4)] * float(q8(w, 0)); sum += input_tile[uint(i * 4 + 1)] * float(q8(w, 1));
		sum += input_tile[uint(i * 4 + 2)] * float(q8(w, 2)); sum += input_tile[uint(i * 4 + 3)] * float(q8(w, 3)); }
	output_buffer.values[row * uint(output_width) + column] = sum * scales_buffer.values[column];
}
]]

local NORM_ROPE_SOURCE = [[
#pragma language glsl4
layout(local_size_x = 64) in;
layout(std430) buffer Values { float values[]; } value_buffer;
layout(std430) readonly buffer Scales { float values[]; } scale_buffer;
uniform int heads; uniform int rows;
void computemain() {
	uint index = love_GlobalThreadID.x; if (index >= uint(rows * heads)) return;
	uint base = index * 64u; float sum = 0.0;
	for (uint d = 0u; d < 64u; d++) sum += value_buffer.values[base + d] * value_buffer.values[base + d];
	float rms = sqrt(sum / 64.0); for (uint d = 0u; d < 64u; d++) value_buffer.values[base + d] *= (1.0 + scale_buffer.values[d]) / rms;
	float position = float(index / uint(heads));
	for (uint d = 0u; d < 32u; d++) { float angle = position / pow(10000.0, float(2u * d) / 64.0); float a = value_buffer.values[base + d]; float b = value_buffer.values[base + 32u + d]; float c = cos(angle); float s = sin(angle); value_buffer.values[base + d] = a * c - b * s; value_buffer.values[base + 32u + d] = b * c + a * s; }
}
]]

local SCORES_SOURCE = [[
#pragma language glsl4
layout(local_size_x = 64) in;
layout(std430) readonly buffer Query { float values[]; } query_buffer;
layout(std430) readonly buffer Key { float values[]; } key_buffer;
layout(std430) writeonly buffer Scores { float values[]; } score_buffer;
uniform int rows;
void computemain() {
	uint index = love_GlobalThreadID.x; uint count = uint(rows * 8 * rows); if (index >= count) return;
	uint key = index % uint(rows); uint query_head = index / uint(rows); uint head = query_head % 8u; uint token = query_head / 8u; uint key_head = head / 2u;
	float score = 0.0; uint q = (token * 8u + head) * 64u; uint k = (key * 4u + key_head) * 64u;
	for (uint d = 0u; d < 64u; d++) score += query_buffer.values[q + d] * key_buffer.values[k + d];
	score_buffer.values[index] = score * 0.125;
}
]]

local CONTEXT_SOURCE = [[
#pragma language glsl4
layout(local_size_x = 64) in;
layout(std430) readonly buffer Scores { float values[]; } score_buffer;
layout(std430) readonly buffer Value { float values[]; } value_buffer;
layout(std430) writeonly buffer Context { float values[]; } context_buffer;
uniform int rows;
void computemain() {
	uint index = love_GlobalThreadID.x; if (index >= uint(rows * 512)) return;
	uint token = index / 512u; uint rem = index % 512u; uint head = rem / 64u; uint dimension = rem % 64u; uint key_head = head / 2u; uint score_base = (token * 8u + head) * uint(rows);
	float maximum = -3.402823e38; for (int key = 0; key < rows; key++) maximum = max(maximum, score_buffer.values[score_base + uint(key)]);
	float denominator = 0.0; float result = 0.0;
	for (int key = 0; key < rows; key++) { float weight = exp(score_buffer.values[score_base + uint(key)] - maximum); denominator += weight; result += weight * value_buffer.values[(uint(key) * 4u + key_head) * 64u + dimension]; }
	context_buffer.values[index] = result / denominator;
}
]]

---@class rizu.ai.NeedleGpuEncoderProbe
---@operator call: rizu.ai.NeedleGpuEncoderProbe
---@field graphics love.Graphics
---@field data love.Data
---@field now fun(): number
---@field state "idle"|"unsupported"|"waiting"|"ready"|"error"
---@field readback love.GraphicsReadback?
local NeedleGpuEncoderProbe = class()

---@param graphics? love.Graphics
---@param data? love.Data
---@param now? fun(): number
function NeedleGpuEncoderProbe:new(graphics, data, now)
	self.graphics = graphics or love.graphics
	self.data = data or love.data
	self.now = now or love.timer.getTime
	self.state = "idle"
end

local function log(message)
	local line = "[Needle GPU encoder] " .. message
	print(line)
	if love and love.filesystem then pcall(love.filesystem.append, "needle_gpu_probe.log", line .. "\n") end
end

local function f16(value)
	local sign = value >= 0x8000 and -1 or 1
	local exponent = math.floor(value / 1024) % 32
	local mantissa = value % 1024
	if exponent == 0 then return sign * mantissa * 2 ^ -24 end
	if exponent == 31 then return sign * math.huge end
	return sign * (1 + mantissa / 1024) * 2 ^ (exponent - 15)
end

function NeedleGpuEncoderProbe:release()
	self.readback = nil
	self.dense_shader = nil
	self.norm_rope_shader = nil
	self.score_shader = nil
	self.context_shader = nil
	self.buffers = nil
	if self.state == "waiting" then self.state = "idle" end
end

---@param bytes love.ByteData
---@param count integer
---@return number[]
local function read_floats(bytes, count)
	local values = {}
	for i = 0, count - 1 do values[i + 1] = bytes:getFloat(i * 4) end
	return values
end

---@param context needle.Context
---@param name string
---@param layer integer
---@param width integer
---@param output_width integer
---@return love.ByteData weights
---@return love.ByteData scales
function NeedleGpuEncoderProbe:load_projection(context, name, layer, width, output_width)
	local q8_index = assert(context:find_tensor(name .. ".q8"))
	local scale_index = assert(context:find_tensor(name .. ".q8_scale"))
	local q8_pointer = assert(context:tensor_data(q8_index))
	local scale_pointer = assert(context:tensor_data(scale_index))
	local source = ffi.cast("const signed char *", q8_pointer) + layer * width * output_width
	local weights_data = self.data.newByteData(width * output_width)
	local weights = ffi.cast("signed char *", weights_data:getFFIPointer())
	for output = 0, output_width - 1 do for input = 0, width - 1 do weights[output * width + input] = source[input * output_width + output] end end
	local scales_data = self.data.newByteData(output_width * 4)
	ffi.copy(scales_data:getFFIPointer(), ffi.cast("const unsigned char *", scale_pointer) + layer * output_width * 4, output_width * 4)
	return weights_data, scales_data
end

---@param context needle.Context
---@param name string
---@param layer integer
---@return love.ByteData
function NeedleGpuEncoderProbe:load_f16_scales(context, name, layer)
	local index = assert(context:find_tensor(name))
	local pointer = ffi.cast("const uint16_t *", assert(context:tensor_data(index)))
	local data = self.data.newByteData(HEAD_DIM * 4)
	local out = ffi.cast("float *", data:getFFIPointer())
	for i = 0, HEAD_DIM - 1 do out[i] = f16(pointer[layer * HEAD_DIM + i]) end
	return data
end

---@param shader love.Shader
---@param input love.Buffer
---@param weights love.Buffer
---@param scales love.Buffer
---@param output love.Buffer
---@param input_width integer
---@param output_width integer
---@param rows integer
function NeedleGpuEncoderProbe:project(shader, input, weights, scales, output, input_width, output_width)
	shader:send("Input", input)
	shader:send("Weights", weights)
	shader:send("Scales", scales)
	shader:send("Output", output)
	shader:send("input_width", input_width)
	shader:send("output_width", output_width)
	shader:send("rows", self.seq_len)
	self.graphics.dispatchThreadgroups(shader, self.seq_len * math.ceil(output_width / 64))
end

---@param model_path string
---@param seq_len? integer
---@return boolean
function NeedleGpuEncoderProbe:start(model_path, seq_len)
	self:release()
	self.seq_len = seq_len or SEQ_LEN
	local supported = self.graphics.getSupported()
	if not supported.glsl4 then
		self.state = "unsupported"
		self.error = "GLSL 4 compute shaders are unavailable"
		log("unavailable: " .. self.error)
		return false
	end
	local started_at = self.now()
	local context
	local ok, err = pcall(function()
		context = assert(needle.load(model_path))
		local input_values = {}
		for i = 0, self.seq_len * D_MODEL - 1 do input_values[i + 1] = math.sin(i * 0.017) * 0.5 + math.cos(i * 0.001) * 0.25 end
		self.expected = assert(context:encoder_self_attention(0, input_values, self.seq_len))
		local input_data = self.data.newByteData(self.seq_len * D_MODEL * 4)
		local input = ffi.cast("float *", input_data:getFFIPointer())
		for i = 0, #input_values - 1 do input[i] = input_values[i + 1] end
		local q_weights, q_scales = self:load_projection(context, "encoder/layers/EncoderBlock_0/self_attn/q_proj/kernel", 0, D_MODEL, D_MODEL)
		local k_weights, k_scales = self:load_projection(context, "encoder/layers/EncoderBlock_0/self_attn/k_proj/kernel", 0, D_MODEL, KV_HEADS * HEAD_DIM)
		local v_weights, v_scales = self:load_projection(context, "encoder/layers/EncoderBlock_0/self_attn/v_proj/kernel", 0, D_MODEL, KV_HEADS * HEAD_DIM)
		local out_weights, out_scales = self:load_projection(context, "encoder/layers/EncoderBlock_0/self_attn/out_proj/kernel", 0, D_MODEL, D_MODEL)
		self.dense_shader = self.graphics.newComputeShader(DENSE_SOURCE, {debugname = "Needle GPU Encoder Q8 Dense"})
		self.norm_rope_shader = self.graphics.newComputeShader(NORM_ROPE_SOURCE, {debugname = "Needle GPU Encoder Norm RoPE"})
		self.score_shader = self.graphics.newComputeShader(SCORES_SOURCE, {debugname = "Needle GPU Encoder Scores"})
		self.context_shader = self.graphics.newComputeShader(CONTEXT_SOURCE, {debugname = "Needle GPU Encoder Context"})
		local function buffer(format, data, name) return self.graphics.newBuffer(format, data, {shaderstorage = true, usage = "static", debugname = name}) end
		self.buffers = {
			input = buffer("float", input_data, "Needle GPU Encoder Input"),
			q_weights = buffer("uint32", q_weights, "Needle GPU Encoder Q Weights"), q_scales = buffer("float", q_scales, "Needle GPU Encoder Q Scales"),
			k_weights = buffer("uint32", k_weights, "Needle GPU Encoder K Weights"), k_scales = buffer("float", k_scales, "Needle GPU Encoder K Scales"),
			v_weights = buffer("uint32", v_weights, "Needle GPU Encoder V Weights"), v_scales = buffer("float", v_scales, "Needle GPU Encoder V Scales"),
			out_weights = buffer("uint32", out_weights, "Needle GPU Encoder Out Weights"), out_scales = buffer("float", out_scales, "Needle GPU Encoder Out Scales"),
			q_norm = buffer("float", self:load_f16_scales(context, "encoder/layers/EncoderBlock_0/self_attn/q_norm/scale", 0), "Needle GPU Encoder Q Norm"),
			k_norm = buffer("float", self:load_f16_scales(context, "encoder/layers/EncoderBlock_0/self_attn/k_norm/scale", 0), "Needle GPU Encoder K Norm"),
			q = self.graphics.newBuffer("float", self.seq_len * D_MODEL, {shaderstorage = true, debugname = "Needle GPU Encoder Q"}),
			k = self.graphics.newBuffer("float", self.seq_len * KV_HEADS * HEAD_DIM, {shaderstorage = true, debugname = "Needle GPU Encoder K"}),
			v = self.graphics.newBuffer("float", self.seq_len * KV_HEADS * HEAD_DIM, {shaderstorage = true, debugname = "Needle GPU Encoder V"}),
			scores = self.graphics.newBuffer("float", self.seq_len * HEADS * self.seq_len, {shaderstorage = true, debugname = "Needle GPU Encoder Scores"}),
			context = self.graphics.newBuffer("float", self.seq_len * D_MODEL, {shaderstorage = true, debugname = "Needle GPU Encoder Context"}),
			output = self.graphics.newBuffer("float", self.seq_len * D_MODEL, {shaderstorage = true, debugname = "Needle GPU Encoder Output"}),
		}
	end)
	if context then context:close() end
	if not ok then self.state = "error"; self.error = tostring(err); log("error: " .. self.error); self:release(); return false end
	local b = self.buffers
	self:project(self.dense_shader, b.input, b.q_weights, b.q_scales, b.q, D_MODEL, D_MODEL)
	self:project(self.dense_shader, b.input, b.k_weights, b.k_scales, b.k, D_MODEL, KV_HEADS * HEAD_DIM)
	self:project(self.dense_shader, b.input, b.v_weights, b.v_scales, b.v, D_MODEL, KV_HEADS * HEAD_DIM)
	self.norm_rope_shader:send("Values", b.q); self.norm_rope_shader:send("Scales", b.q_norm); self.norm_rope_shader:send("heads", HEADS); self.norm_rope_shader:send("rows", self.seq_len); self.graphics.dispatchThreadgroups(self.norm_rope_shader, self.seq_len * HEADS)
	self.norm_rope_shader:send("Values", b.k); self.norm_rope_shader:send("Scales", b.k_norm); self.norm_rope_shader:send("heads", KV_HEADS); self.norm_rope_shader:send("rows", self.seq_len); self.graphics.dispatchThreadgroups(self.norm_rope_shader, self.seq_len * KV_HEADS)
	self.score_shader:send("Query", b.q); self.score_shader:send("Key", b.k); self.score_shader:send("Scores", b.scores); self.score_shader:send("rows", self.seq_len); self.graphics.dispatchThreadgroups(self.score_shader, math.ceil(self.seq_len * HEADS * self.seq_len / 64))
	self.context_shader:send("Scores", b.scores); self.context_shader:send("Value", b.v); self.context_shader:send("Context", b.context); self.context_shader:send("rows", self.seq_len); self.graphics.dispatchThreadgroups(self.context_shader, math.ceil(self.seq_len * D_MODEL / 64))
	self:project(self.dense_shader, b.context, b.out_weights, b.out_scales, b.output, D_MODEL, D_MODEL)
	self.preparation_seconds = self.now() - started_at
	self.dispatch_started_at = self.now()
	self.readback = self.graphics.readbackBufferAsync(b.output, 0, self.seq_len * D_MODEL * 4)
	self.state = "waiting"
	log(("queued layer 0 self-attention for %d tokens after %.4fs preparation; waiting for whole-output readback"):format(self.seq_len, self.preparation_seconds))
	return true
end

---@param model_path string
---@return boolean
function NeedleGpuEncoderProbe:startPrefill(model_path)
	return self:start(model_path, 461)
end

function NeedleGpuEncoderProbe:update()
	if self.state ~= "waiting" or not self.readback or not self.readback:isComplete() then return end
	if self.readback:hasError() then self.state = "error"; self.error = "GPU encoder readback failed"; log("error: " .. self.error); return end
	local actual = read_floats(self.readback:getBufferData(), self.seq_len * D_MODEL)
	local maximum = 0
	local maximum_index = 1
	local sum = 0
	for i = 1, #actual do
		local difference = math.abs(actual[i] - self.expected[i])
		if difference > maximum then maximum = difference; maximum_index = i end
		sum = sum + difference
	end
	local mean = sum / #actual
	local elapsed = self.now() - self.dispatch_started_at
	local allowed = 0.002 + math.abs(self.expected[maximum_index]) * 0.00005
	log(("layer 0 self-attention complete: max_diff=%.7f (allowed %.7f at value %.6f) mean_diff=%.7f gpu=%.4fs first gpu=%.6f cpu=%.6f"):format(maximum, allowed, self.expected[maximum_index], mean, elapsed, actual[1], self.expected[1]))
	if maximum > allowed then self.state = "error"; self.error = "GPU encoder result differs from CPU"; log("error: " .. self.error); return end
	self.state = "ready"
end

return NeedleGpuEncoderProbe
