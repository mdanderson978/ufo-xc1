extends GutTest
## Phase 2 tactical rules: units, TU movement, LOS, and first attack resolver.

var terrain: Dictionary
var items: Dictionary

func before_each() -> void:
	terrain = DataRegistry.get_table("terrain")
	items = DataRegistry.get_table("items")

func test_soldier_unit_starts_with_tu_and_health() -> void:
	var soldier := _soldier_record()
	var unit := BattleUnit.from_soldier(soldier, Vector2i(1, 1))
	assert_eq(unit.team, BattleUnit.TEAM_XCOM)
	assert_eq(unit.tu_current, soldier["stats"]["tu"])
	assert_eq(unit.health_current, soldier["stats"]["health"])
	assert_eq(unit.pos, Vector2i(1, 1))

func test_move_step_spends_tile_tu() -> void:
	var map := BattleMap.new(4, 4, terrain)
	map.set_ground(Vector2i(2, 1), "wheat")
	var unit := BattleUnit.from_soldier(_soldier_record(), Vector2i(1, 1))
	var before := unit.tu_current
	assert_eq(BattleRules.move_step(map, unit, Vector2i(2, 1)), OK)
	assert_eq(unit.pos, Vector2i(2, 1))
	assert_eq(unit.tu_current, before - int(terrain["wheat"]["tu_cost"]))

func test_move_step_rejects_blocked_and_insufficient_tu() -> void:
	var map := BattleMap.new(4, 4, terrain)
	map.set_obstacle(Vector2i(2, 1), "fence")
	var unit := BattleUnit.from_soldier(_soldier_record(), Vector2i(1, 1))
	assert_ne(BattleRules.move_step(map, unit, Vector2i(2, 1)), OK)
	assert_eq(unit.pos, Vector2i(1, 1))

	map.set_obstacle(Vector2i(2, 1), null)
	unit.tu_current = 1
	assert_ne(BattleRules.move_step(map, unit, Vector2i(2, 1)), OK)
	assert_eq(unit.pos, Vector2i(1, 1))

func test_los_is_blocked_by_sight_blocking_obstacle() -> void:
	var map := BattleMap.new(6, 3, terrain)
	assert_true(BattleRules.can_see(map, Vector2i(1, 1), Vector2i(4, 1)))
	map.set_obstacle(Vector2i(2, 1), "hedge")
	assert_false(BattleRules.can_see(map, Vector2i(1, 1), Vector2i(4, 1)))
	map.damage_obstacle(Vector2i(2, 1), 999)
	assert_true(BattleRules.can_see(map, Vector2i(1, 1), Vector2i(4, 1)))

func test_attack_spends_tu_and_damage_is_deterministic() -> void:
	var map := BattleMap.new(8, 3, terrain)
	var attacker := BattleUnit.from_soldier(_soldier_record(), Vector2i(1, 1))
	var target := BattleUnit.from_alien("sectoid_soldier", DataRegistry.get_record("aliens", "sectoid_soldier"), Vector2i(5, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12

	var result := BattleRules.attack(map, attacker, target, items, "snap", rng)
	assert_true(result["ok"])
	assert_eq(int(result["tu_cost"]), 15)
	assert_eq(attacker.tu_current, 45)
	assert_true(result.has("roll"))
	if result["hit"]:
		assert_eq(int(result["damage"]), int(items["rifle_clip"]["damage"]) - int(target.armor["front"]))
		assert_eq(target.health_current, int(target.stats["health"]) - int(result["damage"]))
	else:
		assert_eq(int(result["damage"]), 0)
		assert_eq(target.health_current, int(target.stats["health"]))

func test_attack_requires_line_of_sight() -> void:
	var map := BattleMap.new(8, 3, terrain)
	map.set_obstacle(Vector2i(3, 1), "hedge")
	var attacker := BattleUnit.from_soldier(_soldier_record(), Vector2i(1, 1))
	var target := BattleUnit.from_alien("sectoid_soldier", DataRegistry.get_record("aliens", "sectoid_soldier"), Vector2i(5, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var result := BattleRules.attack(map, attacker, target, items, "snap", rng)
	assert_false(result["ok"])
	assert_eq(result["error"], BattleRules.ERR_NO_LOS)
	assert_eq(attacker.tu_current, attacker.stats["tu"])

func _soldier_record() -> Dictionary:
	return {
		"id": 99,
		"name": "Test Soldier",
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
