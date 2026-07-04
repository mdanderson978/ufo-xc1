extends Node
## Top-level screen router. Owns exactly one active screen at a time and
## swaps them on EventBus.screen_change_requested.

const SCREENS := {
	"main_menu": "res://src/ui/main_menu.tscn",
	"battlescape": "res://src/battlescape/battlescape.tscn",
	# Registered as the phases land:
	# "geoscape": "res://src/geoscape/geoscape.tscn",
	# "basescape": "res://src/basescape/basescape.tscn",
	# "debrief": "res://src/ui/debrief.tscn",
}

var _current_screen: Node = null

func _ready() -> void:
	EventBus.screen_change_requested.connect(_on_screen_change_requested)
	_show_screen("main_menu", {})

func _on_screen_change_requested(screen_id: String, payload: Dictionary) -> void:
	_show_screen(screen_id, payload)

func _show_screen(screen_id: String, payload: Dictionary) -> void:
	if not SCREENS.has(screen_id):
		push_error("Main: unknown screen '%s'" % screen_id)
		return
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null
	var scene: PackedScene = load(SCREENS[screen_id])
	_current_screen = scene.instantiate()
	add_child(_current_screen)
	if _current_screen.has_method("setup"):
		_current_screen.setup(payload)
