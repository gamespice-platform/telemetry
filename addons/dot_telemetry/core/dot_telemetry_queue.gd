class_name DotTelemetryQueue
extends DotBoundedBuffer

## Events waiting to ship. Bounded on purpose, and loud about it: when it is full the oldest event is dropped and [member dropped] counts it, so a backed-up endpoint costs history and never memory. The storage is the shared [DotBoundedBuffer] (a head index, no front shifts); this class only sets the telemetry rule that a requeued batch over the bound loses its newest events, so the history that already failed to ship is kept.

func _init(p_capacity: int = 0) -> void:
	capacity = maxi(0, p_capacity)


## Put a batch whose shipping failed back at the front, in order, still within the bound; over it the newest are dropped.
func requeue(batch: Array, keep_oldest: bool = true) -> void:
	super.requeue(batch, keep_oldest)
