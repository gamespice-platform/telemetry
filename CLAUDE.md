# GameSpice Telemetry

Opt-in gameplay and performance telemetry. Read the family [CLAUDE.md](../../CLAUDE.md) first. **The distributable is `addons/dot_telemetry/`**; it requires [GameSpice Core](../dot-core) only (`ln -s ../../dot-core/addons/dot_core addons/dot_core`, gitignored).

| Path | What |
| --- | --- |
| `core/dot_telemetry_config.gd` | `DotTelemetryConfig`: every tunable, `from_files()`, `validate()` |
| `core/dot_telemetry_schema.gd` | `DotTelemetrySchema`: declared events and typed fields; refuses anything else |
| `core/dot_telemetry_queue.gd` | `DotTelemetryQueue`: bounded batch queue (a `DotBoundedBuffer`; a requeue over the bound drops the newest), counts what it drops |
| `core/dot_telemetry_rollup.gd` | `DotTelemetryRollup`: counts, sessions, ordered funnels, errors, crash-free rate |
| `runtime/dot_telemetry.gd` | `DotTelemetry`: the node; consent gate, sampling, `track`, `flush`, `shipped` |
| `examples/telemetry_selftest.tscn` | the suite |

## Boundary (what it is not)

- **GameSpice Stats** (`dot-stats`) owns per-player counters, gauges and bests keyed by a pseudonymous player id. Telemetry is per session, schema-declared events. Do not add per-player stat types here.
- **GameSpice Log** (`dot-log`) owns sinks and shipping of log records. Telemetry does not carry log lines.
- **GameSpice Profiler** (`dot-profiler`) owns frame-spike analysis and perf reports; its output may be sent as an event.
- **Achievements, Leaderboard** have their own reporters; do not fold them in.
- No HTTP client here: `batch_ready` hands the batch to the game's client.

## Rules

- Off by default. `enabled` false means nothing is recorded, and turning it off discards the unsent queue.
- No hard caps: `max_queue`, `batch_size`, `max_string` are config, 0 is unlimited, and drops are counted (`queue.dropped`), never silent.
- Undeclared events or fields fail with a reason (`DotResult`); they are not dropped quietly.
- No autoloads, no scene paths. Scripts keep `class_name` like the sibling addons, but nothing may be loaded by `uid://` (packs mount under `res://dot_cloud/...`).
- **Validate**: `--import`, parse every `.gd`, run the suite through `hv` (see the hv-routing skill).
