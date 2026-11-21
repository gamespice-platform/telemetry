extends RefCounted

## GameSpice Telemetry's API level. The rule for bumping it is on [GSAddonApi].

# 1: GSTelemetry, GSTelemetryConfig, GSTelemetrySchema, GSTelemetryQueue, GSTelemetryRollup.
# 2: queue head-index (no per-drop shift), persistable queue, send backoff, flush on exit.
const LEVEL := 2
const OLDEST := 1
