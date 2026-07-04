extends Control
## Placeholder main menu. Real theme/title art arrive in Phase 5;
## the button wiring is permanent.

func _ready() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/ui/title_key_art.webp")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Darken the left side so menu text stays readable over the art.
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)

	var title := Label.new()
	title.text = "UFO: XC1"
	title.add_theme_font_size_override("font_size", 72)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "pre-alpha development build"
	subtitle.modulate = Color(1, 1, 1, 0.5)
	layout.add_child(subtitle)

	layout.add_child(HSeparator.new())

	_add_button(layout, "New Campaign", _on_new_campaign)
	_add_button(layout, "Continue", _on_continue)
	_add_button(layout, "Skirmish (debug)", _on_skirmish)
	_add_button(layout, "Quit", _on_quit)

func _add_button(parent: Container, text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 48)
	button.pressed.connect(handler)
	parent.add_child(button)

func _on_new_campaign() -> void:
	GameState.new_campaign()
	# Geoscape lands in Phase 3; until then this is a stub.
	print("New campaign started (geoscape not yet implemented)")

func _on_continue() -> void:
	var slots := SaveManager.list_saves()
	if slots.is_empty():
		print("No saves found")
		return
	SaveManager.load_campaign(slots[slots.size() - 1])

func _on_skirmish() -> void:
	EventBus.screen_change_requested.emit("battlescape", {"seed": 1001, "ufo": "small_scout"})

func _on_quit() -> void:
	get_tree().quit()
