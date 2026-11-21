class_name DotTelemetryQueue
extends RefCounted

## Events waiting to ship. Bounded on purpose, and loud about it: when it is full the oldest event is dropped and [member dropped] counts it, so a backed-up endpoint costs history and never memory. Dropping the oldest moves a head index instead of shifting the array, so a full queue costs the same per event as an empty one; the array is compacted only when half of it is dead space.

## Most events held; 0 is unlimited.
var capacity: int = 0
## Events lost to the bound since the queue was made.
var dropped: int = 0

var _items: Array = []
var _head: int = 0


func _init(p_capacity: int = 0) -> void:
	capacity = p_capacity


func size() -> int:
	return _items.size() - _head


func push(item: Variant) -> void:
	_items.append(item)
	if capacity > 0 and size() > capacity:
		var over := size() - capacity
		_head += over
		dropped += over
		_compact()


## Take up to [param n] events from the front; 0 takes all.
func take(n: int = 0) -> Array:
	var count := size() if n <= 0 else mini(n, size())
	var out := _items.slice(_head, _head + count)
	_head += count
	_compact()
	return out


## Put a batch whose shipping failed back at the front, in order, still within the bound.
func requeue(batch: Array) -> void:
	_items = batch + _items.slice(_head)
	_head = 0
	if capacity > 0 and _items.size() > capacity:
		dropped += _items.size() - capacity
		_items.resize(capacity)


func clear() -> int:
	var n := size()
	_items.clear()
	_head = 0
	return n


## Everything waiting, in order, as a copy: what a game writes to disk so unsent events survive a restart.
func to_array() -> Array:
	return _items.slice(_head)


## Replaces the queue with [param data] (from [method to_array]). Anything over [member capacity] is dropped from the front and counted.
func load_array(data: Array) -> void:
	_items = data.duplicate()
	_head = 0
	if capacity > 0 and _items.size() > capacity:
		dropped += _items.size() - capacity
		_head = _items.size() - capacity
		_compact()


func _compact() -> void:
	if _head > 0 and (_head * 2 >= _items.size() or _head == _items.size()):
		_items = _items.slice(_head)
		_head = 0
