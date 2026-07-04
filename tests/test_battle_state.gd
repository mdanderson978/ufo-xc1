extends GutTest
## Phase 2 battle controller: mission state, turn flow, visibility, actions,
## and win/loss outcomes.

var terrain: Dictionary
var items: Dictionary

func before_each() -> void:
	terrain = DataRegistry.get_table("terrain")
	items = DataRegistry.get_table("items")

func test_from_crash_site_places_squad_and_alien_crew() -> void:
	var soldiers := [_soldier_record(1), _soldier_record(2), _soldier_record(3)]
	var state := BattleState.from_crash_site(DataRegistry, "small_scout", soldiers, 77)
	assert_eq(state.active_team, BattleUnit.TEAM_XCOM)
	assert_eq(state.turn_number, 1)
	assert_eq(state.living_units(BattleUnit.TEAM_XCOM).size(), soldiers.size())
	assert_gt(state.living_units(BattleUnit.TEAM_ALIEN).size(), 0)
	for unit: BattleUnit in state.living_units():
		assert_true(state.map.is_walkable(unit.pos), "%s spawned on blocked tile" % unit.id)

func test_begin_battle_builds_visibility_and_spotted_enemies() -> void:
	var state := _simple_state()
	state.begin_battle()
	assert_true(state.is_visible_to(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))
	assert_true(state.has_seen(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))
	assert_true(state.spotted_enemies[BattleUnit.TEAM_XCOM].has("sectoid_1"))

func test_visibility_respects_blocking_terrain() -> void:
	var map := BattleMap.new(8, 3, terrain)
	map.set_obstacle(Vector2i(3, 1), "hedge")
	var state := BattleState.create(map, items, 1)
	assert_eq(state.add_unit(BattleUnit.from_soldier(_soldier_record(1), Vector2i(1, 1))), OK)
	assert_eq(state.add_unit(BattleUnit.from_alien("sectoid_1", DataRegistry.get_record("aliens", "sectoid_soldier"), Vector2i(5, 1))), OK)
	state.begin_battle()
	assert_false(state.is_visible_to(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))
	assert_false(state.has_seen(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))
	assert_false(state.spotted_enemies[BattleUnit.TEAM_XCOM].has("sectoid_1"))

func test_discovered_tiles_remember_previous_visibility() -> void:
	var map := BattleMap.new(8, 3, terrain)
	map.set_obstacle(Vector2i(3, 1), "hedge")
	var state := BattleState.create(map, items, 2)
	state.reaction_fire_enabled = false
	assert_eq(state.add_unit(BattleUnit.from_soldier(_soldier_record(1), Vector2i(1, 1))), OK)
	assert_eq(state.add_unit(BattleUnit.from_alien("sectoid_1", DataRegistry.get_record("aliens", "sectoid_soldier"), Vector2i(5, 1))), OK)
	state.begin_battle()
	assert_false(state.is_visible_to(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))
	assert_false(state.has_seen(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))

	assert_true(state.map.damage_obstacle(Vector2i(3, 1), 99))
	var scout_result := state.move_unit("xcom_1", [Vector2i(2, 1)])
	assert_true(scout_result["ok"])
	assert_true(state.is_visible_to(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))
	assert_true(state.has_seen(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))

	state.map.set_obstacle(Vector2i(3, 1), "hedge")
	var fallback_result := state.move_unit("xcom_1", [Vector2i(1, 1)])
	assert_true(fallback_result["ok"])
	assert_false(state.is_visible_to(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))
	assert_true(state.has_seen(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))
	assert_true(state.discovered_tile_list(BattleUnit.TEAM_XCOM).has(Vector2i(5, 1)))
	assert_true(state.serialize()["discovered_tiles"][BattleUnit.TEAM_XCOM].has([5, 1]))

func test_end_turn_flips_team_and_refreshes_tu() -> void:
	var state := _simple_state()
	state.begin_battle()
	var alien := state.get_unit("sectoid_1")
	alien.tu_current = 0
	var result := state.end_turn()
	assert_true(result["ok"])
	assert_eq(state.active_team, BattleUnit.TEAM_ALIEN)
	assert_eq(alien.tu_current, int(alien.stats["tu"]))
	result = state.end_turn()
	assert_true(result["ok"])
	assert_eq(state.active_team, BattleUnit.TEAM_XCOM)
	assert_eq(state.turn_number, 2)

func test_move_unit_rejects_inactive_and_occupied_tiles() -> void:
	var state := _simple_state()
	state.reaction_fire_enabled = false
	state.begin_battle()
	var alien_move := state.move_unit("sectoid_1", [Vector2i(4, 1)])
	assert_false(alien_move["ok"], "alien cannot move during XCOM turn")
	var occupied := state.move_unit("xcom_1", [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)])
	assert_false(occupied["ok"], "unit cannot move into occupied enemy tile")

func test_move_unit_spends_tu_and_refreshes_visibility() -> void:
	var state := _simple_state()
	state.reaction_fire_enabled = false
	state.begin_battle()
	var unit := state.get_unit("xcom_1")
	var before := unit.tu_current
	var result := state.move_unit("xcom_1", [Vector2i(2, 1)])
	assert_true(result["ok"])
	assert_eq(unit.pos, Vector2i(2, 1))
	assert_eq(unit.tu_current, before - int(terrain["grass"]["tu_cost"]))
	assert_true(state.is_visible_to(BattleUnit.TEAM_XCOM, Vector2i(5, 1)))
	assert_eq(result["reactions"].size(), 0)

func test_reaction_fire_triggers_on_visible_movement() -> void:
	var state := _reaction_state(35, 7)
	state.begin_battle()
	var alien := state.get_unit("sectoid_1")
	var before_alien_tu := alien.tu_current
	var result := state.move_unit("xcom_1", [Vector2i(2, 1)])
	assert_true(result["ok"])
	assert_gt(result["reactions"].size(), 0)
	var fired := false
	for reaction: Dictionary in result["reactions"]:
		if reaction.get("type") == "reaction_fire":
			fired = true
	assert_true(fired, "expected alien reaction fire")
	assert_lt(alien.tu_current, before_alien_tu)

func test_reaction_fire_can_kill_mover_and_stop_path() -> void:
	var state := _reaction_state(1, 7)
	state.begin_battle()
	var result := state.move_unit("xcom_1", [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)])
	assert_true(result["ok"])
	assert_eq(state.get_unit("xcom_1").health_current, 0)
	assert_eq(state.get_unit("xcom_1").pos, Vector2i(2, 1))
	assert_eq(state.outcome, BattleState.OUTCOME_ALIEN_WIN)

func test_attack_unit_updates_outcome_when_last_alien_dies() -> void:
	var state := _simple_state()
	state.begin_battle()
	var target := state.get_unit("sectoid_1")
	target.health_current = 1
	var result := {}
	for i in range(10):
		if state.outcome != BattleState.OUTCOME_ACTIVE:
			break
		state.get_unit("xcom_1").tu_current = 60
		result = state.attack_unit("xcom_1", "sectoid_1", "aimed")
		assert_true(result["ok"])
	assert_eq(target.health_current, 0)
	assert_eq(state.outcome, BattleState.OUTCOME_XCOM_WIN)
	assert_eq(result["outcome"], BattleState.OUTCOME_XCOM_WIN)
	assert_eq(state.get_unit("xcom_1").kills_current, 1)

func test_death_reduces_living_allies_morale() -> void:
	var state := _morale_state(11)
	state.begin_battle()
	state.end_turn()
	var ally := state.get_unit("xcom_2")
	var before := ally.morale_current
	var result := state.attack_unit("sectoid_1", "xcom_1", "snap")
	assert_true(result["ok"])
	assert_eq(state.get_unit("xcom_1").health_current, 0)
	assert_lt(ally.morale_current, before)
	assert_gt(result["morale_events"].size(), 0)
	assert_eq(result["morale_events"][0]["type"], "morale_loss")

func test_low_morale_unit_can_panic_on_turn_start() -> void:
	var state := _morale_state(1)
	state.begin_battle()
	state.get_unit("xcom_2").morale_current = 0
	state.get_unit("xcom_2").stats["bravery"] = -100
	state.end_turn()
	var result := state.end_turn()
	assert_true(result["ok"])
	assert_eq(state.active_team, BattleUnit.TEAM_XCOM)
	assert_gt(result["morale_events"].size(), 0)
	assert_eq(result["morale_events"][0]["type"], "panic")
	assert_true(state.get_unit("xcom_2").panicked_this_turn)
	assert_eq(state.get_unit("xcom_2").tu_current, 0)

func test_battle_result_recovers_ufo_loot_and_alien_corpses() -> void:
	var state := _simple_state()
	state.ufo_id = "small_scout"
	state.mission_recovery_loot = {"alien_alloys": 2}
	state.begin_battle()
	var target := state.get_unit("sectoid_1")
	target.health_current = 1
	var result := {}
	for i in range(10):
		if state.outcome != BattleState.OUTCOME_ACTIVE:
			break
		state.get_unit("xcom_1").tu_current = 60
		result = state.attack_unit("xcom_1", "sectoid_1", "aimed")
		assert_true(result["ok"])
	var battle_result := state.battle_result()
	assert_eq(battle_result["outcome"], BattleState.OUTCOME_XCOM_WIN)
	assert_eq(battle_result["ufo_id"], "small_scout")
	assert_eq(battle_result["score_xcom"], 10)
	assert_eq(battle_result["xcom_kills"]["xcom_1"], 1)
	assert_eq(battle_result["recovered_items"]["alien_alloys"], 2)
	assert_eq(battle_result["recovered_items"]["sectoid_corpse"], 1)
	assert_true(battle_result.has("morale_events"))

func test_alien_win_when_last_xcom_unit_is_dead() -> void:
	var state := _simple_state()
	state.begin_battle()
	state.get_unit("xcom_1").health_current = 0
	state.end_turn()
	assert_eq(state.outcome, BattleState.OUTCOME_ALIEN_WIN)

func test_battle_result_recovers_no_loot_on_alien_win() -> void:
	var state := _simple_state()
	state.mission_recovery_loot = {"alien_alloys": 2}
	state.begin_battle()
	state.get_unit("xcom_1").health_current = 0
	state.end_turn()
	var battle_result := state.battle_result()
	assert_eq(battle_result["outcome"], BattleState.OUTCOME_ALIEN_WIN)
	assert_true(battle_result["recovered_items"].is_empty())
	assert_eq(battle_result["xcom_losses"].size(), 1)

func _simple_state() -> BattleState:
	var map := BattleMap.new(8, 3, terrain)
	var state := BattleState.create(map, items, 4)
	assert_eq(state.add_unit(BattleUnit.from_soldier(_soldier_record(1), Vector2i(1, 1))), OK)
	assert_eq(state.add_unit(BattleUnit.from_alien("sectoid_1", DataRegistry.get_record("aliens", "sectoid_soldier"), Vector2i(5, 1))), OK)
	return state

func _reaction_state(xcom_health: int, seed: int) -> BattleState:
	var reaction_items := items.duplicate(true)
	reaction_items["reaction_test_gun"] = {
		"name": "Reaction Test Gun",
		"category": "weapon",
		"damage": 99,
		"accuracy": {"snap": 200},
		"tu_percent": {"snap": 1}
	}
	var map := BattleMap.new(8, 3, terrain)
	var state := BattleState.create(map, reaction_items, seed)
	var soldier := _soldier_record(1)
	soldier["stats"]["health"] = xcom_health
	soldier["stats"]["reactions"] = 0
	assert_eq(state.add_unit(BattleUnit.from_soldier(soldier, Vector2i(1, 1))), OK)

	var alien_data := DataRegistry.get_record("aliens", "sectoid_soldier").duplicate(true)
	var alien_stats: Dictionary = alien_data["stats"].duplicate(true)
	alien_stats["reactions"] = 100
	alien_stats["firing_accuracy"] = 200
	alien_data["stats"] = alien_stats
	alien_data["loadout"] = {"right_hand": "reaction_test_gun"}
	assert_eq(state.add_unit(BattleUnit.from_alien("sectoid_1", alien_data, Vector2i(5, 1))), OK)
	return state

func _morale_state(seed: int) -> BattleState:
	var morale_items := items.duplicate(true)
	morale_items["morale_test_gun"] = {
		"name": "Morale Test Gun",
		"category": "weapon",
		"damage": 99,
		"accuracy": {"snap": 200},
		"tu_percent": {"snap": 1}
	}
	var map := BattleMap.new(8, 3, terrain)
	var state := BattleState.create(map, morale_items, seed)
	var soldier_1 := _soldier_record(1)
	soldier_1["stats"]["health"] = 1
	var soldier_2 := _soldier_record(2)
	soldier_2["stats"]["bravery"] = 0
	assert_eq(state.add_unit(BattleUnit.from_soldier(soldier_1, Vector2i(1, 1))), OK)
	assert_eq(state.add_unit(BattleUnit.from_soldier(soldier_2, Vector2i(1, 2))), OK)

	var alien_data := DataRegistry.get_record("aliens", "sectoid_soldier").duplicate(true)
	var alien_stats: Dictionary = alien_data["stats"].duplicate(true)
	alien_stats["firing_accuracy"] = 200
	alien_data["stats"] = alien_stats
	alien_data["loadout"] = {"right_hand": "morale_test_gun"}
	assert_eq(state.add_unit(BattleUnit.from_alien("sectoid_1", alien_data, Vector2i(5, 1))), OK)
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
			"firing_accuracy": 120,
			"throwing_accuracy": 60,
			"strength": 30,
			"melee_accuracy": 30,
			"vision_range": 20
		},
		"loadout": {"right_hand": "rifle"}
	}
