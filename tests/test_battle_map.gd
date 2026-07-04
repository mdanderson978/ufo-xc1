extends GutTest
## Battlescape map model + crash-site generator.

var terrain: Dictionary

func before_each() -> void:
	terrain = DataRegistry.get_table("terrain")

func test_terrain_table_loaded() -> void:
	assert_gt(terrain.size(), 10)
	for id: String in terrain:
		var t: Dictionary = terrain[id]
		assert_true(t.has("kind"), "%s missing kind" % id)

func test_generation_is_deterministic() -> void:
	var a := CrashSiteGenerator.generate(terrain, "small_scout", 555)
	var b := CrashSiteGenerator.generate(terrain, "small_scout", 555)
	assert_eq(JSON.stringify(a.serialize()), JSON.stringify(b.serialize()))
	var c := CrashSiteGenerator.generate(terrain, "small_scout", 556)
	assert_ne(JSON.stringify(a.serialize()), JSON.stringify(c.serialize()))

func test_spawns_and_door_exist() -> void:
	for seed_value in [1, 2, 3, 10, 99]:
		var map := CrashSiteGenerator.generate(terrain, "medium_scout", seed_value)
		assert_gt(map.xcom_spawns.size(), 7, "seed %d: too few squad spawns" % seed_value)
		assert_gt(map.alien_spawns.size(), 4, "seed %d: too few alien spawns" % seed_value)
		assert_eq(map.ufo_door_tiles.size(), 1, "seed %d: expected one UFO door" % seed_value)
		for pos: Vector2i in map.xcom_spawns + map.alien_spawns:
			assert_true(map.is_walkable(pos), "seed %d: spawn %s not walkable" % [seed_value, pos])

func test_all_spawns_connected() -> void:
	# Every alien spawn (including inside the UFO) must be reachable from the
	# squad deployment zone, otherwise a mission could be unwinnable.
	for seed_value in [1, 2, 3, 10, 99, 1234]:
		var map := CrashSiteGenerator.generate(terrain, "harvester", seed_value)
		var reachable := _flood_fill(map, map.xcom_spawns[0])
		for spawn: Vector2i in map.alien_spawns:
			assert_true(reachable.has(spawn), "seed %d: alien spawn %s unreachable" % [seed_value, spawn])

func test_obstacle_destruction() -> void:
	var map := BattleMap.new(4, 4, terrain)
	map.set_obstacle(Vector2i(1, 1), "fence")
	assert_false(map.is_walkable(Vector2i(1, 1)))
	assert_false(map.damage_obstacle(Vector2i(1, 1), 10), "fence has 20hp, 10 should not destroy")
	assert_true(map.damage_obstacle(Vector2i(1, 1), 15), "cumulative 25 > 20 destroys")
	assert_true(map.is_walkable(Vector2i(1, 1)))

func test_ufo_wall_becomes_breach() -> void:
	var map := BattleMap.new(4, 4, terrain)
	map.set_obstacle(Vector2i(2, 2), "ufo_wall")
	assert_true(map.blocks_sight(Vector2i(2, 2)))
	map.damage_obstacle(Vector2i(2, 2), 999)
	assert_eq(map.tile(Vector2i(2, 2))["obstacle"], "ufo_breach")
	assert_false(map.blocks_sight(Vector2i(2, 2)), "breach can be seen through")
	assert_false(map.is_walkable(Vector2i(2, 2)), "breach is not a passage")

func _flood_fill(map: BattleMap, start: Vector2i) -> Dictionary:
	var reachable := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var pos: Vector2i = frontier.pop_back()
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = pos + offset
			if not reachable.has(next) and map.is_walkable(next):
				reachable[next] = true
				frontier.append(next)
	return reachable
