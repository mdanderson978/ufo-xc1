extends Control
## Debug-only Battlescape view. Renders the headless BattleState as 2D tiles
## so the tactical loop can be exercised before final 3D presentation exists.

const TILE_SIZE := 18
const MAP_ORIGIN := Vector2(24, 96)
const BattleAIScript := preload("res://src/battlescape/battle_ai.gd")
const MOVE_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

var _state: BattleState
var _selected_unit_id: String = ""
var _seed: int = 1001
var _ufo_id: String = "small_scout"
var _turn_label: Label
var _status_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	_build_chrome()
	_start_debug_battle()

func setup(payload: Dictionary) -> void:
	_seed = int(payload.get("seed", _seed))
	_ufo_id = payload.get("ufo", _ufo_id)

func _build_chrome() -> void:
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 16
	top_bar.offset_top = 12
	top_bar.offset_right = -16
	top_bar.custom_minimum_size = Vector2(0, 40)
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(func() -> void:
		EventBus.screen_change_requested.emit("main_menu", {})
	)
	top_bar.add_child(back_button)

	var new_seed_button := Button.new()
	new_seed_button.text = "New Seed"
	new_seed_button.pressed.connect(func() -> void:
		_seed += 1
		_start_debug_battle()
	)
	top_bar.add_child(new_seed_button)

	var end_turn_button := Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	top_bar.add_child(end_turn_button)

	_turn_label = Label.new()
	_turn_label.custom_minimum_size = Vector2(360, 32)
	top_bar.add_child(_turn_label)

	_status_label = Label.new()
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_status_label.offset_left = 24
	_status_label.offset_right = -24
	_status_label.offset_bottom = -24
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_status_label)

func _start_debug_battle() -> void:
	var campaign := CampaignFactory.new_campaign(DataRegistry, _seed)
	var base: Dictionary = campaign["bases"][0]
	var soldiers: Array = []
	for i in range(mini(4, base["soldiers"].size())):
		var soldier: Dictionary = base["soldiers"][i].duplicate(true)
		soldier["loadout"] = {"right_hand": "rifle"}
		soldiers.append(soldier)
	_state = BattleState.from_crash_site(DataRegistry, _ufo_id, soldiers, _seed)
	_selected_unit_id = ""
	_set_status("Select an XCOM unit, then click a tile to move or a visible alien to fire.")
	_update_turn_label()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var tile_pos := _screen_to_tile(mouse_event.position)
	if tile_pos == Vector2i(-1, -1):
		return
	_handle_tile_click(tile_pos)

func _handle_tile_click(tile_pos: Vector2i) -> void:
	if _state.outcome != BattleState.OUTCOME_ACTIVE:
		_set_status("Battle finished: %s" % _state.outcome)
		return
	var clicked_unit := _unit_at_tile(tile_pos)
	if clicked_unit != null and clicked_unit.team == BattleUnit.TEAM_XCOM and _state.active_team == BattleUnit.TEAM_XCOM:
		_selected_unit_id = clicked_unit.id
		_set_status("Selected %s. TU: %d" % [clicked_unit.name, clicked_unit.tu_current])
		queue_redraw()
		return

	var selected := _state.get_unit(_selected_unit_id)
	if selected == null or not selected.is_alive():
		_set_status("Select a living XCOM unit first.")
		return

	if clicked_unit != null and clicked_unit.team != selected.team:
		_attack_selected(clicked_unit)
		return

	var path := _find_path(selected.pos, tile_pos, selected.tu_current)
	if path.is_empty():
		_set_status("No reachable path to %s." % tile_pos)
		return
	var result := _state.move_unit(selected.id, path)
	if result.get("ok", false):
		_set_status("%s moved to %s. TU: %d%s" % [
			selected.name,
			selected.pos,
			selected.tu_current,
			_summarize_reactions(result.get("reactions", []))
		])
		if _state.outcome != BattleState.OUTCOME_ACTIVE:
			_set_status(_battle_result_summary())
	else:
		_set_status("Move failed: %s" % result.get("error"))
	_update_turn_label()
	queue_redraw()

func _attack_selected(target: BattleUnit) -> void:
	var selected := _state.get_unit(_selected_unit_id)
	if selected == null:
		return
	if not _state.spotted_enemies[selected.team].has(target.id):
		_set_status("%s is not visible to %s." % [target.name, selected.name])
		return
	var result := _state.attack_unit(selected.id, target.id, "snap")
	if result.get("ok", false):
		var hit_text := "hit" if result["hit"] else "missed"
		if _state.outcome == BattleState.OUTCOME_ACTIVE:
			_set_status("%s fired at %s: %s for %d damage. Outcome: %s" % [
				selected.name,
				target.name,
				hit_text,
				int(result["damage"]),
				result["outcome"]
			])
		else:
			_set_status(_battle_result_summary())
	else:
		_set_status("Attack failed: %s" % result.get("error"))
	_update_turn_label()
	queue_redraw()

func _on_end_turn_pressed() -> void:
	var result := _state.end_turn()
	if result.get("ok", false):
		_selected_unit_id = ""
		if _state.active_team == BattleUnit.TEAM_ALIEN and _state.outcome == BattleState.OUTCOME_ACTIVE:
			var actions: Array[Dictionary] = BattleAIScript.run_alien_turn(_state)
			if _state.outcome == BattleState.OUTCOME_ACTIVE:
				_state.end_turn()
			_set_status(_battle_result_summary() if _state.outcome != BattleState.OUTCOME_ACTIVE else _summarize_alien_actions(actions))
		else:
			_set_status(_battle_result_summary() if _state.outcome != BattleState.OUTCOME_ACTIVE else "Turn advanced. Active team: %s" % _state.active_team)
	else:
		_set_status("End turn failed: %s" % result.get("error"))
	_update_turn_label()
	queue_redraw()

func _summarize_alien_actions(actions: Array[Dictionary]) -> String:
	if actions.is_empty():
		return "Aliens hold position. Active team: %s" % _state.active_team
	var attacks := 0
	var moves := 0
	var waits := 0
	for action: Dictionary in actions:
		match String(action.get("type", "")):
			"attack":
				attacks += 1
			"move":
				moves += 1
			"wait":
				waits += 1
	return "Alien turn: %d attacks, %d moves, %d waits. Active team: %s" % [
		attacks,
		moves,
		waits,
		_state.active_team
	]

func _summarize_reactions(reactions: Array) -> String:
	if reactions.is_empty():
		return ""
	var fired := 0
	var hits := 0
	for reaction: Dictionary in reactions:
		if reaction.get("type") != "reaction_fire":
			continue
		fired += 1
		if reaction.get("hit", false):
			hits += 1
	return " | Reaction fire: %d shots, %d hits" % [fired, hits]

func _battle_result_summary() -> String:
	var result := _state.battle_result()
	var recovered := result["recovered_items"] as Dictionary
	var recovered_parts: Array[String] = []
	for item_id: String in recovered:
		recovered_parts.append("%s x%d" % [item_id, int(recovered[item_id])])
	var recovered_text := "none" if recovered_parts.is_empty() else ", ".join(recovered_parts)
	return "Battle %s | Score %d | XCOM losses %d | Aliens killed %d | Recovered: %s" % [
		result["outcome"],
		int(result["score_xcom"]),
		(result["xcom_losses"] as PackedStringArray).size(),
		(result["aliens_killed"] as PackedStringArray).size(),
		recovered_text
	]

func _draw() -> void:
	if _state == null:
		return
	_draw_map()
	_draw_units()
	_draw_selection()

func _draw_map() -> void:
	for y in range(_state.map.height):
		for x in range(_state.map.width):
			var pos := Vector2i(x, y)
			var tile: Dictionary = _state.map.tile(pos)
			var rect := Rect2(MAP_ORIGIN + Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(rect, _tile_color(tile))
			if tile["obstacle"] != null:
				draw_rect(rect.grow(-4), _obstacle_color(tile["obstacle"]))
			if not _state.is_visible_to(BattleUnit.TEAM_XCOM, pos):
				draw_rect(rect, Color(0, 0, 0, 0.55))
			draw_rect(rect, Color(0, 0, 0, 0.28), false, 1.0)

func _draw_units() -> void:
	for unit: BattleUnit in _state.living_units():
		if unit.team == BattleUnit.TEAM_ALIEN and not _state.spotted_enemies[BattleUnit.TEAM_XCOM].has(unit.id):
			continue
		var center := MAP_ORIGIN + Vector2(unit.pos.x * TILE_SIZE + TILE_SIZE * 0.5, unit.pos.y * TILE_SIZE + TILE_SIZE * 0.5)
		var color := Color(0.1, 0.55, 1.0) if unit.team == BattleUnit.TEAM_XCOM else Color(0.95, 0.2, 0.18)
		draw_circle(center, TILE_SIZE * 0.38, color)
		draw_circle(center, TILE_SIZE * 0.38, Color(0, 0, 0, 0.75), false, 2.0)

func _draw_selection() -> void:
	var unit := _state.get_unit(_selected_unit_id)
	if unit == null:
		return
	var rect := Rect2(MAP_ORIGIN + Vector2(unit.pos.x * TILE_SIZE, unit.pos.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
	draw_rect(rect.grow(2), Color(1.0, 0.85, 0.2), false, 3.0)

func _tile_color(tile: Dictionary) -> Color:
	match String(tile["ground"]):
		"wheat":
			return Color(0.72, 0.62, 0.28)
		"dirt":
			return Color(0.39, 0.27, 0.16)
		"scorched":
			return Color(0.11, 0.1, 0.09)
		"ufo_floor", "ufo_door":
			return Color(0.42, 0.48, 0.52)
		_:
			return Color(0.18, 0.42, 0.18)

func _obstacle_color(obstacle_id: String) -> Color:
	match obstacle_id:
		"fence":
			return Color(0.5, 0.31, 0.14)
		"hedge":
			return Color(0.08, 0.28, 0.09)
		"tree":
			return Color(0.04, 0.22, 0.06)
		"ufo_wall":
			return Color(0.75, 0.82, 0.86)
		_:
			return Color(0.24, 0.24, 0.24)

func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var local := screen_pos - MAP_ORIGIN
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var tile_pos := Vector2i(int(local.x / TILE_SIZE), int(local.y / TILE_SIZE))
	if not _state.map.in_bounds(tile_pos):
		return Vector2i(-1, -1)
	return tile_pos

func _find_path(start: Vector2i, goal: Vector2i, max_tu: int) -> Array[Vector2i]:
	if start == goal or not _state.map.is_walkable(goal):
		return []
	if _unit_at_tile(goal) != null:
		return []
	var frontier: Array[Vector2i] = [start]
	var came_from := {start: start}
	var cost_so_far := {start: 0}
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		if current == goal:
			break
		for direction: Vector2i in MOVE_DIRS:
			var next := current + direction
			if not _state.map.is_walkable(next):
				continue
			if next != goal and _unit_at_tile(next) != null:
				continue
			var step_cost := BattleRules.step_tu_cost(_state.map, current, next)
			var new_cost := int(cost_so_far[current]) + step_cost
			if step_cost < 0 or new_cost > max_tu:
				continue
			if not cost_so_far.has(next) or new_cost < int(cost_so_far[next]):
				cost_so_far[next] = new_cost
				came_from[next] = current
				frontier.append(next)
	if not came_from.has(goal):
		return []
	var reversed_path: Array[Vector2i] = []
	var current := goal
	while current != start:
		reversed_path.append(current)
		current = came_from[current]
	reversed_path.reverse()
	return reversed_path

func _unit_at_tile(tile_pos: Vector2i) -> BattleUnit:
	for unit: BattleUnit in _state.living_units():
		if unit.pos == tile_pos:
			return unit
	return null

func _update_turn_label() -> void:
	if _turn_label == null or _state == null:
		return
	_turn_label.text = "Turn %d  Active: %s  Outcome: %s  Seed: %d" % [
		_state.turn_number,
		_state.active_team,
		_state.outcome,
		_seed
	]

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
