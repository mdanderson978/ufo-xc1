class_name CrashSiteGenerator
extends RefCounted
## Deterministic farmland crash-site maps: wheat fields with fence lines,
## hedgerows, trees, a scatter of wreckage, and a crashed UFO hull whose
## layout comes from the UFO class. Same seed -> same map.

const MAP_SIZE := 40

## ufo_id: key into data/ufos.json (or "" for no UFO, pure terrain skirmish).
static func generate(terrain_table: Dictionary, ufo_id: String, seed_value: int) -> BattleMap:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := BattleMap.new(MAP_SIZE, MAP_SIZE, terrain_table)
	map.seed_value = seed_value

	_paint_fields(map, rng)
	_plant_field_boundaries(map, rng)
	_scatter_trees(map, rng, 14)

	if ufo_id != "":
		var center := Vector2i(
			rng.randi_range(22, MAP_SIZE - 10),
			rng.randi_range(10, MAP_SIZE - 10))
		_stamp_ufo(map, rng, ufo_id, center)
		_scorch_crash_trail(map, rng, center)

	_mark_spawns(map, rng, ufo_id != "")
	return map

static func _paint_fields(map: BattleMap, rng: RandomNumberGenerator) -> void:
	# Split the map into a few horizontal field bands: wheat / grass / dirt.
	var y := 0
	while y < map.height:
		var band_height := rng.randi_range(6, 12)
		var ground: String = ["wheat", "grass", "dirt", "wheat"][rng.randi() % 4]
		for band_y in range(y, mini(y + band_height, map.height)):
			for x in range(map.width):
				map.set_ground(Vector2i(x, band_y), ground)
		y += band_height

static func _plant_field_boundaries(map: BattleMap, rng: RandomNumberGenerator) -> void:
	# Fences or hedges along some band boundaries, with gaps to walk through.
	for y in range(1, map.height - 1):
		var above: String = map.tile(Vector2i(0, y - 1))["ground"]
		var here: String = map.tile(Vector2i(0, y))["ground"]
		if above == here or rng.randf() > 0.6:
			continue
		var barrier: String = "fence" if rng.randf() < 0.6 else "hedge"
		for x in range(map.width):
			if rng.randf() < 0.15: # gaps
				continue
			map.set_obstacle(Vector2i(x, y), barrier)

static func _scatter_trees(map: BattleMap, rng: RandomNumberGenerator, count: int) -> void:
	for i in range(count):
		var pos := Vector2i(rng.randi_range(1, map.width - 2), rng.randi_range(1, map.height - 2))
		if map.tile(pos)["obstacle"] == null:
			map.set_obstacle(pos, "tree" if rng.randf() < 0.7 else "rock")

static func _stamp_ufo(map: BattleMap, rng: RandomNumberGenerator, ufo_id: String, center: Vector2i) -> void:
	# Circular hull; radius by UFO size class. Door faces -x (toward squad).
	var radius := 4 if ufo_id == "harvester" else 3
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var pos := Vector2i(x, y)
			if not map.in_bounds(pos):
				continue
			var distance := Vector2(pos - center).length()
			if distance > radius:
				continue
			map.set_obstacle(pos, null)
			if distance > radius - 1.0:
				map.set_ground(pos, "ufo_floor")
				map.set_obstacle(pos, "ufo_wall")
			else:
				map.set_ground(pos, "ufo_floor")
	# Door on the -x rim.
	var door := Vector2i(center.x - radius, center.y)
	while not map.in_bounds(door) or map.tile(door)["obstacle"] != "ufo_wall":
		door.x += 1
		if door.x >= center.x:
			break
	map.set_obstacle(door, null)
	map.set_ground(door, "ufo_door")
	map.ufo_door_tiles.append(door)
	# Consoles inside, alien spawn tiles inside.
	var inside := Vector2i(center.x + 1, center.y)
	if map.is_walkable(inside):
		map.set_obstacle(inside, "ufo_console")
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(-1, 0)]:
		var spawn := center + offset
		if map.is_walkable(spawn):
			map.alien_spawns.append(spawn)

static func _scorch_crash_trail(map: BattleMap, rng: RandomNumberGenerator, center: Vector2i) -> void:
	# Scorched gouge running -x from the hull with scattered wreckage.
	for x in range(maxi(2, center.x - 14), center.x - 3):
		for y in range(center.y - 2, center.y + 3):
			var pos := Vector2i(x, y)
			if not map.in_bounds(pos) or map.tile(pos)["ground"] == "ufo_floor":
				continue
			if rng.randf() < 0.75:
				map.set_ground(pos, "scorched")
				if map.tile(pos)["obstacle"] != null:
					map.set_obstacle(pos, null)
				if rng.randf() < 0.08:
					map.set_obstacle(pos, "wreckage")

static func _mark_spawns(map: BattleMap, rng: RandomNumberGenerator, has_ufo: bool) -> void:
	# Squad deploys along the -x edge (Skyranger ramp).
	for y in range(map.height / 2 - 4, map.height / 2 + 4):
		for x in range(0, 3):
			var pos := Vector2i(x, y)
			map.set_obstacle(pos, null)
			if map.is_walkable(pos):
				map.xcom_spawns.append(pos)
	# Some aliens patrol outside the UFO.
	var outdoor_spawns := 4
	var attempts := 0
	while outdoor_spawns > 0 and attempts < 200:
		attempts += 1
		var pos := Vector2i(rng.randi_range(map.width / 2, map.width - 2), rng.randi_range(1, map.height - 2))
		if map.is_walkable(pos) and not map.alien_spawns.has(pos):
			map.alien_spawns.append(pos)
			outdoor_spawns -= 1
