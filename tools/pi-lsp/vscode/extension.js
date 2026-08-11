'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const vscode = require('vscode');

const MAX_REQUEST_BYTES = 1024 * 1024;
const DEFAULT_LIMIT = 500;
const CACHE_TTL_MS = 2 * 60 * 1000;

/** @type {Map<string, {expires: number, value: unknown}>} */
const cache = new Map();
/** @type {Map<string, {server: import('node:net').Server, socketPath: string}>} */
const servers = new Map();

function cacheValue(value) {
	const id = crypto.randomUUID();
	cache.set(id, { expires: Date.now() + CACHE_TTL_MS, value });
	return id;
}

function takeCached(id) {
	const entry = cache.get(id);
	cache.delete(id);
	if (!entry || entry.expires < Date.now()) {
		throw rpcError('expired_preview', `Preview ${id} is missing, expired, or already applied`);
	}
	return entry.value;
}

function rpcError(code, message) {
	const error = new Error(message);
	error.code = code;
	return error;
}

function workspaceForRequest(params) {
	const requested = params && typeof params.workspace === 'string' ? params.workspace : undefined;
	const folders = vscode.workspace.workspaceFolders || [];
	if (requested) {
		const resolved = path.resolve(requested);
		const folder = folders.find((item) => path.resolve(item.uri.fsPath) === resolved);
		if (!folder) throw rpcError('invalid_workspace', `No open workspace folder matches ${requested}`);
		return folder;
	}
	if (folders.length === 1) return folders[0];
	throw rpcError('workspace_required', 'The workspace parameter is required when VS Code has multiple workspace folders');
}

function resolveUri(folder, filePath) {
	if (typeof filePath !== 'string' || filePath.length === 0) {
		throw rpcError('invalid_path', 'path must be a non-empty string');
	}
	const root = path.resolve(folder.uri.fsPath);
	const absolute = path.resolve(root, filePath.replace(/^@/, ''));
	const relative = path.relative(root, absolute);
	if (relative.startsWith('..') || path.isAbsolute(relative)) {
		throw rpcError('path_outside_workspace', `${filePath} is outside ${root}`);
	}
	return vscode.Uri.file(absolute);
}

function relativePath(folder, uri) {
	const relative = path.relative(folder.uri.fsPath, uri.fsPath);
	return relative || path.basename(uri.fsPath);
}

function position(line, character) {
	if (!Number.isInteger(line) || line < 1 || !Number.isInteger(character) || character < 1) {
		throw rpcError('invalid_position', 'line and character must be positive integers');
	}
	return new vscode.Position(line - 1, character - 1);
}

function requestRange(params) {
	const start = position(params.line, params.character);
	const end = params.endLine === undefined
		? start
		: position(params.endLine, params.endCharacter);
	return new vscode.Range(start, end);
}

function serializePosition(value) {
	return { line: value.line + 1, character: value.character + 1 };
}

function serializeRange(value) {
	return { start: serializePosition(value.start), end: serializePosition(value.end) };
}

function serializeLocation(folder, value) {
	if (value.targetUri) {
		return {
			path: relativePath(folder, value.targetUri),
			range: serializeRange(value.targetSelectionRange),
			targetRange: serializeRange(value.targetRange),
		};
	}
	return { path: relativePath(folder, value.uri), range: serializeRange(value.range) };
}

function diagnosticSeverity(value) {
	return ['error', 'warning', 'information', 'hint'][value] || 'unknown';
}

function diagnosticKey(value) {
	return `${value.source || ''}:${value.code || ''}:${value.range.start.line}:${value.range.start.character}:${value.message}`;
}

function serializeDiagnostic(value) {
	return {
		severity: diagnosticSeverity(value.severity),
		message: value.message,
		range: serializeRange(value.range),
		source: value.source,
		code: typeof value.code === 'object' ? value.code.value : value.code,
		tags: value.tags,
	};
}

function markdownText(content) {
	if (typeof content === 'string') return content;
	if (content && typeof content.value === 'string') return content.value;
	if (content && typeof content.language === 'string') return `\`\`\`${content.language}\n${content.value}\n\`\`\``;
	return String(content);
}

function serializeWorkspaceEdit(folder, edit) {
	const changes = [];
	for (const [uri, edits] of edit.entries()) {
		changes.push({
			path: relativePath(folder, uri),
			edits: edits.map((item) => ({ range: serializeRange(item.range), newText: item.newText })),
		});
	}
	return changes;
}

function serializeSymbol(folder, value) {
	if (value.location) {
		return {
			name: value.name,
			kind: vscode.SymbolKind[value.kind],
			containerName: value.containerName,
			location: serializeLocation(folder, value.location),
		};
	}
	return {
		name: value.name,
		kind: vscode.SymbolKind[value.kind],
		detail: value.detail,
		range: serializeRange(value.range),
		selectionRange: serializeRange(value.selectionRange),
		children: (value.children || []).map((item) => serializeSymbol(folder, item)),
	};
}

async function diagnostics(folder, params) {
	const requestedUri = params.path ? resolveUri(folder, params.path) : undefined;
	const severity = params.severity ? new Set([].concat(params.severity)) : undefined;
	const source = typeof params.source === 'string' ? params.source : undefined;
	const limit = Math.min(Math.max(params.limit || DEFAULT_LIMIT, 1), 2000);
	const groups = [];
	let matched = 0;
	const sourceDiagnostics = requestedUri
		? [[requestedUri, vscode.languages.getDiagnostics(requestedUri)]]
		: vscode.languages.getDiagnostics();
	for (const [uri, values] of sourceDiagnostics) {
		if (uri.scheme !== 'file') continue;
		const relative = path.relative(folder.uri.fsPath, uri.fsPath);
		if (relative.startsWith('..') || path.isAbsolute(relative)) continue;
		const selected = values.filter((value) => {
			return (!severity || severity.has(diagnosticSeverity(value.severity))) && (!source || value.source === source);
		});
		if (!selected.length) continue;
		const remaining = Math.max(limit - matched, 0);
		const items = selected.slice(0, remaining).map(serializeDiagnostic);
		matched += selected.length;
		if (items.length) groups.push({ path: relativePath(folder, uri), diagnostics: items });
	}
	return { workspace: folder.uri.fsPath, total: Math.min(matched, limit), matched, truncated: matched > limit, files: groups };
}

async function codeActions(folder, params) {
	const uri = resolveUri(folder, params.path);
	await vscode.workspace.openTextDocument(uri);
	const range = requestRange(params);
	const actions = await vscode.commands.executeCommand('vscode.executeCodeActionProvider', uri, range, '', 100) || [];
	return {
		path: relativePath(folder, uri),
		actions: actions.map((action) => {
			const id = cacheValue({ kind: 'codeAction', folder: folder.uri.fsPath, action });
			return {
				id,
				title: action.title,
				kind: action.kind && action.kind.value,
				preferred: action.isPreferred,
				disabled: action.disabled && action.disabled.reason,
				diagnostics: (action.diagnostics || []).map(diagnosticKey),
				edit: action.edit ? serializeWorkspaceEdit(folder, action.edit) : undefined,
				command: typeof action.command === 'string'
					? { command: action.command, title: action.title }
					: action.command && { command: action.command.command, title: action.command.title },
			};
		}),
	};
}

async function saveWorkspaceEditDocuments(edit) {
	const openDocuments = new Map(vscode.workspace.textDocuments.map((document) => [document.uri.toString(), document]));
	for (const [uri] of edit.entries()) {
		const document = openDocuments.get(uri.toString());
		if (document && document.isDirty && !(await document.save())) {
			throw rpcError('save_failed', `Could not save ${uri.fsPath}`);
		}
	}
}

async function applyCodeAction(folder, params) {
	const cached = takeCached(params.id);
	if (!cached || cached.kind !== 'codeAction' || cached.folder !== folder.uri.fsPath) {
		throw rpcError('invalid_preview', 'The preview is not a code action for this workspace');
	}
	const action = cached.action;
	if (action.disabled) throw rpcError('action_disabled', action.disabled.reason);
	if (action.edit) {
		if (!(await vscode.workspace.applyEdit(action.edit))) {
			throw rpcError('apply_failed', 'VS Code rejected the workspace edit');
		}
		await saveWorkspaceEditDocuments(action.edit);
	}
	if (typeof action.command === 'string') {
		await vscode.commands.executeCommand(action.command, ...(action.arguments || []));
	} else if (action.command) {
		await vscode.commands.executeCommand(action.command.command, ...(action.command.arguments || []));
	}
	return { applied: true, title: action.title };
}

async function hover(folder, params) {
	const uri = resolveUri(folder, params.path);
	const values = await vscode.commands.executeCommand('vscode.executeHoverProvider', uri, position(params.line, params.character)) || [];
	return { path: relativePath(folder, uri), hovers: values.map((item) => ({ contents: item.contents.map(markdownText), range: item.range && serializeRange(item.range) })) };
}

async function locations(folder, params, command) {
	const uri = resolveUri(folder, params.path);
	const args = [uri, position(params.line, params.character)];
	if (command === 'vscode.executeReferenceProvider') args.push({ includeDeclaration: params.includeDeclaration !== false });
	const values = await vscode.commands.executeCommand(command, ...args) || [];
	const limit = Math.min(Math.max(params.limit || DEFAULT_LIMIT, 1), 2000);
	return {
		path: relativePath(folder, uri),
		total: Math.min(values.length, limit),
		matched: values.length,
		truncated: values.length > limit,
		locations: values.slice(0, limit).map((item) => serializeLocation(folder, item)),
	};
}

async function symbols(folder, params) {
	if (params.path) {
		const uri = resolveUri(folder, params.path);
		const values = await vscode.commands.executeCommand('vscode.executeDocumentSymbolProvider', uri) || [];
		const limit = Math.min(Math.max(params.limit || DEFAULT_LIMIT, 1), 2000);
		return {
			path: relativePath(folder, uri),
			total: Math.min(values.length, limit),
			matched: values.length,
			truncated: values.length > limit,
			symbols: values.slice(0, limit).map((item) => serializeSymbol(folder, item)),
		};
	}
	if (typeof params.query !== 'string' || !params.query) throw rpcError('invalid_query', 'query is required for workspace symbols');
	const values = await vscode.commands.executeCommand('vscode.executeWorkspaceSymbolProvider', params.query) || [];
	return { query: params.query, symbols: values.slice(0, params.limit || DEFAULT_LIMIT).map((item) => serializeSymbol(folder, item)) };
}

async function prepareRename(folder, params) {
	const uri = resolveUri(folder, params.path);
	await vscode.workspace.openTextDocument(uri);
	const edit = await vscode.commands.executeCommand('vscode.executeDocumentRenameProvider', uri, position(params.line, params.character), params.newName);
	if (!edit) throw rpcError('rename_unavailable', 'No rename edit was returned at this position');
	const id = cacheValue({ kind: 'workspaceEdit', folder: folder.uri.fsPath, edit });
	return { id, newName: params.newName, changes: serializeWorkspaceEdit(folder, edit) };
}

async function applyWorkspaceEdit(folder, params) {
	const cached = takeCached(params.id);
	if (!cached || cached.kind !== 'workspaceEdit' || cached.folder !== folder.uri.fsPath) {
		throw rpcError('invalid_preview', 'The preview is not a workspace edit for this workspace');
	}
	if (!(await vscode.workspace.applyEdit(cached.edit))) throw rpcError('apply_failed', 'VS Code rejected the workspace edit');
	await saveWorkspaceEditDocuments(cached.edit);
	return { applied: true };
}

async function status(folder) {
	const lua = vscode.extensions.getExtension('sumneko.lua');
	const commands = new Set(await vscode.commands.getCommands(true));
	return {
		workspace: folder.uri.fsPath,
		bridge: 'ready',
		luaExtension: lua ? { installed: true, active: lua.isActive, version: lua.packageJSON.version } : { installed: false },
		lifecycleCommands: { start: commands.has('lua.startServer'), stop: commands.has('lua.stopServer') },
		diagnosticCount: vscode.languages.getDiagnostics().reduce((count, [, values]) => count + values.length, 0),
	};
}

async function restartLuaServer(folder) {
	const lua = vscode.extensions.getExtension('sumneko.lua');
	if (!lua) throw rpcError('lua_extension_missing', 'The sumneko.lua VS Code extension is not installed');
	await lua.activate();
	const commands = new Set(await vscode.commands.getCommands(true));
	if (!commands.has('lua.stopServer') || !commands.has('lua.startServer')) {
		throw rpcError('lifecycle_unavailable', 'The Lua extension does not expose lua.stopServer and lua.startServer');
	}
	await vscode.commands.executeCommand('lua.stopServer');
	await vscode.commands.executeCommand('lua.startServer');
	return { restarted: true, workspace: folder.uri.fsPath };
}

async function dispatch(request) {
	if (!request || typeof request !== 'object' || typeof request.method !== 'string') {
		throw rpcError('invalid_request', 'Expected an object with a method');
	}
	const params = request.params && typeof request.params === 'object' ? request.params : {};
	const folder = workspaceForRequest(params);
	switch (request.method) {
		case 'diagnostics': return diagnostics(folder, params);
		case 'codeActions': return codeActions(folder, params);
		case 'applyCodeAction': return applyCodeAction(folder, params);
		case 'hover': return hover(folder, params);
		case 'definition': return locations(folder, params, 'vscode.executeDefinitionProvider');
		case 'references': return locations(folder, params, 'vscode.executeReferenceProvider');
		case 'symbols': return symbols(folder, params);
		case 'prepareRename': return prepareRename(folder, params);
		case 'applyWorkspaceEdit': return applyWorkspaceEdit(folder, params);
		case 'status': return status(folder);
		case 'restartLuaServer': return restartLuaServer(folder);
		default: throw rpcError('method_not_found', `Unknown method: ${request.method}`);
	}
}

function startServer(folder, context) {
	const socketPath = path.join(folder.uri.fsPath, '.pi', 'lsp-bridge.sock');
	fs.mkdirSync(path.dirname(socketPath), { recursive: true });
	try { fs.unlinkSync(socketPath); } catch (error) { if (error.code !== 'ENOENT') throw error; }
	const server = net.createServer((connection) => {
		let input = '';
		let bytes = 0;
		connection.setEncoding('utf8');
		connection.on('data', (chunk) => {
			bytes += Buffer.byteLength(chunk);
			if (bytes > MAX_REQUEST_BYTES) {
				connection.destroy(rpcError('request_too_large', 'Request exceeds 1 MiB'));
				return;
			}
			input += chunk;
			const newline = input.indexOf('\n');
			if (newline < 0) return;
			connection.pause();
			let request;
			try { request = JSON.parse(input.slice(0, newline)); }
			catch (error) {
				connection.end(`${JSON.stringify({ id: null, error: { code: 'parse_error', message: error.message } })}\n`);
				return;
			}
			dispatch(request).then(
				(result) => connection.end(`${JSON.stringify({ id: request.id, result })}\n`),
				(error) => connection.end(`${JSON.stringify({ id: request.id, error: { code: error.code || 'internal_error', message: error.message } })}\n`),
			);
		});
	});
	server.on('error', (error) => console.error(`[Pi LSP Bridge] ${socketPath}:`, error));
	server.listen(socketPath, () => fs.chmodSync(socketPath, 0o600));
	servers.set(folder.uri.fsPath, { server, socketPath });
	context.subscriptions.push({ dispose: () => stopServer(folder.uri.fsPath) });
}

function stopServer(workspacePath) {
	const entry = servers.get(workspacePath);
	if (!entry) return;
	servers.delete(workspacePath);
	entry.server.close();
	try { fs.unlinkSync(entry.socketPath); } catch (error) { if (error.code !== 'ENOENT') console.error(error); }
}

function activate(context) {
	for (const folder of vscode.workspace.workspaceFolders || []) startServer(folder, context);
	context.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders((event) => {
		for (const folder of event.removed) stopServer(folder.uri.fsPath);
		for (const folder of event.added) startServer(folder, context);
	}));
	context.subscriptions.push(vscode.commands.registerCommand('piLspBridge.restart', () => {
		for (const folder of vscode.workspace.workspaceFolders || []) {
			stopServer(folder.uri.fsPath);
			startServer(folder, context);
		}
		vscode.window.showInformationMessage('Pi LSP Bridge restarted');
	}));
}

function deactivate() {
	for (const workspacePath of [...servers.keys()]) stopServer(workspacePath);
}

module.exports = { activate, deactivate };
