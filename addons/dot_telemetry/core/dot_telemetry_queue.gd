class_name DotTelemetryQueue
extends RefCounted

## Events waiting to ship. Bounded on purpose, and loud about it: when it is full the oldest event is dropped and [member dropped] counts it, so a backed-up endpoint costs history and never memory.

## Most events held; 0 is unlimited.
var capacity: int = 0
## Events lost to the bound since the queue was made.
var dropped: int = 0

var _items: Array = []


func _init(p_capacity: int = 0) -> void:
	capacity = p_capacity


func size() -> int:
	return _items.size()


func push(item: Variant) -> void:
	_items.append(item)
	if capacity > 0:
		while _items.size() > capacity:
			_items.pop_front()
			dropped += 1


## Take up to [param n] events from the front; 0 takes all.
func take(n: int = 0) -> Array:
	var count := _items.size() if n <= 0 else mini(n, _items.size())
	var out := _items.slice(0, count)
	_items = _items.slice(count)
	return out


## Put a batch whose shipping failed back at the front, in order, still within the bound.
func requeue(batch: Array) -> void:
	_items = batch + _items
	if capacity > 0:
		while _items.size() > capacity:
			_items.pop_back()
			dropped += 1


func clear() -> int:
	var n := _items.size()
	_items.clear()
	return n
