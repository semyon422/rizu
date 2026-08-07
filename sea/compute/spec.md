# Server Replay Computation

## Goal

Move expensive chart and replay computation out of OpenResty worker processes without weakening server-side score verification. Submissions should remain recoverable across client disconnects, worker failures, and server restarts, and their side effects should be safe to retry.

## User Experience

- Submitting a score should not pause unrelated HTTP requests, WebSocket messages, or multiplayer traffic.
- The native client should receive a prompt acknowledgement after the server has durably accepted the required input data.
- A queued native submission should continue processing if the client disconnects.
- Bancho score submission should keep its synchronous protocol response while computation runs outside the Nginx worker.
- Valid results should eventually appear in leaderboards and user statistics. Permanent validation failures should be observable instead of disappearing as transport failures.
- Duplicate submission or job delivery should not duplicate plays, activity, upload accounting, Dan clears, or leaderboard effects.

## Scope

This document owns the server-side execution flow for chart parsing, difficulty calculation, replay computation, persistence, and the resulting side effects.

Replay serialization and historical compatibility remain owned by `sea/replays/spec.md`. The worker must load replays through `sea.replays.ReplayLoader` and preserve the original serialized bytes and replay hash.

## Current Behavior

The generated Nginx configuration currently starts one worker process. Both native WebSocket submissions and Bancho HTTP submissions execute server computation synchronously in that worker.

The native submission path is:

1. `sea.ChartplaySubmission:submitChartplay` creates a `ComputeDataLoader` backed by the connected client's remote compute-data provider.
2. `sea.Chartplays:submit` creates the chartplay with `compute_state = "new"`.
3. Missing replay and chart files are requested from the client, hash-checked, decoded, and copied into server storage.
4. `sea.ComputeContext` parses the chart, applies modifiers, calculates chart difficulty, and replays every recorded frame through the rhythm engine.
5. The server writes chart metadata, chart difficulty, and the computed chartplay.
6. The same request updates external ranking state, leaderboards, activity, user counters, Dan state, and the connected client's leaderboard view.
7. Only then does the remote call return.

The Bancho adapter performs chart and replay computation before constructing its canonical chartplay, then passes the result through the native submission path, which computes it again. Removing this duplicate computation is useful independently of worker isolation.

`sea.compute.ChartsComputer` and `sea.app.cli` already support manually recomputing stored chartplays, but `sea.ComputeTasks` records batch progress rather than providing a claimed, retryable online job queue.

The current replay-hash get-or-create sequence is not protected by a unique database constraint, and submission finalization plus its secondary effects are not one atomic operation. Those gaps must be closed before retries or multiple workers can be safe.

### Blocking characteristics

OpenResty light threads and Lua coroutines provide cooperative scheduling. They do not move CPU work to another core or process. Chart parsing, difficulty calculation, modifier application, and replay-frame processing do not yield, so wrapping the current computation in `ngx.thread`, a timer, or another coroutine would still occupy the Nginx worker event loop.

Increasing the number of Nginx workers would limit a computation stall to the connections assigned to one worker, but it would not isolate compute load from request handling. It would also introduce additional database writers and is not the target architecture.

### July 2026 measurement

A read-only local benchmark ran the pure load, parse, difficulty, and replay stages for the 26 most recent valid chartplays, among the latest 500, whose replay and chart files were both available in the checkout.

| Stage | p50 | p95 |
|---|---:|---:|
| Complete measured phase | 32 ms | 342 ms |
| Chart parsing | 2 ms | 18 ms |
| Difficulty calculation | 18 ms | 132 ms |
| Replay playback | 11 ms | 89 ms |

The slowest measured play took 370 ms: 193 ms parsing, 85 ms calculating difficulty, and 89 ms replaying frames. The sample is small and affected by local filesystem caches. It excludes database finalization, leaderboard recalculation, external API access, notifications, and adversarial or unusually large charts, so it is evidence of the blocking problem rather than a capacity forecast.

## Implemented Baseline (Phase 2)

The first production boundary is implemented as synchronous external computation:

- Compose supervises one `compute` service running `sea/compute/worker.lua` in a separate persistent LuaJIT process.
- OpenResty connects to `127.0.0.1:8191` with a yielding Nginx cosocket. The HTTP/WebSocket coroutine remains pending, but chart parsing, difficulty calculation, and replay playback execute only in the compute process.
- IPC uses one length-prefixed STBL request and response per TCP connection. Both peers enforce a 64 MiB framed-payload limit (while ingestion limits each chart and replay to 16 MiB), a 120-second timeout, and exact compute-version equality. The service accepts at most one active client, which is the initial hard concurrency bound and backpressure mechanism.
- `sea.compute.ReplayComputer` owns the repository-independent request/result computation boundary. `sea.compute.ComputeRequest` and `ComputeResult` validate the records and restore concrete metatables after deserialization.
- OpenResty still retrieves client inputs, verifies hashes, publishes immutable chart/replay files with temporary-write plus atomic rename, and performs all database finalization and secondary effects.
- Native and Bancho contracts remain synchronous in this baseline. Bancho now only converts its protocol replay and constructs base records; it no longer parses, calculates difficulty, and replays the score before submitting it for the canonical computation.
- Manual stored-chartplay recomputation also uses the same replay-computer abstraction, so production can keep expensive recomputation out of OpenResty while tests and CLI contexts may inject the in-process implementation.

The process is deliberately compute-only: it has no database or persistent-state mount and cannot finalize submissions. Durable asynchronous native acceptance, leases, and an idempotent side-effect outbox remain the next phases; the synchronous baseline does not claim disconnect or restart recovery after the IPC request begins.

## Target Architecture

The target separates input ingestion, pure computation, canonical finalization, and secondary side effects:

```text
client
  |
  v
Nginx ingestion
  - authenticate and rate-limit
  - retrieve, bound, and hash-check inputs
  - atomically persist immutable chart/replay data
  - create chartplay and compute job
  |
  v
bounded persistent compute worker pool
  - load and validate inputs
  - parse chart
  - calculate difficulty
  - replay frames
  - produce a typed result or classified failure
  |
  v
short canonical finalization transaction
  - write chartmeta/chartdiff/chartplay
  - mark chartplay valid or invalid
  - create idempotent side-effect records
  |
  v
secondary processing and best-effort notification
  - leaderboards and user aggregates
  - activity and Dan state
  - external ranking lookup
  - connected-user notification
```

### Ingestion

The Nginx worker remains responsible for connection-specific work that cannot be deferred:

- authenticating the user,
- enforcing submission access and input-size limits,
- retrieving missing data from `remote.compute_data_provider` while the WebSocket still exists,
- validating content hashes,
- durably storing the replay and chart bytes,
- creating or finding the canonical chartplay,
- creating the durable compute job.

The job must not become visible until every required input is durably available to a worker. Folder storage should write a temporary file and atomically rename it into its content-addressed location.

Full replay conversion and semantic validation may run in the compute worker. Ingestion still needs enough validation to reject malformed remote contracts, oversized data, and hash mismatches without creating unbounded work.

### Compute worker

Replay computation runs in a persistent LuaJIT process outside OpenResty. The initial pool should contain one worker and have a hard concurrency bound. Additional workers should be added only from queue-age and CPU measurements.

The worker receives immutable input identifiers and explicit computation parameters. It must not depend on a live `sea.Peer`, call client remotes, send notifications, update leaderboards, or perform external HTTP requests.

The computation boundary should be expressible as a repository-independent request and result:

```text
ComputeRequest
  job and chartplay identifiers
  replay hash
  chart hash, stored name, and index
  expected compute version

ComputeResult
  normalized replay base
  chartmeta
  chartdiff
  chartplay-computed fields
  compute version
  stage timings
```

The exact Lua record shapes should be documented through EmmyLua annotations when implemented. Result deserialization must restore the concrete metatables needed by repository validation.

For non-custom plays, server-computed values are canonical even when the client supplies its own chartdiff and chartplay-computed values. Client values may be retained temporarily for drift telemetry, but a mismatch must have an explicit policy rather than remaining as ignored comparison code.

Custom plays currently use the submitted custom chartdiff instead of recomputing standard difficulty. Their validation and persistence policy must remain explicit in the worker contract.

### Finalization

Computation must occur outside a database transaction. Once a result exists, the worker or finalizer opens a short transaction that:

1. verifies that the job still owns a valid lease and has not already completed,
2. creates or updates chartmeta and chartdiff records,
3. imports normalized replay-base and server-computed fields into the chartplay,
4. changes the chartplay to its terminal `valid` or `invalid` state,
5. records durable, uniquely keyed side effects,
6. marks the job complete.

External API calls, client remote calls, and lengthy leaderboard recalculation must not occur inside this transaction.

### Native submission

The native protocol should become asynchronous after durable ingestion. `submitChartplay` should return a submission identifier and a state such as `queued`, rather than holding the WebSocket call open until computation and all secondary effects finish.

Completion notification may use the existing user-targeted broadcast path, but the persisted chartplay/job state is authoritative. Notification loss or disconnect must not lose the submission.

### Bancho submission

Bancho expects a synchronous score response. It should submit through the same compute boundary, then await completion through nonblocking IPC. The HTTP coroutine may remain pending, but the compute process owns the CPU work and the Nginx event loop remains available.

The await path needs a finite protocol-compatible timeout. A timeout must not cancel or lose a durably accepted job. Retrying the HTTP submission must resolve to the same canonical chartplay instead of duplicating its effects.

Before the durable flow is complete, Bancho can use synchronous request/reply to the external compute process to preserve behavior. Its existing second computation should be removed as part of extracting the shared compute boundary.

## Job Model

Runtime job state should be separate from the public chartplay compute state. `Chartplay.compute_state` can retain the existing `new`, `valid`, and `invalid` meanings while a dedicated job record carries delivery and retry details.

Proposed job states:

```text
queued -> running -> succeeded
          |   |
          |   +-> queued       transient retry
          |
          +----> failed        permanent validation failure
          |
          +----> dead          retry budget exhausted
```

A job should record at least:

- its chartplay identifier,
- a unique idempotency key,
- state,
- attempt count,
- creation and update times,
- next eligible attempt time,
- lease owner and lease expiry,
- compute version,
- last error code and bounded diagnostic text,
- stage timings.

Only one live job may exist for a canonical chartplay. A worker claims a job in a short transaction, commits the claim, computes without holding database locks, and then attempts finalization. Expired leases make abandoned work eligible for retry.

Failures must be classified:

- malformed replay, unsupported format, hash mismatch, invalid timings, and deterministic parser/engine rejection are permanent;
- unavailable storage, worker crash, IPC failure, and database busy errors are transient;
- unexpected internal exceptions retry a bounded number of times and then enter `dead` for inspection.

At-least-once execution is assumed. Exactly-once business effects come from database constraints, idempotent finalization, and uniquely keyed side-effect records, not from transport promises.

External service failures belong to their corresponding side-effect job and do not change an already finalized chartplay back into a compute failure.

## Architecture Decisions

### ADR: External persistent processes provide CPU isolation

Replay computation will run in persistent LuaJIT worker processes, not OpenResty light threads, request coroutines, or Nginx timers.

Persistent workers avoid per-submission process startup, allow bounded concurrency, and can later retain safe chart or calculation caches. A local Unix socket is the baseline request/reply transport for the first isolation step; the durable job record remains independent of the notification or IPC transport.

### ADR: Durable database job, optional NATS wake-up

The initial durable queue should be represented in the server database because the deployment is single-host and the submission and job can be committed together. NATS Core may notify workers that new work exists, but database polling must recover missed notifications and server restarts.

The existing NATS integration is broadcast-oriented. Its OpenResty client does not expose queue groups, acknowledgements, durable consumers, or JetStream. Core NATS publication alone must not be treated as durable job acceptance.

JetStream remains an option if operational requirements justify a separate durable broker and suitable Lua clients. Moving to it would not remove the need for idempotent finalization.

### ADR: Immutable content-addressed inputs

Jobs refer to chart and replay hashes instead of embedding large payloads in the queue. Input files are immutable after their hash has been verified and must be persisted before enqueue.

The chart's stored filename and selected index are part of the request because parsing depends on format selection, not only on bytes.

### ADR: Server results remain canonical

Moving computation out of Nginx must not change the trust boundary. Standard ranked results come from server code running the installed chart parser, modifiers, difficulty model, rhythm engine, and scoring engine.

Accepting client-computed fields without server verification is not a substitute for worker isolation.

### ADR: Computation is versioned operationally

Each job and result records the deployed computation version. At minimum this is an immutable build or Git revision; a dedicated engine version may be added later.

A worker must reject or requeue a job that requests a computation version it cannot provide. Rolling deployment must not silently finalize a result under a different version than the one recorded on the job.

This operational version records what code performed the computation. It does not change the replay compatibility guarantees in `sea/replays/spec.md`.

### ADR: Secondary effects are retryable and idempotent

Canonical chartplay finalization and secondary business effects are separate. Finalization emits uniquely keyed work for leaderboard updates, activity, user aggregates, Dan state, external ranking lookup, and notifications.

Additive counters must not be incremented again when a job or side effect is redelivered. Prefer recomputable aggregates or a uniqueness constraint tied to the chartplay/event where practical.

## Invariants

- CPU-bound chart and replay computation does not run in an OpenResty worker after the migration is complete.
- A compute job never depends on a live client connection.
- A job is not visible before all required immutable inputs are durably stored.
- Original replay bytes and their replay hash are preserved.
- Standard non-custom results are computed by server-controlled code.
- Worker concurrency is explicitly bounded; queue growth applies backpressure instead of spawning unbounded processes.
- No database transaction spans computation, IPC, external HTTP, or client remote calls.
- Job delivery and finalization are safe under duplicate execution.
- A chartplay becomes `valid` only after all canonical result rows commit.
- A permanent invalid result does not enter leaderboards or successful user aggregates.
- Completion notification is best-effort; persisted state is authoritative.
- Every finalized result identifies the computation version that produced it.
- If SQLite WAL remains the queue store, every process accessing it runs on the same host.
- Multiple SQLite writer processes are not enabled until the deployed SQLite library contains the WAL-reset fix described below.

## SQLite Safety Prerequisite

`sea.ServerSqliteDatabase` enables WAL, `synchronous = NORMAL`, and a 10-second busy timeout. The SQLite library observed at the start of the July 2026 investigation was version 3.49.1. The dependency manifest now pins SQLite 3.53.4 for every target.

SQLite documents a rare WAL-reset corruption bug affecting upstream versions 3.7.0 through 3.51.2 when separate connections in multiple threads or processes write or checkpoint at the same time. The fix is in 3.51.3 and selected backports:

https://www.sqlite.org/wal.html#wal_reset_bug

Before a compute worker or finalizer becomes an additional writer to `server.db`, deployment must build and deploy the pinned SQLite library, then verify version 3.51.3 or later through the same `ljsqlite3` library used by the application. Updating only a system SQLite command-line program does not verify the library selected by the runtime.

Until that prerequisite is met, the external process must remain compute-only and the existing server process must perform database finalization. WAL still permits concurrent readers and one writer, but write transactions must remain short:

https://www.sqlite.org/wal.html#concurrency

## Rollout Plan

### Phase 1: Measurement and pure boundary (implemented)

- Add stage timings for input load, replay decode, chart parse, difficulty, replay playback, finalization, and secondary effects.
- Add Nginx event-loop-lag and submission-latency measurements.
- Extract a repository-independent compute request/result boundary from `sea.Chartplays:processSubmit`.
- Verify that the extracted path produces the same canonical results as the current synchronous path.
- Remove the duplicate Bancho computation.

### Phase 2: Synchronous external computation (implemented)

- Start one supervised persistent LuaJIT compute process.
- Add bounded local request/reply IPC with payload limits, timeouts, and structured errors.
- Keep native and Bancho remote contracts synchronous initially while the Nginx coroutine awaits IPC.
- Keep database writes in the current server process until the SQLite safety prerequisite is satisfied.
- Measure event-loop responsiveness and worker capacity under concurrent submissions.

### Phase 3: Durable native submissions

- Add the compute-job schema, atomic claim, leases, retry policy, and operator-visible failure details.
- Make replay and chart storage publication atomic.
- Change the native remote response to return a queued submission.
- Recover queued and expired jobs after restarts.
- Notify connected users after finalization without making notification part of correctness.

### Phase 4: Idempotent side effects

- Add short canonical finalization transactions.
- Add unique side-effect keys or an outbox.
- Move external ranking lookup, leaderboard work, user aggregates, activity, Dan handling, and notifications out of the compute transaction.
- Add safe replay/reprocessing commands for failed jobs and side effects.

### Phase 5: Scale and optimize

- Increase worker count only when queue age and CPU utilization justify it.
- Evaluate worker-local chart and difficulty-context caches with explicit versioned keys and memory bounds.
- Consider JetStream only if the database queue becomes an operational or scaling limitation.

## Verification

Implementation should cover:

- result equivalence between the old synchronous path and the extracted worker computation,
- native and Bancho end-to-end submission,
- no duplicate Bancho computation,
- client disconnect immediately after durable acceptance,
- worker crash before claim, during computation, and after computation but before finalization,
- expired leases and bounded retry,
- duplicate submissions and duplicate job/result delivery,
- malformed, oversized, missing, and hash-mismatched inputs,
- permanent invalid results versus transient infrastructure failures,
- database busy handling and concurrent finalization,
- idempotent leaderboard, activity, user-counter, Dan, and external-ranking effects,
- compute-version mismatch during rolling deployment,
- queue saturation and backpressure,
- Nginx event-loop responsiveness while long replays compute,
- restart recovery with NATS unavailable.

Representative replay compatibility fixtures should continue to follow the verification checklist in `sea/replays/spec.md`.

## Future Work and Open Questions

- Replace the implemented loopback TCP endpoint with a Unix socket if OpenResty's and LuaSocket's deployment support makes that operationally simpler; framing and payload limits remain unchanged.
- Decide whether Bancho should move from the implemented direct compute request/reply plus synchronous finalization to a durable job while preserving its protocol response.
- Define the public native submission-status query and notification contract.
- Decide the exact boundary between canonical finalization and leaderboard visibility.
- Determine which user statistics should be recomputed from canonical rows rather than incremented.
- Define worker memory and CPU limits, maximum chart/replay complexity, and queue admission limits.
- Investigate reusable difficulty contexts. A persisted `Chartdiff` alone may not contain every intermediate value required by `ChartplayComputedFactory`.
- Decide when the operational complexity of JetStream is justified.
