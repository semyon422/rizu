import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import { Container, Text } from "@earendil-works/pi-tui";

const TEST_SCRIPT = "./test";

interface TestFileResult {
	path: string;
	tests: number;
	time: number;
}

interface TestError {
	file: string;
	line: number;
	method: string | null;
	detail: string;
}

interface TestResult {
	files: TestFileResult[];
	errors: TestError[];
	total: number;
	fail: number;
}

function formatTime(seconds: number): string {
	if (seconds < 0.001) return `${Math.round(seconds * 1000)}μs`;
	if (seconds < 1) return `${(seconds * 1000).toFixed(1)}ms`;
	return `${seconds.toFixed(3)}s`;
}

function stripAnsi(text: string): string {
	return text.replace(/\x1b\[[0-9;]*m/g, "");
}

function extractJsonResult(output: string): TestResult {
	// The test runner may produce setup noise before the JSON line.
	// Find the last line that is valid JSON.
	const lines = output.split("\n").map((l) => l.trim()).filter(Boolean);
	let jsonLine = "";
	for (const line of lines) {
		if (line.startsWith("{")) {
			try {
				JSON.parse(line);
				jsonLine = line;
			} catch {
				// Not valid JSON, skip
			}
		}
	}
	if (!jsonLine) {
		throw new Error(`no JSON output found in:\n${output.slice(0, 1000)}`);
	}
	return JSON.parse(jsonLine) as TestResult;
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "run_tests",
		label: "Run Tests",
		description: "Run the project test suite. Supports running all tests, tests matching a file pattern, or specific test methods. Returns structured results with pass/fail counts, timing, and error details.",
		promptSnippet: "Run Lua test suite with --json output; returns structured pass/fail results with timing",
		promptGuidelines: [
			"Use run_tests after making code changes to verify nothing broke.",
			"Use run_tests with file_pattern to run focused tests for the changed module.",
			"Use run_tests with method_pattern to run a single test method.",
			"When tests fail, analyze the error details before attempting fixes.",
		],
		parameters: Type.Object({
			file_pattern: Type.Optional(
				Type.String({
					description:
						"File path pattern to match test files. E.g. 'rizu/gameplay' runs all tests under that directory, 'GameplayTimings_test.lua' runs a specific file. Omit to run all tests.",
				}),
			),
			method_pattern: Type.Optional(
				Type.String({
					description:
						"Lua pattern to match test method names within matched files. E.g. 'auto_timings' runs only methods matching that name.",
				}),
			),
			quick: Type.Optional(
				Type.Boolean({
					description:
						"If true, only show a summary (pass/fail counts and timing) without error details. Default: false.",
				}),
			),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const cwd = ctx.cwd;
			const args: string[] = ["--json"];

			if (params.file_pattern) {
				args.push(params.file_pattern);
			}
			if (params.method_pattern) {
				args.push(params.method_pattern);
			}

			let output: string;
			try {
				output = execFileSync(TEST_SCRIPT, args, {
					cwd,
					encoding: "utf-8",
					timeout: 120_000,
				}).trim();
			} catch (error: any) {
				return {
					content: [
						{
							type: "text",
							text: `Error running tests: ${error.message ?? String(error)}`,
						},
					],
					isError: true,
					details: {},
				};
			}

			let result: TestResult;
			try {
				result = extractJsonResult(output);
			} catch (parseError: any) {
				return {
					content: [
						{
							type: "text",
							text: `Failed to parse test output: ${parseError.message}`,
						},
					],
					isError: true,
					details: {},
				};
			}

			const passed = result.total - result.fail;
			const allPassed = result.fail === 0;

			// Collect failed files and methods
			const failedFiles = new Set<string>();
			const failedMethodKeys = new Set<string>();
			for (const err of result.errors) {
				failedFiles.add(err.file);
				if (err.method) {
					failedMethodKeys.add(`${err.file}:${err.method}`);
				}
			}

			// Build summary
			const lines: string[] = [];
			lines.push(
				allPassed
					? `✅ All ${result.total} test(s) passed`
					: `❌ ${result.fail} of ${result.total} test(s) failed`,
			);

			// Failed files and methods summary
			if (failedFiles.size > 0 && !params.quick) {
				lines.push("");
				lines.push("## Failed");
				for (const f of failedFiles) {
					const fileErrors = result.errors.filter((e) => e.file === f);
					const methods = fileErrors.filter((e) => e.method).map((e) => e.method!);
					lines.push(`- \`${f}\` (${fileErrors.length} failure${fileErrors.length > 1 ? "s" : ""})${methods.length > 0 ? ": " + methods.join(", ") : ""}`);
				}
			}

			// File timing breakdown
			if (result.files.length > 0 && !params.quick) {
				lines.push("");
				lines.push("## Files");
				for (const f of result.files) {
					const fileErrors = result.errors.filter((e) => e.file === f.path);
					const status = fileErrors.length > 0 ? "❌" : "✅";
					lines.push(
						`- \`${f.path}\`: ${status} ${f.tests} test(s) in ${formatTime(f.time)}`,
					);
				}
			}

			// Error details
			if (result.errors.length > 0 && !params.quick) {
				lines.push("");
				lines.push("## Errors");
				for (const err of result.errors) {
					const methodTag = err.method ? ` (${err.method})` : "";
					lines.push(`### ${err.file}:${err.line}${methodTag}`);
					lines.push("```");
					lines.push(stripAnsi(err.detail));
					lines.push("```");
				}
			}

			// Total timing
			const totalTime = result.files.reduce((sum, f) => sum + f.time, 0);
			lines.push("");
			lines.push(`**Total:** ${result.total} test(s) in ${formatTime(totalTime)}`);

			return {
				content: [{ type: "text", text: lines.join("\n") }],
				isError: !allPassed,
				details: {
					total: result.total,
					passed,
					failed: result.fail,
					files: result.files.length,
					totalTime,
					failedFiles: [...failedFiles],
					failedMethods: [...failedMethodKeys],
				},
			};
		},
		renderCall(args, theme, _context) {
			const parts: string[] = ["Run tests"];
			if (args.file_pattern) parts.push(args.file_pattern);
			if (args.method_pattern) parts.push(`method ${args.method_pattern}`);
			if (args.quick) parts.push("(summary only)");
			return new Text(theme.fg("toolTitle", theme.bold("run_tests ")) + theme.fg("dim", parts.join(" ")), 0, 0);
		},
		renderResult(result, { expanded, isPartial }, theme, _context) {
			if (isPartial) return new Text(theme.fg("warning", "Running tests..."), 0, 0);

			if (!result.details || typeof result.details !== "object") {
				return new Text(theme.fg("success", "Done"), 0, 0);
			}

			const details = result.details as {
				total?: number;
				passed?: number;
				failed?: number;
				files?: number;
				totalTime?: number;
				failedFiles?: string[];
				failedMethods?: string[];
			};

			const status = details.failed && details.failed > 0 ? "FAIL" : "OK";
			const statusColor = details.failed && details.failed > 0 ? "error" : "success";

			const container = new Container();

			// Summary line
			container.addChild(new Text(theme.fg(statusColor, `${status}: ${details.total ?? "?"} tests, ${details.files ?? "?"} files, ${formatTime(details.totalTime ?? 0)}`), 0, 0));

			// Failed methods line (always shown when there are failures)
			if (details.failed && details.failed > 0 && details.failedMethods && details.failedMethods.length > 0) {
				container.addChild(new Text(theme.fg("error", `  Failed: ${details.failedMethods.join(", ")}`), 0, 0));
			} else if (details.failed && details.failed > 0) {
				container.addChild(new Text(theme.fg("error", `  Failed: ${details.failed} test(s) in ${details.failedFiles?.length ?? "?"} file(s)`), 0, 0));
			}

			// Full details (only when expanded)
			if (expanded) {
				const content = result.content?.[0];
				if (content?.type === "text") {
					container.addChild(new Text(theme.fg("dim", content.text), 0, 0));
				}
			}

			return container;
		},
	});

	// Register a command for quick access — runs tests directly, no LLM needed
	pi.registerCommand("test", {
		description: "Run tests (all or by pattern)",
		handler: async (args, ctx) => {
			const cmdArgs: string[] = ["--json"];
			if (args) cmdArgs.push(args);

			try {
				const output = execFileSync(TEST_SCRIPT, cmdArgs, {
					cwd: ctx.cwd,
					encoding: "utf-8",
					timeout: 120_000,
				}).trim();

				const result = extractJsonResult(output);
				const passed = result.total - result.fail;
				const totalTime = result.files.reduce((sum, f) => sum + f.time, 0);

				if (result.fail === 0) {
					ctx.ui.notify(`✅ All ${result.total} test(s) passed in ${formatTime(totalTime)}`, "info");
				} else {
					ctx.ui.notify(`❌ ${result.fail} of ${result.total} test(s) failed`, "error");

					// Show error details
					for (const err of result.errors) {
						const methodTag = err.method ? ` (${err.method})` : "";
						ctx.ui.notify(`${err.file}:${err.line}${methodTag}`, "error");
					}
				}
			} catch (error: any) {
				ctx.ui.notify(`Test error: ${error.message ?? String(error)}`, "error");
			}
		},
	});

	// Auto-notify when editing Lua files that have a corresponding test file
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "edit" && event.toolName !== "write") return;

		const inputPath = (event as any).input?.path;
		if (!inputPath || !inputPath.endsWith(".lua") || inputPath.includes("_test.lua")) return;

		const testPath = inputPath.replace(/\.lua$/, "_test.lua");
		try {
			const fs = await import("node:fs");
			if (!fs.existsSync(resolve(ctx.cwd, testPath))) return;
		} catch {
			return;
		}

		ctx.ui.notify(`Test file exists: \`${testPath}\``, "info");
	});
}
