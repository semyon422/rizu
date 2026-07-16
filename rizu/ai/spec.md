## Goal

Provide an in-game AI chat backed by an OpenAI-compatible local provider, with game-aware tools and state kept separate from the reusable protocol code in `aqua/ai/openai`.

## User Experience

- The player opens AI chat from the global command palette without leaving the current screen.
- The chat shows user messages, assistant replies, tool activity, request status, and recoverable errors.
- Assistant text appears as it is generated. While a request is active, the player can click Stop or press Escape to cancel it without losing already displayed text.
- The assistant can use one Lua evaluation tool to inspect or operate on the running game when answering a request.
- Closing and reopening the window preserves the current conversation; an explicit clear action starts a new conversation.

## Architecture Decisions

- `ChatModel` owns conversation state, busy/error state, history limits, and asynchronous calls into the common agent loop.
- The system prompt is stored in `SystemPrompt.md` and loaded as a runtime asset so prompt changes do not require editing Lua source. Its `{{brand_name}}` placeholder resolves from `brand.lua`.
- The game-wide `rizu.net.NetworkService` supplies the HTTP request function. AI traffic does not create another scheduler and must not block frame updates while waiting for the configured provider.
- `LuaEvalTool` is project-specific because its evaluation environment exposes the current `sphere.GameController` as `game`.
- Lua evaluation inherits the process-wide globals through `__index = _G`. Per-call `game`, `_G`, and captured `print` entries override that fallback, while ordinary global assignments remain local to the evaluation environment.
- The configured provider uses the OpenAI-compatible `/v1/chat/completions` endpoint and streams assistant text through server-sent events.
- Provider endpoint, API key, and model are configured only in ignored `userdata/ai.lua`. Tracked configuration does not select a provider or model.
- The retained UI window belongs in `yi`; it observes `ChatModel` and contains no API or evaluation logic.
- The provider does not advertise developer-role support, so project instructions use a `system` message.

## Invariants

- Only one chat request may be in flight at a time.
- Streaming text updates one in-progress assistant transcript entry rather than creating one entry per token.
- Canceling closes the active HTTP stream, removes incomplete protocol messages from API history, preserves partial text in the visible transcript, and returns the model to idle state.
- A request retains the user message, assistant tool-call message, matching tool results, and final assistant response in protocol order.
- Conversation trimming removes complete old turns and always preserves the system message.
- Lua bytecode is rejected, output is size-bounded, and syntax/runtime failures are returned as tool results.
- The Lua tool is a trusted developer capability, not a security sandbox. It exposes the process globals and the `game` object, including state-changing and process-level APIs.
- The API key must not be committed to the repository or printed in diagnostics.
- Opening AI chat and opening the command palette are mutually exclusive so only one overlay owns keyboard input.

## Future Work and Open Questions

- Add explicit approval UI before state-changing tools when the agent is exposed beyond trusted local use.
- If prompts become untrusted, run Lua evaluation behind a non-bypassable execution timeout or instruction limit, preferably outside the main game thread.
- If full process access becomes undesirable, replace `__index = _G` with an explicit global allowlist and expose narrower game inspection and command APIs.
- Consider memory limits and stronger output/result serialization bounds for adversarial evaluations.
- Add model/provider selection to retained settings.
- Replace unrestricted game-object access with narrower read and command tools as useful workflows become clear.
