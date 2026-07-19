## Goal

Provide an in-game AI chat backed by an OpenAI-compatible local provider, with game-aware tools and state kept separate from the reusable protocol code in `aqua/ai/openai`.

Also provide an offline Needle command router that turns one natural-language palette query into one explicitly confirmed, allowlisted game command.

## User Experience

- The player opens AI chat from the global command palette without leaving the current screen.
- The chat shows user messages, assistant replies, tool activity, request status, and recoverable errors.
- Assistant text appears as it is generated. While a request is active, the player can click Stop or press Escape to cancel it without losing already displayed text.
- The assistant can use one Lua evaluation tool to inspect or operate on the running game when answering a request.
- Closing and reopening the window preserves the current conversation; an explicit clear action starts a new conversation.
- The player selects `Needle` in the command palette, types a query, watches a function call update after a short debounce, and presses Enter to run that exact call.

## Architecture Decisions

- `ChatModel` owns conversation state, busy/error state, history limits, and asynchronous calls into the common agent loop.
- The system prompt is stored in `SystemPrompt.md` and loaded as a runtime asset so prompt changes do not require editing Lua source. Its `{{brand_name}}` placeholder resolves from `brand.lua`.
- The game-wide `rizu.net.NetworkService` supplies the HTTP request function. AI traffic does not create another scheduler and must not block frame updates while waiting for the configured provider.
- `LuaEvalTool` is project-specific because its evaluation environment exposes the current `sphere.GameController` as `game`.
- `LuaEvalTool` implements both the OpenAI function-tool shape and the native `mcp.Tool` metadata used by `aqua/mcp`, keeping evaluation policy and behavior in one game-owned implementation.
- The development MCP surface also provides `RuntimeStateTool` for structured read-only screen, selection, and preview observations, `ScreenshotTool` for asynchronous PNG image content, and `RestartTool` for requesting a LÖVE-managed process restart. These focused tools are preferred over Lua evaluation when they cover the workflow.
- Lua evaluation inherits the process-wide globals through `__index = _G`. Per-call `game`, `_G`, and captured `print` entries override that fallback, while ordinary global assignments remain local to the evaluation environment.
- The configured provider uses the OpenAI-compatible `/v1/chat/completions` endpoint and streams assistant text through server-sent events.
- Provider endpoint, API key, and model are configured only in ignored `userdata/ai.lua`. Tracked configuration does not select a provider or model.
- The retained UI window belongs in `yi`; it observes `ChatModel` and contains no API or evaluation logic.
- The provider does not advertise developer-role support, so project instructions use a `system` message.
- `NeedleModel` owns debounce, request generations, streamed proposal text, parsing, and execution gating. `NeedleWorker` owns the native context on a managed LÖVE thread.
- `NeedleToolRegistry` snapshots only the approved semantic tools for the active command contexts and maps them back to existing command callbacks on the main thread.
- The worker asks Needle to route across a compact active tool snapshot containing tool names and short routing descriptions only, then performs final argument generation with only the model-selected full schema. Query text is never interpreted with keyword lists, regular expressions, or other deterministic routing and argument-extraction heuristics.
- Worker terminal events carry queue, routing/final prefill, decode, encoder-layer progress, and total timings. `NeedleModel.telemetry` exposes only the current request's measurements.
- `NeedleGpuProbe` is an opt-in palette diagnostic which verifies GLSL 4 support, shader-storage capacity, Q8 packed-weight compute, and async readback before any GPU inference path is enabled.
- `NeedleGpuEncoderProbe` is a separate opt-in diagnostic. It uploads one real Q8 encoder self-attention layer, computes Q/K/V, RMSNorm/RoPE, score matrix, softmax/value, and output projection on the main-thread graphics queue, then compares its asynchronous readback with the C runtime. It is not used by live Needle inference yet; current Intel/Vulkan measurements make a one-layer GPU prefill slower than the optimized CPU path, so GPU work remains diagnostic until it can retain buffers and beat CPU end-to-end.
- Model prompts use Needle's training-time flat `parameters` format, including per-argument `required` flags and descriptions. The registry retains a separate JSON Schema-shaped representation for strict main-thread validation; model-facing schemas are never trusted as validation state.
- Needle accepts exactly one call shaped as `[{"name": ..., "arguments": {...}}]`; generated names and arguments are validated again after constrained decoding.

## Invariants

- Only one chat request may be in flight at a time.
- Streaming text updates one in-progress assistant transcript entry rather than creating one entry per token.
- Canceling closes the active HTTP stream, removes incomplete protocol messages from API history, preserves partial text in the visible transcript, and returns the model to idle state.
- A request retains the user message, assistant tool-call message, matching tool results, and final assistant response in protocol order.
- Conversation trimming removes complete old turns and always preserves the system message.
- Lua bytecode is rejected, output is size-bounded, and syntax/runtime failures are returned as tool results.
- Lua evaluation reports an explicit MCP execution-error flag in addition to its JSON result, while the OpenAI agent continues to consume the same result text.
- The Lua tool is a trusted developer capability, not a security sandbox. It exposes the process globals and the `game` object, including state-changing and process-level APIs.
- The API key must not be committed to the repository or printed in diagnostics.
- Opening AI chat and opening the command palette are mutually exclusive so only one overlay owns keyboard input.
- Native Needle inference never runs on the render thread, and output from superseded request IDs never becomes executable.
- Enter executes only a complete proposal produced for the byte-identical current query. Needle has no access to Lua evaluation, arbitrary commands, conversation history, or the `game` object.
- Superseded prefill is cooperatively cancelled between encoder layers. A currently executing layer may finish, but decoding and later layers never run for that request.
- GPU diagnostics never run native inference on the graphics thread. Their short CPU reference call is diagnostic-only; a future GPU inference backend must retain model buffers across requests and must not make that reference call.

## Future Work and Open Questions

- Add explicit approval UI before state-changing tools when the agent is exposed beyond trusted local use.
- If prompts become untrusted, run Lua evaluation behind a non-bypassable execution timeout or instruction limit, preferably outside the main game thread.
- If full process access becomes undesirable, replace `__index = _G` with an explicit global allowlist and expose narrower game inspection and command APIs.
- Consider memory limits and stronger output/result serialization bounds for adversarial evaluations.
- Add model/provider selection to retained settings.
- Replace unrestricted game-object access with narrower read and command tools as useful workflows become clear.
- Continue Needle runtime work by borrowing non-threading Cactus ideas first: blocked attention, FP16 scratch evaluation, fused/layout-aware kernels, and persistent execution metadata. Threading remains a later architectural decision because the embedded runtime currently documents single-threaded ownership.
