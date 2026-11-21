class_name DotTelemetryRollup
extends RefCounted

## What the numbers add up to, computed locally and cheaply: event counts, sessions, ordered funnels, and error and crash summaries.

## Sessions tracked at most; 0 is unlimited. Past it a new session is counted in [member untracked] and left out of funnels.
var max_sessions: int = 0
var untracked: int = 0

var _counts: Dictionary = {}
var _sessions: Dictionary = {}   # id -> {first, last, events, fatal}
var _funnels: Dictionary = {}    # name -> Array[StringName]
var _progress: Dictionary = {}   # name -> {session -> next step index}
var _errors: Dictionary = {}     # code -> count


## A funnel is an ordered list of events; a session passes step i once it has done steps 0 to i in that order.
func define_funnel(funnel: StringName, steps: Array) -> DotResult:
	if steps.size() < 2:
		return DotResult.fail(DotError.CODE_INVALID, "funnel '%s' needs at least two steps" % funnel)
	_funnels[funnel] = steps.duplicate()
	_progress[funnel] = {}
	return DotResult.success(funnel)


func record(event: StringName, session: String, t: float = 0.0) -> void:
	_counts[event] = int(_counts.get(event, 0)) + 1
	var s := _session(session, t)
	if s.is_empty():
		return
	s["last"] = t
	s["events"] = int(s["events"]) + 1
	for funnel: Variant in _funnels:
		var steps: Array = _funnels[funnel]
		var prog: Dictionary = _progress[funnel]
		var at := int(prog.get(session, 0))
		if at < steps.size() and steps[at] == event:
			prog[session] = at + 1


## An error seen in a session; [param fatal] marks a crash and takes that session out of the crash-free rate.
func record_error(code: String, session: String = "", fatal: bool = false, t: float = 0.0) -> void:
	_errors[code] = int(_errors.get(code, 0)) + 1
	if fatal and session != "":
		var s := _session(session, t)
		if not s.is_empty():
			s["fatal"] = true


func count(event: StringName) -> int:
	return int(_counts.get(event, 0))


func session_count() -> int:
	return _sessions.size()


## Sessions that reached each step of a funnel, in order. Empty for an unknown funnel.
func funnel(name: StringName) -> Array[int]:
	var out: Array[int] = []
	if not _funnels.has(name):
		return out
	var steps: Array = _funnels[name]
	out.resize(steps.size())
	out.fill(0)
	for sid: Variant in (_progress[name] as Dictionary):
		for i in int(_progress[name][sid]):
			out[i] += 1
	return out


## The commonest errors first, ties by code. [param n] 0 returns all.
func top_errors(n: int = 0) -> Array:
	var rows: Array = []
	for code: Variant in _errors:
		rows.append({"code": code, "count": _errors[code]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["count"] > b["count"] or (a["count"] == b["count"] and str(a["code"]) < str(b["code"])))
	return rows if n <= 0 else rows.slice(0, n)


## Share of tracked sessions without a fatal error; 1.0 with no sessions.
func crash_free_rate() -> float:
	if _sessions.is_empty():
		return 1.0
	var bad := 0
	for sid: Variant in _sessions:
		if bool(_sessions[sid]["fatal"]):
			bad += 1
	return 1.0 - float(bad) / float(_sessions.size())


func session_summary(session: String) -> Dictionary:
	if not _sessions.has(session):
		return {}
	var s: Dictionary = _sessions[session]
	return {"events": s["events"], "seconds": float(s["last"]) - float(s["first"]), "fatal": s["fatal"]}


func _session(id: String, t: float) -> Dictionary:
	if _sessions.has(id):
		return _sessions[id]
	if max_sessions > 0 and _sessions.size() >= max_sessions:
		untracked += 1
		return {}
	var s := {"first": t, "last": t, "events": 0, "fatal": false}
	_sessions[id] = s
	return s
