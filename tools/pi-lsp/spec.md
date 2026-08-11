## Goal

Expose the language services already running in VS Code to a project-local Pi agent without starting a second language-server process.

## User Experience

With the `rizu.rizu-pi-lsp-bridge` VS Code extension installed and this workspace open, Pi gets an `lsp` tool. The agent can:

- list VS Code diagnostics for the workspace or one file,
- aggregate diagnostics by code, source, top-level directory, and file,
- preview document formatting edits and apply them through the workspace-edit operation,
- inspect and apply code actions,
- request hover, definitions, references, and symbols,
- preview and apply rename edits,
- inspect bridge/Lua extension status, and
- restart the Lua language server.

The bridge is project-local. If VS Code or the bridge is unavailable, the tool reports a connection error and installation guidance rather than starting a separate LuaLS instance.

## Architecture Decisions

### VS Code owns language-server state

The VS Code extension calls the public `vscode.languages` and `vscode.execute*Provider` APIs. Pi therefore sees the same diagnostics and provider results as the editor. It does not speak LSP directly and does not launch LuaLS.

### Local Unix socket transport

Each open workspace folder gets `.pi/lsp-bridge.sock`. Requests and responses are newline-delimited JSON objects:

```text
{"id":"...","method":"diagnostics","params":{...}}
{"id":"...","result":{...}}
```

Errors use `{"id":"...","error":{"code":"...","message":"..."}}`. The socket is mode `0600`, accepts one request per connection, limits request size, and only resolves file paths inside its workspace folder.

### Mutations require two steps

Code actions and rename edits are first returned as previews with opaque, short-lived IDs. A separate apply request performs the mutation. This prevents an inspection request from changing files and gives the agent a chance to report the intended change.

### LuaLS lifecycle uses contributed commands

The bridge activates `sumneko.lua` and invokes its public `lua.stopServer` and `lua.startServer` commands. Status can prove that the extension and lifecycle commands are available, but VS Code exposes no public API for the LuaLS process state itself.

## Invariants

- VS Code is the sole owner of the bridged language-server process.
- Paths supplied by Pi cannot escape the workspace folder.
- Protocol positions are one-based for agent readability; VS Code positions are converted at the boundary.
- Diagnostic and navigation responses are bounded before entering model context.
- Cached code actions and workspace edits expire and cannot be applied more than once.
- Bridge shutdown removes only the socket created by that bridge instance.

## Future Work and Open Questions

- Add Windows named-pipe transport if this adapter is promoted beyond the current Linux project setup.
- Support multi-root selection from Pi when Pi's working directory is above several workspace folders.
- Consider diagnostic change notifications so Pi can react without polling.
- Package and publish both halves after the project-local workflow is validated.
