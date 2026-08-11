# Server Replay Computation

## Goal

Keep expensive chart and replay computation outside OpenResty while preserving server-authoritative score verification. Accepted submissions must survive disconnects, worker failures, retries, graceful reloads, and server restarts without duplicating canonical plays or business effects.

## User Experience

- Native score submission returns promptly after the required immutable inputs and durable job have been accepted.
- A submission continues after the client disconnects.
- Persisted status, not notification delivery, is authoritative.
- Bancho keeps its synchronous protocol response while CPU-bound computation runs outside Nginx.
- Valid results eventually appear in leaderboards and user statistics.
- Permanent compute failures and exhausted retry budgets remain inspectable.
- Duplicate submission or delivery does not duplicate chartplays or their side effects.

## Scope

This document owns server-side input ingestion, replay computation, canonical finalization, durable compute jobs, and chartplay side effects.

Replay serialization and historical compatibility are owned by `sea/replays/spec.md`. Computation must load replays through `sea.replays.ReplayLoader`, preserve the original bytes, and preserve the replay hash.

## Implemented Architecture

```text
native client / Bancho
  |
  v
OpenResty ingestion
  - authenticate and rate-limit
  - retrieve, bound, and hash-check missing inputs
  - atomically publish immutable chart/replay files
  - atomically create chartfile, chartplay, and compute job
  |
  v
SQLite compute_jobs queue
  - conditional claim
  - lease and bounded retry
  - restart and expired-lease recovery
  |
  v
external LuaJIT compute service over bounded TCP IPC
  - parse chart
  - calculate difficulty
  - replay frames
  - return typed canonical result or classified failure
  |
  v
short finalization transaction in OpenResty
  - verify lease ownership
  - write chartmeta/chartdiff/chartplay
  - create chartplay_effects outbox rows
  - mark compute job succeeded
  |
  v
SQLite chartplay_effects queue
  - external ranking
  - leaderboards
  - activity
  - user aggregates
  - Dan handling
  - best-effort completion notification
```

### Input ingestion

OpenResty performs the connection-specific work that cannot be deferred:

1. Authenticate and rate-limit the submitting user.
2. Request missing replay and chart data from the connected native client, or use the Bancho provider.
3. Enforce the 16 MiB per-input ingestion limit and validate content hashes.
4. Publish chart and replay bytes through content-addressed storage using temporary write plus atomic rename.
5. In one database transaction, create or find the chartfile and canonical chartplay, then create exactly one compute job for that chartplay.

A job is not visible until all required immutable inputs are available. `chartplays.replay_hash`, `compute_jobs.chartplay_id`, and the compute-job idempotency key are unique. A replay already owned by another user is rejected.

Upload attribution is persisted on the compute job at acceptance so restart processing can reconstruct aggregate upload accounting without a live request.

### Durable compute processing

`compute_jobs` uses these states:

```text
queued -> running -> succeeded
          |   |
          |   +-> queued       transient retry
          |
          +----> failed        permanent compute rejection
          |
          +----> dead          transient retry budget exhausted
```

A compute job records its chartplay, idempotency key, compute version, submitted custom chartdiff, attempt count, retry time, lease owner and expiry, bounded failure diagnostics, upload attribution, and stage timings.

Claims are conditional database updates. The default lease is 180 seconds and the retry budget is three attempts. Expired `running` jobs are claimable again. Each claim gets a distinct lease-owner token so stale work from an earlier claim cannot finalize a newer claim.

An OpenResty timer loop drains queued and expired jobs. It runs only in Nginx worker 0, polls once per second while idle, backs off after errors, and stops scheduling during shutdown. Database claims still protect graceful-reload overlap between old and new worker-0 processes.

### External compute boundary

Compose supervises one persistent compute-only LuaJIT service running `sea/compute/worker.lua`. It has no database or persistent-state mount.

OpenResty communicates with it through one length-prefixed STBL request and response per TCP connection on `127.0.0.1:8191`. Both sides enforce:

- a 64 MiB framed-payload limit,
- a 120-second timeout,
- exact compute-version equality,
- one active compute client as the initial concurrency and backpressure bound.

OpenResty uses a yielding Nginx cosocket from request or timer context. The TCP wait does not block unrelated requests in that Nginx worker. CPU-bound parsing, difficulty calculation, modifier application, and replay playback run only in the external process.

`sea.compute.ReplayComputer` defines the repository-independent boundary. `ComputeRequest` carries the compute version, chartplay inputs, submitted custom chartdiff, chart filename, chart bytes, and replay bytes. `ComputeResult` carries the version, normalized replay base, chart metadata, chart difficulty, computed chartplay values, and stage timings. Deserialization restores concrete metatables before validation and persistence.

Standard non-custom results are always server-computed and canonical. Custom plays retain their explicit submitted-chartdiff policy.

### Failure classification

Compute failures cross the process boundary as:

```text
ComputeFailure {
  kind = "permanent" | "transient",
  code = string,
  message = string
}
```

Deterministic malformed input, unsupported formats, and validation rejection are permanent. Worker availability, IPC, storage, version mismatch, invalid worker results, finalization errors, and unexpected infrastructure errors are transient.

A permanent failure marks the chartplay `invalid` and the compute job `failed` in one transaction. A transient failure requeues the job until its attempt budget is exhausted, then leaves it `dead`. Side-effect failures never change an already valid chartplay back into a compute failure.

### Canonical finalization

Computation never runs inside a database transaction. Once a result exists, OpenResty opens a short transaction that:

1. verifies the active claim and lease-owner token,
2. creates or updates chart metadata and difficulty rows,
3. imports canonical computed values into the chartplay,
4. marks the chartplay `valid`,
5. inserts the six uniquely keyed side-effect rows,
6. marks the compute job `succeeded` with stage timings.

External HTTP, leaderboard recomputation, NATS publication, and client remotes do not run in this transaction.

### Durable side effects

`chartplay_effects` contains one row per `(chartplay_id, effect)` for:

- `external_ranked`,
- `leaderboards`,
- `activity`,
- `user_aggregates`,
- `dan`,
- `notification`.

Effects use conditional claims, 60-second leases, five attempts, delayed retries, bounded diagnostics, and `dead` state. A second worker-0 timer loop drains this queue and recovers queued or expired work after restart.

At-least-once delivery is expected. Replay safety comes from effect-specific behavior:

- leaderboards are recalculated from canonical valid chartplays,
- activity is rebuilt from canonical valid chartplays,
- user counts, play time, latest activity, and upload totals are recomputed from canonical rows and accepted upload attribution,
- external ranking checks for an existing row,
- Dan handling retains its semantic duplicate guard,
- notification is best-effort and does not affect correctness.

The notification effect is claimable only after every other effect for the chartplay has succeeded. It broadcasts `chartplaySubmissionCompleted(chartplay_id)` to connected sockets of the submitting user. Notification loss is harmless because persisted status remains authoritative.

### Native protocol

Native `submitChartplay` returns `ChartplaySubmissionResult` after durable acceptance. Its status includes the job and chartplay identifiers, compute state, attempts, retry time, bounded failure details, an optional canonical chartplay after compute success, and `effects_complete`.

`getChartplaySubmission(job_id)` returns the persisted status only when the job belongs to the authenticated user. The canonical chartplay may be available before `effects_complete` becomes true.

Duplicate native submissions resolve to the same canonical chartplay and job.

### Bancho protocol

Bancho uses the same durable chartplay, compute job, and side-effect rows, but preserves its synchronous score response. Its request awaits external computation, canonical finalization, and durable side-effect processing. A client retry resolves through replay-hash idempotency rather than creating a second chartplay.

### Operator commands

`sea/app/cli.lua` exposes:

```text
compute_jobs [state] [limit]
requeue_compute_job <id>
chartplay_effects [state] [limit]
requeue_chartplay_effect <id>
```

Compute jobs can be requeued from `failed` or `dead`. Side effects can be requeued from `dead`. Inspection limits are bounded.

## Architecture Decisions

### ADR: Persistent external processes provide CPU isolation

Replay computation runs in a persistent LuaJIT process, not an OpenResty light thread, request coroutine, or Nginx timer. Coroutines make I/O cooperative but do not move CPU work off the Nginx process.

Persistent workers avoid per-submission process startup and permit explicit concurrency bounds. The compute service remains stateless and cannot finalize submissions.

### ADR: SQLite is the durable queue

The deployment is single-host, and SQLite allows chartplay acceptance, compute-job creation, canonical finalization, and outbox creation to share transactions with their owning records.

NATS Core may be used as a wake-up optimization later, but database polling remains authoritative. Core NATS publication is not durable job acceptance. JetStream is only worth considering if measured scale or operational requirements justify it.

### ADR: Inputs are immutable and content-addressed

Jobs refer to verified chart and replay hashes instead of embedding large payloads in the queue. The chart filename and selected index remain explicit because parser selection depends on them.

Generic folder storage retains ordinary overwrite semantics. Immutability is enforced by `ContentAddressedStorage`.

### ADR: Server results remain canonical

Moving computation out of Nginx does not change the trust boundary. Ranked results come from server-controlled parser, modifier, difficulty, rhythm-engine, and scoring code. Client-computed fields are not accepted as substitutes for server verification.

### ADR: Computation is operationally versioned

Every compute job and result records the deployed computation version. A result produced by a different version cannot silently finalize the job. This operational version does not replace replay-format compatibility guarantees.

### ADR: Exactly-once behavior comes from idempotency

Transport and queue processing are at least once. Uniqueness constraints, lease-owner checks, canonical recomputation, and effect-specific duplicate guards provide exactly-once business outcomes.

## Invariants

- CPU-bound chart and replay computation does not run in OpenResty.
- The external compute service has no database or persistent-state access.
- A compute job never depends on a live client connection.
- A job is not visible before all required immutable inputs are durably stored.
- Original replay bytes and replay hash are preserved.
- Standard non-custom results are computed by server-controlled code.
- Compute concurrency is explicitly bounded.
- No database transaction spans computation, IPC, external HTTP, NATS, or client remote calls.
- Claims are conditional and stale lease owners cannot finalize newer claims.
- A chartplay becomes `valid` only with all canonical result rows committed.
- Compute success and outbox creation commit atomically.
- A permanent invalid result does not enter successful aggregates or leaderboards.
- Duplicate submission, compute delivery, or side-effect delivery does not create a duplicate chartplay.
- Notification is best-effort; persisted job and effect state is authoritative.
- Every finalized result identifies its compute version.
- SQLite queue access remains on one host.

## SQLite Runtime Safety

`sea.ServerSqliteDatabase` enables WAL, `synchronous = NORMAL`, foreign keys, and a 10-second busy timeout. The dependency manifest pins SQLite 3.53.4, and the deployed `ljsqlite3` runtime must remain at 3.51.3 or later.

Older SQLite versions are affected by the WAL-reset corruption bug described at:

https://www.sqlite.org/wal.html#wal_reset_bug

The external compute service remains compute-only, so all database writes are performed by OpenResty. Transactions remain short even though timer and request coroutines can contend for the one SQLite writer.

## Historical Performance Evidence

A July 2026 read-only sample measured 26 recent valid chartplays with locally available inputs:

| Stage | p50 | p95 |
|---|---:|---:|
| Complete measured phase | 32 ms | 342 ms |
| Chart parsing | 2 ms | 18 ms |
| Difficulty calculation | 18 ms | 132 ms |
| Replay playback | 11 ms | 89 ms |

The slowest measured play took 370 ms. The sample excludes finalization, side effects, cold storage, and adversarial charts; it justified CPU isolation but is not a capacity forecast.

## Completed Rollout

1. Extracted and measured the pure replay-computation boundary.
2. Moved CPU work to the supervised external LuaJIT service with bounded typed IPC.
3. Added immutable input publication, replay-hash idempotency, durable compute jobs, leases, retries, restart recovery, async native acknowledgement, status polling, and synchronous Bancho compatibility.
4. Added transactional outbox creation and durable idempotent side-effect processing.

Further work is operational hardening and measured scaling rather than completing the original migration.

## Verification

Coverage includes:

- external request/result equivalence and protocol bounds,
- native and Bancho end-to-end submission,
- duplicate replay submission,
- permanent versus transient compute failures,
- exclusive claims and expired-lease recovery,
- retry exhaustion and operator requeue,
- async queued-to-succeeded status and ownership isolation,
- atomic input acceptance and retrieval failures,
- unique side-effect keys and notification dependencies,
- side-effect retry, dead state, and requeue,
- migration through schema version 10,
- Bancho adapter and end-to-end regressions.

Representative replay fixtures should continue to follow `sea/replays/spec.md`.

## Future Work and Open Questions

### Native submission tracking

- Add a reconnect-safe native submission tracker that persists pending job identifiers or replay identities locally.
- Treat `chartplaySubmissionCompleted` as a wake-up hint, then fetch authoritative status.
- Poll `getChartplaySubmission` after reconnect and when a completion notification is missed.
- Remove completed submissions from local pending state only after observing persisted terminal status.
- Display queued, retrying, permanent failure, dead job, and incomplete-side-effect states in the client UI.
- Consider exposing a bounded side-effect failure summary through native status when compute succeeded but an effect is dead.

### Observability and backpressure

- Export queue depth, oldest eligible job age, running/retrying/dead counts, attempt counts, compute latency, effect latency, and stage timings.
- Add operator alerts for stuck queues, repeated transient failures, and dead effects.
- Add per-user and global outstanding-submission limits so a compute outage cannot grow the queue without bound.
- Reject excessive work before storing inputs where possible.

### Recovery and stress testing

- Exercise graceful reload overlap between old and new worker-0 loops.
- Test compute-service outages and restarts under concurrent submissions.
- Test SQLite busy contention and large submission bursts.
- Inject crashes after effect application but before acknowledgement to verify replay safety for every effect.
- Measure Nginx event-loop responsiveness while long computations and external side effects are active.

### Scaling and optimization

- Increase external compute worker count only when queue age and CPU utilization justify it.
- Define worker memory and CPU limits plus maximum chart/replay complexity.
- Evaluate bounded worker-local chart and difficulty-context caches with versioned keys.
- Investigate reusable difficulty contexts; persisted `Chartdiff` may not contain every intermediate required by `ChartplayComputedFactory`.
- Replace loopback TCP with a Unix socket if deployment support provides a clear operational benefit.
- Consider NATS wake-ups or JetStream only if measured SQLite polling or queue operations become limiting.
