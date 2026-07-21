## Goal

Provide an in-game AI chat backed by either an OpenAI-compatible local provider or an OpenAI subscription login, with game-aware tools and state kept separate from the reusable protocol code in `aqua/ai/openai`.

Also provide an offline Needle command router that turns one natural-language palette query into one explicitly confirmed, allowlisted game command.

## User Experience

- The player opens AI chat from the global command palette without leaving the current screen.
- When the selected provider has `type = "openai_subscription"`, the chat header offers an OpenAI login button. It opens the system browser and completes through a loopback callback; the player returns to the game after authorizing the account.
- The chat header shows the active provider and model. Clicking it opens a scrollable selector containing every configured provider/model pair; selecting one starts a fresh conversation with that backend.
- The chat shows user messages, assistant replies, tool activity, request status, and recoverable errors.
- Assistant text appears as it is generated. While a request is active, the player can click Stop or press Escape to cancel it without losing already displayed text.
- The assistant can use one Lua evaluation tool to inspect or operate on the running game when answering a request.
- The assistant can map runtime functions to repository source locations and read source ranges without using arbitrary Lua evaluation.
- The assistant can search mounted source files, inspect structured runtime values, and review recent failed tool calls without arbitrary Lua evaluation.
- Closing and reopening the window preserves the current conversation; an explicit clear action starts a new conversation.
- The player selects `Needle` in the command palette, types a query, watches a function call update after a short debounce, and presses Enter to run that exact call.

## Architecture Decisions

- `ChatModel` owns conversation state, busy/error state, history limits, and asynchronous calls into the common agent loop.
- The system prompt is stored in `SystemPrompt.md` and loaded as a runtime asset so prompt changes do not require editing Lua source. Its `{{brand_name}}` placeholder resolves from `brand.lua`.
- The game-wide `rizu.net.NetworkService` supplies the HTTP request function. AI traffic does not create another scheduler and must not block frame updates while waiting for the configured provider.
- `LuaEvalTool` is project-specific because its evaluation environment exposes the current `sphere.GameController` as `game`.
- `SourceLocationTool` resolves dot-separated paths rooted at `game` through `debug.getinfo`, including underscore-prefixed implementation functions. `ReadFileTool` reads numbered ranges from any file available through an injected `fs.IFilesystem` and validates returned text as UTF-8.
- `SearchSourceTool` recursively searches either filenames or plain-text content through the same injected `fs.IFilesystem`. Calls select case sensitivity and bound scanned files plus returned matches so work and results remain suitable for the render-thread agent.
- `InspectRuntimeTool` traverses dot-separated paths rooted at `game` and serializes values, table fields, metatables, cycles, and function source locations. Calls explicitly bound nested depth and total table fields.
- `ToolFailureLog` retains the latest 100 failures from both surfaces in memory. `GetToolFailuresTool` returns filtered entries newest first; failures remain visible in the console as structured JSON lines.
- Source search, source reading, source location, runtime inspection, failure retrieval, and Lua evaluation are shared by the in-game OpenAI agent and development MCP server so both surfaces observe the same diagnostic workflow.
- Failed OpenAI-agent and MCP tool calls invoke application-owned logging with the surface, tool name, arguments, and error. Failures include dispatch/schema errors, execution exceptions, and explicit tool error results.
- `LuaEvalTool` implements both the OpenAI function-tool shape and the native `mcp.Tool` metadata used by `aqua/mcp`, keeping evaluation policy and behavior in one game-owned implementation.
- The development MCP surface also provides `RuntimeStateTool` for structured read-only screen, selection, and preview observations, `ScreenshotTool` for asynchronous PNG image content, and `RestartTool` for requesting a LÖVE-managed process restart. These focused tools are preferred over Lua evaluation when they cover the workflow.
- Lua evaluation inherits the process-wide globals through `__index = _G`. Per-call `game`, `_G`, and captured `print` entries override that fallback, while ordinary global assignments remain local to the evaluation environment.
- The configured provider uses the OpenAI-compatible `/v1/chat/completions` endpoint and streams assistant text through server-sent events.
- `openai_subscription` is an isolated compatibility connector for the same OAuth and ChatGPT Codex Responses flow used by PI. It uses authorization-code PKCE, validates the callback state, binds the callback server to loopback only, refreshes expired access tokens, and supplies the ChatGPT account ID required by the Responses backend.
- Subscription Responses are translated by reusable `aqua/ai/openai/SubscriptionClient.lua`: system messages become instructions, existing chat/tool messages become Responses input items, and completed provider output items are retained verbatim. Retaining encrypted reasoning items is required for a valid continuation across tool rounds.
- The subscription connector uses the game-wide `NetworkService` for token and inference requests, so its traffic follows the same proxy policy and non-blocking scheduler as other game network traffic.
- OAuth credentials are stored in ignored `userdata/ai_auth.lua`. The tracked config contains only an empty credential shape; access and refresh tokens must never be committed or logged.
- ChatGPT subscription access and API-key access are separate provider contracts. The normal `openai_compatible` client remains available for local Qwen and public API endpoints and never reads subscription credentials.
- `ProviderManager` flattens named provider entries and their ordered model lists into UI choices, constructs and caches the matching protocol clients, owns shared subscription authentication, and persists `active_provider` plus `active_model` after selection.
- Game chat allows up to 50 sequential tool-call rounds before the agent returns a tool-limit error.
- Ignored `userdata/ai.lua` defines a `providers` dictionary. Each named provider has a display name, provider type, ordered `models` list, and its protocol-specific endpoint/auth/generation settings. `active_provider` and `active_model` persist the selector state.
- Legacy single-provider `provider`, `model`, and transport fields are converted in memory when no provider dictionary exists, preserving existing user configurations without rewriting them on load.
- A minimal multi-provider `userdata/ai.lua` has this shape:

```lua
return {
	active_provider = "local_provider",
	active_model = "local-model",
	providers = {
		local_provider = {
			name = "Local",
			type = "openai_compatible",
			models = {"local-model", "another-model"},
			base_url = "http://localhost:28080/v1",
			api_key = "",
			max_tokens = 4096,
			timeout = 300,
		},
		openai = {
			name = "OpenAI",
			type = "openai_subscription",
			models = {"gpt-model"},
			reasoning_effort = "medium",
			timeout = 300,
		},
	},
}
```
- The retained UI window belongs in `yi`; it observes `ChatModel` and contains no API or evaluation logic.
- `AiChatView` caches wrapped transcript lines and invalidates them only on `chat_changed` or width changes. Long tool results must not be rewrapped every rendered frame.
- `AiChatView` validates transcript and input strings before passing them to LÖVE text APIs so malformed tool or clipboard bytes cannot crash rendering.
- The provider does not advertise developer-role support, so project instructions use a `system` message.
- `NeedleModel` owns debounce, request generations, streamed proposal text, parsing, and execution gating. `NeedleWorker` owns the native context on a managed LÖVE thread.
- `NeedleToolRegistry` snapshots only the approved semantic tools for the active command contexts and maps them back to existing command callbacks on the main thread.
- The worker asks Needle to route across a compact active tool snapshot containing tool names and short routing descriptions only, then performs final argument generation with only the model-selected full schema. Query text is never interpreted with keyword lists, regular expressions, or other deterministic routing and argument-extraction heuristics.
- Worker terminal events carry queue, routing/final prefill, decode, encoder-layer progress, and total timings. `NeedleModel.telemetry` exposes only the current request's measurements.
- `NeedleGpuProbe` is an opt-in runtime diagnostic which verifies GLSL 4 support, shader-storage capacity, Q8 packed-weight compute, and async readback before any GPU inference path is enabled. It remains instantiated on the game controller for developer/MCP access, but is not exposed in the player command palette.
- `NeedleGpuEncoderProbe` is a separate opt-in runtime diagnostic. It uploads one real Q8 encoder self-attention layer, computes Q/K/V, RMSNorm/RoPE, score matrix, softmax/value, and output projection on the main-thread graphics queue, then compares its asynchronous readback with the C runtime. It is not exposed in the player command palette and is not used by live Needle inference yet; current Intel/Vulkan measurements make a one-layer GPU prefill slower than the optimized CPU path, so GPU work remains diagnostic until it can retain buffers and beat CPU end-to-end.
- Model prompts use Needle's training-time flat `parameters` format, including per-argument `required` flags and descriptions. The registry retains a separate JSON Schema-shaped representation for strict main-thread validation; model-facing schemas are never trusted as validation state.
- Needle accepts exactly one call shaped as `[{"name": ..., "arguments": {...}}]`; generated names and arguments are validated again after constrained decoding.

## Invariants

- Only one chat request may be in flight at a time.
- Streaming text updates one in-progress assistant transcript entry rather than creating one entry per token.
- Canceling closes the active HTTP stream, removes incomplete protocol messages from API history, preserves partial text in the visible transcript, and returns the model to idle state.
- A failed request preserves its user prompt and every complete assistant tool-call/result group so a later retry or follow-up still has the original context. Only an incomplete trailing protocol group is removed.
- A request retains the user message, assistant tool-call message, matching tool results, and final assistant response in protocol order.
- Conversation trimming removes complete old turns and always preserves the system message.
- Switching provider or model is allowed only while idle and clears both visible and protocol conversation history. Provider-owned Responses reasoning items must never be sent to a different provider or model.
- Lua bytecode is rejected, output is size-bounded, and syntax/runtime failures are returned as tool results.
- Source reads remain repository-relative and character-bounded, but have no root, extension, or line-count allowlist. They are a trusted developer capability and may expose ignored runtime configuration.
- Source search requires an explicit starting path and bounds returned matches, but it does not apply a root or extension allowlist.
- Runtime inspection never evaluates caller-provided Lua code, but table indexing and value formatting may still invoke object metatables in the trusted game process.
- Tool failure history is process-local, bounded, and reset when the game restarts.
- Lua evaluation reports an explicit MCP execution-error flag in addition to its JSON result, while the OpenAI agent continues to consume the same result text.
- The Lua tool is a trusted developer capability, not a security sandbox. It exposes the process globals and the `game` object, including state-changing and process-level APIs.
- The API key must not be committed to the repository or printed in diagnostics.
- OAuth access tokens, refresh tokens, and callback authorization codes must not be printed, exposed in UI errors, or committed. The callback accepts only the active state value and authorization verifier.
- The OAuth client and ChatGPT Codex backend are compatibility surfaces rather than the public OpenAI API contract. Keep them in separate `SubscriptionAuth` and `SubscriptionClient` modules so changes do not regress local or API-key providers.
- Opening AI chat and opening the command palette are mutually exclusive so only one overlay owns keyboard input.
- Native Needle inference never runs on the render thread, and output from superseded request IDs never becomes executable.
- Enter executes only a complete proposal produced for the byte-identical current query. Needle has no access to Lua evaluation, arbitrary commands, conversation history, or the `game` object.
- Superseded prefill is cooperatively cancelled between encoder layers. A currently executing layer may finish, but decoding and later layers never run for that request.
- GPU diagnostics never run native inference on the graphics thread. Their short CPU reference call is diagnostic-only; a future GPU inference backend must retain model buffers across requests and must not make that reference call.

## Future Work and Open Questions

- Validate agent tool arguments against their published schemas before execution, reusing `mcp.JsonSchema`. Prefer strict schemas with complete `required` lists and `additionalProperties = false` where provider capabilities allow it.
- Add tool risk metadata and explicit approval UI before Lua evaluation, restarts, settings changes, file writes, or other state-changing calls. Keep focused read-only inspection automatic.
- Replace character-based history limits with token-aware context accounting. Compact old complete turns into summaries while preserving recent tool groups and every provider-owned Responses item required for stateless reasoning continuity.
- Record request traces containing provider, model, first-token latency, total duration, token usage when reported, tool timings, round count, cancellation, and errors. Make recent traces available to both the UI and diagnostic tools.
- Build a reproducible agent evaluation suite covering source inspection, network requests, malformed tool calls, context preservation, cancellation, provider switching, and tool-choice/final-answer quality across local and subscription models.
- Move potentially expensive source search, large reads, serialization, and evaluation away from the render thread or give them cooperative work and time budgets. If prompts become untrusted, Lua evaluation also needs a non-bypassable instruction or process-level limit.
- Replace unrestricted game-object access with focused tools for screen state, chart and library selection, settings, gameplay state, and approved commands. If full process access becomes undesirable, replace Lua evaluation's `_G` fallback with an explicit allowlist.
- Improve chat interaction with retry/regenerate, edit-and-resend, copy output, collapsible tool results, a context-usage display, and per-model reasoning controls.
- Persist conversations with their provider and model identity. Restore only under a compatible selection, and never replay provider-owned reasoning items into another provider or model.
- Extend provider configuration with explicit capabilities for tools, strict schemas, reasoning, streaming, roles, and image input instead of assuming OpenAI-compatible behavior.
- Add focused screenshot/image input to the in-game agent so it can inspect the current UI without unrestricted runtime evaluation.
- Consider optional automatic routing for simple local requests versus difficult or tool-heavy subscription requests, with a visible override and deterministic policy.
- Consider memory limits and stronger output/result serialization bounds for adversarial evaluations.
- Continue Needle runtime work by borrowing non-threading Cactus ideas first: blocked attention, FP16 scratch evaluation, fused/layout-aware kernels, and persistent execution metadata. Threading remains a later architectural decision because the embedded runtime currently documents single-threaded ownership.
- Use `rizu/ai/benchmarks/needle_routing.lua` to check compact routing prompt latency and tool-selection quality before changing routing descriptions or schema shape. By default it runs route selection and then a selected-schema final generation; set `ROUTE_ONLY=1` to measure routing alone. Keep ambiguous phrases such as bare "random chart" or "search camellia" out of the pass/fail set until the model reliably distinguishes selection, search, and option commands for those phrasings. Some final-generation argument values remain quality gaps (for example vague speed changes and autoplay mode), so only stable argument expectations should be hard failures.
