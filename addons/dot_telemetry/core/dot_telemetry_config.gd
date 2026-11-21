class_name DotTelemetryConfig
extends DotConfig

## Every tunable of telemetry. Layers, weakest first: these defaults, `cfg/addon/dot_telemetry/*.yml`, the game's files, the operator's files, `DOT_TELEMETRY_*` environment variables, then `--telemetry-*` flags. Telemetry is opt-in: `enabled` is false until the player (or the game on the player's behalf) turns it on.

const ADDON := "dot-telemetry"

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

@export_group("Sampling")
## Share of sessions that report, 0 to 1, decided once per session from its id.
@export_range(0.0, 1.0, 0.01) var sample_rate: float = 1.0
## Longest string property, in characters; 0 is unlimited. A longer one is refused, not cut.
@export_range(0, 65536, 1) var max_string: int = 256
## Whether an event the schema does not declare is recorded as is. Off, it is refused.
@export var allow_unknown_events: bool = false


func env_prefix() -> String:
	return "DOT_TELEMETRY_"


func cli_prefix() -> String:
	return "--telemetry-"


func validate() -> DotResult:
	if sample_rate < 0.0 or sample_rate > 1.0:
		return DotResult.fail(DotError.CODE_INVALID, "telemetry sample_rate %s is outside 0 to 1" % sample_rate)
	if endpoint != "" and not (endpoint.begins_with("https://") or endpoint.begins_with("http://localhost")):
		return DotResult.fail(DotError.CODE_INVALID, "telemetry endpoint '%s' must be https (or http on localhost)" % endpoint)
	return DotResult.success(self)


## Defaults, then `cfg/addon/dot_telemetry/*.yml` and the game tier, then environment and command line.
static func from_files() -> DotResult:
	var cfg := DotTelemetryConfig.new()
	var files := DotAddonConfig.load_dir(ADDON)
	if not files.ok:
		return files
	cfg.apply_dictionary(files.value as Dictionary, "yml")
	return cfg.load_layered()


func describe() -> String:
	return "telemetry %s sample %.2f batch %d queue %d every %ds" % [
		"on" if enabled else "off", sample_rate, batch_size, max_queue, flush_seconds]
