class_name DotTelemetry
extends Node

## The node a game holds. [method track] checks an event against the schema, drops it if the player has telemetry off or the session is not sampled, then queues it and counts it. A batch leaves through [signal batch_ready]; the game's HTTP client ships it and calls [method shipped].

## A batch is ready to send: an Array of {e, t, s, p} dictionaries (event, unix time, session, properties).
signal batch_ready(batch: Array)

var config: DotTelemetryConfig = DotTelemetryConfig.new()
var schema := DotTelemetrySchema.new()
var queue := DotTelemetryQueue.new()
var rollup := DotTelemetryRollup.new()
var session_id: String = ""

var _sampled := true
var _since_flush := 0.0


func _ready() -> void:
	queue.capacity = config.max_queue


## Begin a session. Whether it reports is decided here, once, from [param id] and the sample rate, so a session is whole or absent.
func start_session(id: String) -> void:
	session_id = id
	queue.capacity = config.max_queue
	_sampled = sampled(id, config.sample_rate)


## Stable pick of sessions: the same id gives the same answer on every machine.
static func sampled(id: String, rate: float) -> bool:
	if rate >= 1.0:
		return true
	if rate <= 0.0:
		return false
	return float(id.hash() % 10000) / 10000.0 < rate


## The player's off switch. Turning it off discards everything unsent.
func set_enabled(on: bool) -> void:
	config.enabled = on
	if not on:
		queue.clear()


## Record an event. Success carries true when it was queued and false when it was skipped on purpose (off, or the session is not sampled). A schema violation fails with the reason.
func track(event: StringName, props: Dictionary = {}) -> DotResult:
	if not config.enabled or not _sampled:
		return DotResult.success(false)
	var clean := props
	if schema.has(event) or not config.allow_unknown_events:
		var r := schema.validate(event, props, config.max_string)
		if not r.ok:
			return r
		clean = r.value as Dictionary
	queue.push({"e": event, "t": Time.get_unix_time_from_system(), "s": session_id, "p": clean})
	rollup.record(event, session_id, Time.get_unix_time_from_system())
	return DotResult.success(true)


func track_error(code: String, fatal: bool = false) -> void:
	if config.enabled and _sampled:
		rollup.record_error(code, session_id, fatal, Time.get_unix_time_from_system())


## Take the next batch and announce it. Empty when telemetry is off or nothing waits.
func flush() -> Array:
	if not config.enabled or queue.size() == 0:
		return []
	var batch := queue.take(config.batch_size)
	batch_ready.emit(batch)
	return batch


## The game's client reports how a batch went; a failed one goes back to the front of the queue.
func shipped(ok: bool, batch: Array) -> void:
	if not ok:
		queue.requeue(batch)


func _process(delta: float) -> void:
	if not config.enabled:
		return
	_since_flush += delta
	if _since_flush >= float(config.flush_seconds):
		_since_flush = 0.0
		flush()
