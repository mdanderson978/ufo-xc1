extends GutTest
## Phase 2 alien AI: fire at visible XCOM units, otherwise advance.

const BattleAIScript := preload("res://src/battlescape/battle_ai.gd")

var terrain: Dictionary
var items: Dictionary

func before_each() -> void:
	terrain = DataRegistry.get_table("terrain")
	items = DataRegistry.get_table("items")

func test_visible_alien_fires_snap_shot() -> void:
	var state := _simple_state(Vector2i(5, 1), false)
	state.begin_battle()
	state.end_turn()
	var alien := state.get_unit("sectoid_1")
	var before_tu := alien.tu_current
	var before_health := state.get_unit("xcom_1").health_current

	var actions: Array[Dictionary] = BattleAIScript.run_alien_turn(state)
	assert_eq(actions.size(), 1)
	assert_eq(actions[0]["type"], "attack")
	assert_true(actions[0]["ok"])
	assert_lt(alien.tu_current, before_tu)
	assert_lte(state.get_unit("xcom_1").health_current, before_health)

func test_unseen_alien_moves_toward_nearest_xcom() -> void:
	var state := _simple_state(Vector2i(7, 1), true)
	state.begin_battle()
	state.end_turn()
	var alien := state.get_unit("sectoid_1")
	var before_pos := alien.pos
	var before_distance := before_pos.distance_squared_to(state.get_unit("xcom_1").pos)

	var actions: Array[Dictionary] = BattleAIScript.run_alien_turn(state)
	assert_eq(actions.size(), 1)
	assert_eq(actions[0]["type"], "move")
	assert_true(actions[0]["ok"])
	assert_ne(alien.pos, before_pos)
	assert_lt(alien.pos.distance_squared_to(state.get_unit("xcom_1").pos), before_distance)

func test_ai_does_nothing_outside_alien_turn() -> void:
	var state := _simple_state(Vector2i(5, 1), false)
	state.begin_battle()
	assert_eq(BattleAIScript.run_alien_turn(state).size(), 0)

func _simple_state(alien_pos: Vector2i, block_los: bool) -> BattleState:
	var map := BattleMap.new(10, 3, terrain)
	if block_los:
		map.set_obstacle(Vector2i(4, 1), "hedge")
	var state := BattleState.create(map, items, 12)
	assert_eq(state.add_unit(BattleUnit.from_soldier(_soldier_record(1), Vector2i(1, 1))), OK)
	assert_eq(state.add_unit(BattleUnit.from_alien("sectoid_1", DataRegistry.get_record("aliens", "sectoid_soldier"), alien_pos)), OK)
	return state

func _soldier_record(id: int) -> Dictionary:
	return {
		"id": id,
		"name": "Test Soldier %d" % id,
		"stats": {
			"tu": 60,
			"stamina": 55,
			"health": 35,
			"bravery": 50,
			"reactions": 50,
			"firing_accuracy": 70,
			"throwing_accuracy": 60,
			"strength": 30,
			"melee_accuracy": 30,
			"vision_range": 20
		},
		"loadout": {"right_hand": "rifle"}
	}
