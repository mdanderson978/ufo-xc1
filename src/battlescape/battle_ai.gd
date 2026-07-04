class_name BattleAI
extends RefCounted
## First-pass alien AI for the headless tactical loop. It deliberately acts
## through BattleState actions so UI, tests, and future AI share one rules path.

const MAX_MOVE_STEPS := 6
const MOVE_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

static func run_alien_turn(state: BattleState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if state.active_team != BattleUnit.TEAM_ALIEN or state.outcome != BattleState.OUTCOME_ACTIVE:
		return actions

	var aliens := state.living_units(BattleUnit.TEAM_ALIEN)
	for alien: BattleUnit in aliens:
		if state.outcome != BattleState.OUTCOME_ACTIVE or not alien.is_alive():
			continue
		var action := _act_with_alien(state, alien)
		if not action.is_empty():
			actions.append(action)
	return actions

static func _act_with_alien(state: BattleState, alien: BattleUnit) -> Dictionary:
	var visible_target := _nearest_visible_enemy(state, alien)
	if visible_target != null:
		var attack_result := state.attack_unit(alien.id, visible_target.id, "snap")
		attack_result["actor"] = alien.id
		attack_result["target"] = visible_target.id
		attack_result["type"] = "attack"
		return attack_result

	var nearest_enemy := _nearest_living_enemy(state, alien)
	if nearest_enemy == null:
		return {}
	var path := _find_path_toward(state, alien.pos, nearest_enemy.pos, alien.tu_current, MAX_MOVE_STEPS)
	if path.is_empty():
		return {"ok": true, "type": "wait", "actor": alien.id}
	var move_result := state.move_unit(alien.id, path)
	move_result["actor"] = alien.id
	move_result["type"] = "move"
	return move_result

static func _nearest_visible_enemy(state: BattleState, alien: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	var best_distance := INF
	for enemy: BattleUnit in state.living_units(BattleUnit.TEAM_XCOM):
		if not state.spotted_enemies[BattleUnit.TEAM_ALIEN].has(enemy.id):
			continue
		if not BattleRules.can_see(state.map, alien.pos, enemy.pos, int(alien.stats.get("vision_range", 20))):
			continue
		var distance := alien.pos.distance_squared_to(enemy.pos)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best

static func _nearest_living_enemy(state: BattleState, alien: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	var best_distance := INF
	for enemy: BattleUnit in state.living_units(BattleUnit.TEAM_XCOM):
		var distance := alien.pos.distance_squared_to(enemy.pos)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best

static func _find_path_toward(
		state: BattleState,
		start: Vector2i,
		goal: Vector2i,
		max_tu: int,
		max_steps: int) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0}
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		for direction: Vector2i in MOVE_DIRS:
			var next := current + direction
			if not state.map.is_walkable(next):
				continue
			var occupant := state.unit_at(next)
			if occupant != null and next != goal:
				continue
			if next == goal:
				continue
			var step_cost := BattleRules.step_tu_cost(state.map, current, next)
			var new_cost := int(cost_so_far[current]) + step_cost
			if step_cost < 0 or new_cost > max_tu:
				continue
			if not cost_so_far.has(next) or new_cost < int(cost_so_far[next]):
				cost_so_far[next] = new_cost
				came_from[next] = current
				frontier.append(next)

	var best_tile := start
	var best_distance := start.distance_squared_to(goal)
	for pos: Vector2i in came_from:
		if pos == start:
			continue
		var distance := pos.distance_squared_to(goal)
		if distance < best_distance:
			best_tile = pos
			best_distance = distance
	if best_tile == start:
		return []

	var reversed_path: Array[Vector2i] = []
	var current := best_tile
	while current != start:
		reversed_path.append(current)
		current = came_from[current]
	reversed_path.reverse()
	if reversed_path.size() > max_steps:
		reversed_path.resize(max_steps)
	return reversed_path
