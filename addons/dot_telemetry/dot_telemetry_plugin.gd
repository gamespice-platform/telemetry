@tool
extends EditorPlugin

## Editor entry point for GameSpice Telemetry. No autoloads: a game owns its telemetry node and decides when it starts.


func _enter_tree() -> void:
	add_custom_type("DotTelemetry", "Node", load("res://addons/dot_telemetry/runtime/dot_telemetry.gd"), null)


func _exit_tree() -> void:
	remove_custom_type("DotTelemetry")
