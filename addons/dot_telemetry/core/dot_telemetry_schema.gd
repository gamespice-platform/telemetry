class_name DotTelemetrySchema
extends RefCounted

## The events a game reports, declared once: a name and a typed field list. Anything that does not fit is refused with a reason, so a typo shows up in the first run and not as a hole in a dashboard.

const TYPES: Array[StringName] = [&"int", &"float", &"bool", &"string"]

var _events: Dictionary = {}


## Declare an event. [param fields] maps a field name to one of [constant TYPES]. Event and field names are lowercase `a-z0-9_.`.
func declare(event: StringName, fields: Dictionary = {}) -> DotResult:
	if not _name_ok(str(event)):
		return DotResult.fail(DotError.CODE_INVALID, "event name '%s' must be lowercase a-z, 0-9, _ or ." % event)
	for f: Variant in fields:
		if not _name_ok(str(f)):
			return DotResult.fail(DotError.CODE_INVALID, "field name '%s' of %s is not a valid name" % [f, event])
		if not TYPES.has(StringName(str(fields[f]))):
			return DotResult.fail(DotError.CODE_INVALID, "field %s.%s has unknown type '%s'" % [event, f, fields[f]])
	_events[event] = fields.duplicate()
	return DotResult.success(event)


func has(event: StringName) -> bool:
	return _events.has(event)


func event_names() -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in _events:
		out.append(str(k))
	out.sort()
	return out


## Check [param props] against the declaration. Success carries a clean copy; failure names the event and field.
## [param max_string] is the longest string allowed, 0 for any length.
func validate(event: StringName, props: Dictionary, max_string: int = 0) -> DotResult:
	if not _events.has(event):
		return DotResult.fail(DotError.CODE_INVALID, "event '%s' is not declared" % event)
	var fields: Dictionary = _events[event]
	var out := {}
	for f: Variant in fields:
		if not props.has(f):
			return DotResult.fail(DotError.CODE_INVALID, "%s is missing field '%s'" % [event, f])
		var v: Variant = props[f]
		var want := StringName(str(fields[f]))
		if not _type_ok(want, v):
			return DotResult.fail(DotError.CODE_INVALID, "%s.%s wants %s, got %s" % [event, f, want, type_string(typeof(v))])
		if want == &"string" and max_string > 0 and str(v).length() > max_string:
			return DotResult.fail(DotError.CODE_INVALID, "%s.%s is %d characters, over the limit of %d" % [event, f, str(v).length(), max_string])
		out[f] = v
	for p: Variant in props:
		if not fields.has(p):
			return DotResult.fail(DotError.CODE_INVALID, "%s has undeclared field '%s'" % [event, p])
	return DotResult.success(out)


static func _type_ok(want: StringName, v: Variant) -> bool:
	match want:
		&"int": return typeof(v) == TYPE_INT
		&"float": return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT
		&"bool": return typeof(v) == TYPE_BOOL
		&"string": return typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME
	return false


static func _name_ok(s: String) -> bool:
	if s.is_empty():
		return false
	for i in s.length():
		var c := s.unicode_at(i)
		if not ((c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 46):
			return false
	return true
