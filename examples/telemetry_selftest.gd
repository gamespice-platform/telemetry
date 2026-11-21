extends Node

## dot-telemetry's headless suite (res://examples/telemetry_selftest.tscn).
## Counts sections run to their last line as well as checks, because a script error
## aborts a section and not the run.

const EXPECTED_SECTIONS := 7
const EXPECTED_CHECKS := 65

var _passed := 0
var _failed := 0
var _sections := 0


func _ready() -> void:
	print("dot-telemetry")
	_config()
	_schema()
	_queue()
	_rollup()
	_node()
	_resilience()
	_layers()
	print("")
	_check(_sections == EXPECTED_SECTIONS, "every section ran to its last line (%d of %d)" % [_sections, EXPECTED_SECTIONS])
	_check(_passed + _failed == EXPECTED_CHECKS, "and the suite ran all %d of its checks (%d)" % [EXPECTED_CHECKS, _passed + _failed])
	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _config() -> void:
	var c := GSTelemetryConfig.new()
	_check(c.validate().ok, "defaults validate")
	_check(not c.enabled, "telemetry is off until someone turns it on")
	c.sample_rate = 1.5
	_check(not c.validate().ok, "a sample rate over 1 is refused")
	c.sample_rate = 0.5
	c.endpoint = "http://example.com/in"
	_check(not c.validate().ok, "a plain http endpoint is refused")
	c.endpoint = "https://example.com/in"
	_check(c.validate().ok, "an https endpoint is fine")
	c.endpoint = "http://localhost:8080/in"
	_check(c.validate().ok, "http on localhost is fine")
	_check(c.has_key("flush_seconds") and c.has_key("max_queue") and c.has_key("batch_size"), "the tunables are config keys")
	_sections += 1


func _schema() -> void:
	var s := GSTelemetrySchema.new()
	_check(s.declare(&"level.finish", {"seconds": "float", "deaths": "int", "map": "string", "won": "bool"}).ok, "a declaration with every type")
	_check(not s.declare(&"Bad Name", {}).ok, "an uppercase event name is refused")
	_check(not s.declare(&"x", {"a": "vector"}).ok, "an unknown field type is refused")
	_check(not s.declare(&"x", {"A": "int"}).ok, "a bad field name is refused")
	_check(s.has(&"level.finish") and not s.has(&"x"), "only declared events are known")
	var good := {"seconds": 12.5, "deaths": 2, "map": "dust", "won": true}
	var r := s.validate(&"level.finish", good)
	_check(r.ok and (r.value as Dictionary)["deaths"] == 2, "a matching event validates", str(r.code()))
	_check(not s.validate(&"nope", {}).ok, "an undeclared event is refused")
	var missing := good.duplicate()
	missing.erase("map")
	_check(not s.validate(&"level.finish", missing).ok, "a missing field is refused")
	var extra := good.duplicate()
	extra["email"] = "a@b.c"
	_check(not s.validate(&"level.finish", extra).ok, "an undeclared field is refused, so nothing sneaks in")
	var wrong := good.duplicate()
	wrong["deaths"] = "two"
	_check(not s.validate(&"level.finish", wrong).ok, "a wrong type is refused")
	var as_int := good.duplicate()
	as_int["seconds"] = 12
	_check(s.validate(&"level.finish", as_int).ok, "an int is a fine float")
	var long := good.duplicate()
	long["map"] = "x".repeat(300)
	_check(not s.validate(&"level.finish", long, 256).ok, "a string over the limit is refused")
	_check(s.validate(&"level.finish", long, 0).ok, "0 means no string limit")
	_check(s.event_names() == PackedStringArray(["level.finish"]), "event_names lists them")
	_sections += 1


func _queue() -> void:
	var q := GSTelemetryQueue.new(3)
	for i in 5:
		q.push(i)
	_check(q.size() == 3 and q.dropped == 2, "a full queue drops the oldest and counts it", "%d/%d" % [q.size(), q.dropped])
	_check(q.take(2) == [2, 3] and q.size() == 1, "take pulls from the front")
	q.requeue([2, 3])
	_check(q.take(0) == [2, 3, 4], "requeue puts a failed batch back first and take(0) takes all")
	var u := GSTelemetryQueue.new(0)
	for i in 1000:
		u.push(i)
	_check(u.size() == 1000 and u.dropped == 0, "capacity 0 is unlimited")
	_check(u.clear() == 1000 and u.size() == 0, "clear says how many it threw away")
	_sections += 1


func _rollup() -> void:
	var r := GSTelemetryRollup.new()
	_check(not r.define_funnel(&"f", [&"a"]).ok, "a one-step funnel is refused")
	_check(r.define_funnel(&"onboarding", [&"start", &"move", &"shoot"]).ok, "a funnel is defined")
	r.record(&"start", "s1", 0.0)
	r.record(&"move", "s1", 5.0)
	r.record(&"shoot", "s1", 9.0)
	r.record(&"start", "s2", 0.0)
	r.record(&"move", "s2", 3.0)
	r.record(&"shoot", "s3", 1.0)
	r.record(&"start", "s3", 2.0)
	_check(r.funnel(&"onboarding") == [3, 2, 1], "funnel counts sessions per step in order", str(r.funnel(&"onboarding")))
	_check(r.count(&"start") == 3 and r.count(&"nothing") == 0, "event counts")
	_check(r.session_count() == 3, "three sessions")
	_check(r.session_summary("s1")["seconds"] == 9.0 and r.session_summary("s1")["events"] == 3, "a session summary has its length")
	_check(r.funnel(&"missing").is_empty(), "an unknown funnel is empty")
	r.record_error("net.timeout", "s1")
	r.record_error("net.timeout", "s2")
	r.record_error("ui.null", "s2", true)
	var top := r.top_errors(1)
	_check(top.size() == 1 and top[0]["code"] == "net.timeout" and top[0]["count"] == 2, "top errors, commonest first")
	_check(is_equal_approx(r.crash_free_rate(), 2.0 / 3.0), "crash-free rate counts sessions, not errors")
	var cap := GSTelemetryRollup.new()
	cap.max_sessions = 1
	cap.record(&"a", "x")
	cap.record(&"a", "y")
	_check(cap.session_count() == 1 and cap.untracked == 1 and cap.count(&"a") == 2, "max_sessions bounds tracking and counts what it skipped")
	_sections += 1


func _node() -> void:
	var t := GSTelemetry.new()
	add_child(t)
	t.schema.declare(&"jump", {"height": "float"})
	t.start_session("abc")
	var off := t.track(&"jump", {"height": 1.0})
	_check(off.ok and off.value == false and t.queue.size() == 0, "off by default: nothing is queued")
	t.set_enabled(true)
	t.config.batch_size = 2
	_check(t.track(&"jump", {"height": 1.0}).value == true, "once on, an event is queued")
	_check(not t.track(&"jump", {"high": 1.0}).ok, "a schema violation fails loudly")
	_check(not t.track(&"unknown", {}).ok, "an undeclared event fails while allow_unknown_events is off")
	t.config.allow_unknown_events = true
	_check(t.track(&"unknown", {"x": 1}).value == true, "allow_unknown_events lets it through as is")
	t.track(&"jump", {"height": 2.0})
	var got: Array = []
	t.batch_ready.connect(func(b: Array) -> void: got.append(b))
	var batch := t.flush()
	_check(batch.size() == 2 and got.size() == 1 and batch[0]["e"] == &"jump" and batch[0]["s"] == "abc", "flush announces a batch of batch_size")
	t.shipped(false, batch)
	_check(t.queue.size() == 3, "a failed batch goes back")
	t.set_enabled(false)
	_check(t.queue.size() == 0 and t.flush().is_empty(), "the off switch discards what was unsent")
	t.set_enabled(true)
	t.config.sample_rate = 0.0
	t.start_session("zzz")
	_check(t.track(&"jump", {"height": 1.0}).value == false, "an unsampled session records nothing")
	_check(GSTelemetry.sampled("id", 1.0) and not GSTelemetry.sampled("id", 0.0), "sample rate 1 and 0 are always and never")
	_check(GSTelemetry.sampled("same", 0.5) == GSTelemetry.sampled("same", 0.5), "sampling is stable for an id")
	var yes := 0
	for i in 2000:
		if GSTelemetry.sampled("session-%d" % i, 0.25):
			yes += 1
	_check(yes > 350 and yes < 650, "a 0.25 rate picks about a quarter", str(yes))
	t.queue_free()
	_sections += 1


func _layers() -> void:
	var c := GSTelemetryConfig.new()
	var applied := c.apply_dictionary({"flush_seconds": 5, "enabled": true, "max_queue": 0})
	_check(applied.size() == 3 and c.flush_seconds == 5 and c.enabled and c.max_queue == 0, "a dictionary layer sets every type", str(applied))
	var r := GSTelemetryConfig.from_files()
	_check(r.ok and r.value is GSTelemetryConfig, "from_files returns a config")
	_check((r.value as GSTelemetryConfig).describe().begins_with("telemetry off"), "describe says what it is, and that it is off")
	_check(c.env_prefix() == "DOT_TELEMETRY_" and c.cli_prefix() == "--telemetry-", "env and command-line prefixes")
	_sections += 1


func _resilience() -> void:
	var q := GSTelemetryQueue.new(3)
	for i in 5:
		q.push(i)
	_check(q.size() == 3 and q.dropped == 2 and q.to_array() == [2, 3, 4], "a full queue drops the oldest through the head index")
	_check(q.take(2) == [2, 3] and q.size() == 1, "take after a drop")
	q.requeue([8, 9])
	_check(q.to_array() == [8, 9, 4] and q.dropped == 2, "requeue keeps order within the bound")
	q.requeue([1, 2])
	_check(q.to_array() == [1, 2, 8] and q.dropped == 4, "requeue over the bound drops the newest")
	var r := GSTelemetryQueue.new(2)
	r.load_array([1, 2, 3, 4])
	_check(r.to_array() == [3, 4] and r.dropped == 2, "load_array honours the bound and counts")
	var big := GSTelemetryQueue.new(0)
	for i in 10000:
		big.push(i)
	_check(big.take(0).size() == 10000 and big.size() == 0, "capacity 0 is unlimited")
	var t := GSTelemetry.new()
	t.config.flush_seconds = 10
	t.config.max_backoff_seconds = 60
	_check(t.next_flush_seconds() == 10.0, "no failures, normal interval")
	t.shipped(false, [])
	t.shipped(false, [])
	_check(t.failures() == 2 and t.next_flush_seconds() == 40.0, "the wait doubles per failure")
	for i in 10:
		t.shipped(false, [])
	_check(t.next_flush_seconds() == 60.0, "and stops at max_backoff_seconds")
	t.shipped(true, [])
	_check(t.failures() == 0 and t.next_flush_seconds() == 10.0, "a success resets it")
	t.config.max_backoff_seconds = 0
	t.shipped(false, [])
	_check(t.next_flush_seconds() == 10.0, "backoff 0 keeps the interval")
	t.config.max_queue = -1
	_check(not t.config.validate().ok, "a negative limit is refused")
	t.free()
	_sections += 1


func _check(ok: bool, what: String, extra: String = "") -> void:
	if ok:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FAIL  ", what, "  ", extra)
