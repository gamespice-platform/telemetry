class_name GSTelemetryConfig
extends GSConfig

## Every tunable of telemetry. Layers, weakest first: these defaults, `cfg/addon/gs_telemetry/*.yml`, the game's files, the operator's files, `GS_TELEMETRY_*` environment variables, then `--telemetry-*` flags. Telemetry is opt-in: `enabled` is false until the player (or the game on the player's behalf) turns it on.

const ADDON := "gs-telemetry"

## Master switch and the player's off switch. Off, nothing is recorded and anything unsent is discarded.
@export var enabled: bool = false
## Where batches go (https, or http on localhost). The addon never sends them itself; the game's client does.
@export var endpoint: String = ""

@export_group("Batching")
## Seconds between batches while enabled.
@export_range(1, 3600, 1) var flush_seconds: int = 30
## Events per batch; 0 sends the whole queue at once.
@export_range(0, 100000, 1) var batch_size: int = 100
## Events kept while waiting to ship; 0 is unlimited. When full the oldest is dropped and counted.
@export_range(0, 1000000, 1) var max_queue: int = 5000

## After a failed send the wait doubles, up to this many seconds; 0 keeps the normal interval.
@export_range(0, 86400, 1) var max_backoff_seconds: int = 600
## Flush the queue when the game closes or is paused (a phone, a hidden browser tab).
@export var flush_on_exit: bool = true

@export_group("Sampling")
## Share of sessions that report, 0 to 1, decided once per session from its id.
@export_range(0.0, 1.0, 0.01) var sample_rate: float = 1.0
## Longest string property, in characters; 0 is unlimited. A longer one is refused, not cut.
@export_range(0, 65536, 1) var max_string: int = 256
## Whether an event the schema does not declare is recorded as is. Off, it is refused.
@export var allow_unknown_events: bool = false


func env_prefix() -> String:
	return "GS_TELEMETRY_"


func cli_prefix() -> String:
	return "--telemetry-"


func validate() -> GSResult:
	if sample_rate < 0.0 or sample_rate > 1.0:
		return GSResult.fail(GSError.CODE_INVALID, "telemetry sample_rate %s is outside 0 to 1" % sample_rate)
	if max_backoff_seconds < 0 or batch_size < 0 or max_queue < 0 or max_string < 0:
		return GSResult.fail(GSError.CODE_INVALID, "telemetry limits cannot be negative (0 is unlimited)")
	if endpoint != "" and not (endpoint.begins_with("https://") or endpoint.begins_with("http://localhost")):
		return GSResult.fail(GSError.CODE_INVALID, "telemetry endpoint '%s' must be https (or http on localhost)" % endpoint)
	return GSResult.success(self)


## Defaults, then `cfg/addon/gs_telemetry/*.yml` and the game tier, then environment and command line.
static func from_files() -> GSResult:
	var cfg := GSTelemetryConfig.new()
	var files := GSAddonConfig.load_dir(ADDON)
	if not files.ok:
		return files
	cfg.apply_dictionary(files.value as Dictionary, "yml")
	return cfg.load_layered()


func describe() -> String:
	return "telemetry %s sample %.2f batch %d queue %d every %ds" % [
		"on" if enabled else "off", sample_rate, batch_size, max_queue, flush_seconds]
