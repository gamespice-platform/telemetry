extends RefCounted

## GameSpice Telemetry's API level. The rule for bumping it is on [DotAddonApi].

# 1: DotTelemetry, DotTelemetryConfig, DotTelemetrySchema, DotTelemetryQueue, DotTelemetryRollup.
# 2: queue head-index (no per-drop shift), persistable queue, send backoff, flush on exit.
const LEVEL := 2
const OLDEST := 1
