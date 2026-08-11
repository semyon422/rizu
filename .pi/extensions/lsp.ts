import { randomUUID } from "node:crypto";
import net from "node:net";
import path from "node:path";
import { StringEnum } from "@earendil-works/pi-ai";
import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	formatSize,
	truncateHead,
	type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const operations = [
	"diagnostics",
	"code_actions",
	"apply_code_action",
	"hover",
	"definition",
	"references",
	"symbols",
	"prepare_rename",
	"apply_workspace_edit",
	"status",
	"restart",
] as const;

interface BridgeResponse {
	id: string | null;
	result?: unknown;
	error?: { code: string; message: string };
}

function callBridge(
	socketPath: string,
	method: string,
	params: Record<string, unknown>,
	signal?: AbortSignal,
): Promise<unknown> {
	return new Promise((resolve, reject) => {
		const id = randomUUID();
		const socket = net.createConnection(socketPath);
		let input = "";
		let settled = false;
		const timeout = setTimeout(() => finish(new Error("VS Code LSP bridge timed out after 30 seconds")), 30_000);

		function finish(error?: Error, result?: unknown) {
			if (settled) return;
			settled = true;
			clearTimeout(timeout);
			signal?.removeEventListener("abort", abort);
			socket.destroy();
			if (error) reject(error);
			else resolve(result);
		}

		function abort() {
			finish(new Error("LSP request cancelled"));
		}

		signal?.addEventListener("abort", abort, { once: true });
		if (signal?.aborted) return abort();

		socket.setEncoding("utf8");
		socket.on("connect", () => {
			socket.write(`${JSON.stringify({ id, method, params })}\n`);
		});
		socket.on("data", (chunk) => {
			input += chunk;
			if (Buffer.byteLength(input) > 5 * 1024 * 1024) {
				finish(new Error("VS Code LSP bridge response exceeded 5 MiB"));
				return;
			}
			const newline = input.indexOf("\n");
			if (newline < 0) return;
			try {
				const response = JSON.parse(input.slice(0, newline)) as BridgeResponse;
				if (response.id !== id) throw new Error("VS Code LSP bridge returned a mismatched request ID");
				if (response.error) throw new Error(`${response.error.code}: ${response.error.message}`);
				finish(undefined, response.result);
			} catch (error) {
				finish(error instanceof Error ? error : new Error(String(error)));
			}
		});
		socket.on("error", (error: NodeJS.ErrnoException) => {
			if (error.code === "ENOENT" || error.code === "ECONNREFUSED") {
				finish(new Error(
					`VS Code LSP bridge is unavailable at ${socketPath}. ` +
					"Install tools/pi-lsp/vscode/install.sh and run 'Developer: Reload Window' in VS Code.",
				));
				return;
			}
			finish(error);
		});
		socket.on("end", () => {
			if (!settled && !input.includes("\n")) finish(new Error("VS Code LSP bridge closed without a response"));
		});
	});
}

function requiredString(value: string | undefined, name: string): string {
	if (!value) throw new Error(`${name} is required for this LSP operation`);
	return value.replace(/^@/, "");
}

function requiredPosition(line: number | undefined, character: number | undefined) {
	if (!Number.isInteger(line) || line! < 1 || !Number.isInteger(character) || character! < 1) {
		throw new Error("line and character must be positive, one-based integers for this LSP operation");
	}
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "lsp",
		label: "LSP",
		description:
			"Inspect VS Code language diagnostics and semantic information, preview/apply provider code actions or renames, and inspect/restart LuaLS. " +
			"Positions are one-based. Mutation operations require a preview ID returned by code_actions or prepare_rename.",
		promptSnippet: "Inspect VS Code language diagnostics, navigation, code actions, renames, and LuaLS status",
		promptGuidelines: [
			"Use lsp diagnostics after editing Lua files when semantic LuaLS validation is useful.",
			"Use lsp code_actions or prepare_rename to preview changes before calling their corresponding apply operation.",
		],
		parameters: Type.Object({
			operation: StringEnum(operations, { description: "Language-service operation" }),
			path: Type.Optional(Type.String({ description: "Workspace-relative file path" })),
			line: Type.Optional(Type.Integer({ minimum: 1, description: "One-based start line" })),
			character: Type.Optional(Type.Integer({ minimum: 1, description: "One-based start character" })),
			endLine: Type.Optional(Type.Integer({ minimum: 1, description: "One-based end line for a range" })),
			endCharacter: Type.Optional(Type.Integer({ minimum: 1, description: "One-based end character for a range" })),
			severity: Type.Optional(Type.Array(StringEnum(["error", "warning", "information", "hint"] as const))),
			source: Type.Optional(Type.String({ description: "Diagnostic source filter, such as Lua Diagnostics" })),
			query: Type.Optional(Type.String({ description: "Workspace symbol query" })),
			limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 2000 })),
			includeDeclaration: Type.Optional(Type.Boolean()),
			newName: Type.Optional(Type.String({ description: "New symbol name for prepare_rename" })),
			id: Type.Optional(Type.String({ description: "Opaque preview ID to apply" })),
		}),
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const methodByOperation: Record<(typeof operations)[number], string> = {
				diagnostics: "diagnostics",
				code_actions: "codeActions",
				apply_code_action: "applyCodeAction",
				hover: "hover",
				definition: "definition",
				references: "references",
				symbols: "symbols",
				prepare_rename: "prepareRename",
				apply_workspace_edit: "applyWorkspaceEdit",
				status: "status",
				restart: "restartLuaServer",
			};
			const needsPath = ["code_actions", "hover", "definition", "references", "prepare_rename"];
			const needsPosition = ["code_actions", "hover", "definition", "references", "prepare_rename"];
			if (needsPath.includes(params.operation)) requiredString(params.path, "path");
			if (needsPosition.includes(params.operation)) requiredPosition(params.line, params.character);
			if (params.operation === "symbols" && !params.path && !params.query) {
				throw new Error("symbols requires path for document symbols or query for workspace symbols");
			}
			if (params.operation === "prepare_rename") requiredString(params.newName, "newName");
			if (params.operation === "apply_code_action" || params.operation === "apply_workspace_edit") {
				requiredString(params.id, "id");
			}

			onUpdate?.({ content: [{ type: "text", text: `Waiting for VS Code: ${params.operation}…` }] });
			const socketPath = path.join(ctx.cwd, ".pi", "lsp-bridge.sock");
			const requestParams = { ...params, path: params.path?.replace(/^@/, ""), workspace: ctx.cwd };
			delete (requestParams as { operation?: string }).operation;
			const result = await callBridge(socketPath, methodByOperation[params.operation], requestParams, signal);
			const serialized = JSON.stringify(result, null, 2);
			const truncation = truncateHead(serialized, { maxBytes: DEFAULT_MAX_BYTES, maxLines: DEFAULT_MAX_LINES });
			let text = truncation.content;
			if (truncation.truncated) {
				text += `\n\n[Output truncated to ${formatSize(truncation.outputBytes)} and ${truncation.outputLines} lines.]`;
			}
			return { content: [{ type: "text", text }], details: result };
		},
	});
}
