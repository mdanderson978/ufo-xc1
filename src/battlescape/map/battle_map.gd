class_name BattleMap
extends RefCounted
## The tactical grid. Pure data + queries; no scene-tree dependencies.
## Tiles are addressed (x, y) with z-levels reserved for Milestone 2
## (M1 maps are single-level with height variation via obstacles).
##
## Each tile is {ground: String, obstacle: String|null (terrain ids),
## obstacle_hp: int, door_open: bool}.

var width: int
var height: int
var seed_value: int
var terrain: Dictionary # terrain table from DataRegistry
var tiles: Array = [] # row-major Array of Dictionary
## Squad deployment zone (Skyranger ramp area) and alien spawn tiles.
var xcom_spawns: Array[Vector2i] = []
var alien_spawns: Array[Vector2i] = []
var ufo_door_tiles: Array[Vector2i] = []

func _init(map_width: int, map_height: int, terrain_table: Dictionary) -> void:
	width = map_width
	height = map_height
	terrain = terrain_table
	tiles.resize(width * height)
	for i in range(tiles.size()):
		tiles[i] = {"ground": "grass", "obstacle": null, "obstacle_hp": 0, "door_open": false}

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func tile(pos: Vector2i) -> Dictionary:
	return tiles[pos.y * width + pos.x]

func set_ground(pos: Vector2i, ground_id: String) -> void:
	tile(pos)["ground"] = ground_id

func set_obstacle(pos: Vector2i, obstacle_id: Variant) -> void:
	var t := tile(pos)
	t["obstacle"] = obstacle_id
	if obstacle_id != null:
		var terrain_def: Dictionary = terrain.get(obstacle_id, {})
		t["obstacle_hp"] = terrain_def.get("destructible", {}).get("hp", 0)

func is_walkable(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	var t := tile(pos)
	if t["obstacle"] != null and terrain[t["obstacle"]].get("kind") != "door":
		return false
	var ground: Dictionary = terrain[t["ground"]]
	return ground.get("walkable", false)

## TU cost of stepping INTO this tile (diagonal handled by mover).
func tu_cost(pos: Vector2i) -> int:
	var t := tile(pos)
	return int(terrain[t["ground"]].get("tu_cost", 4))

## Whether sight passes THROUGH this tile.
func blocks_sight(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return true
	var t := tile(pos)
	if t["obstacle"] != null:
		var obstacle: Dictionary = terrain[t["obstacle"]]
		if obstacle.get("kind") == "door":
			return not t["door_open"]
		if obstacle.get("blocks_sight", false):
			return true
	if t["ground"] == "ufo_door" and not t["door_open"]:
		return true
	return terrain[t["ground"]].get("blocks_sight", false)

## Cover percentage granted by the tile a target stands behind/in.
func cover_at(pos: Vector2i) -> int:
	var t := tile(pos)
	var cover: int = int(terrain[t["ground"]].get("cover", 0))
	if t["obstacle"] != null:
		cover = maxi(cover, int(terrain[t["obstacle"]].get("cover", 0)))
	return cover

## Damage an obstacle; removes/transforms it when hp is exhausted.
## Returns true if the tile changed.
func damage_obstacle(pos: Vector2i, damage: int) -> bool:
	var t := tile(pos)
	if t["obstacle"] == null:
		return false
	var destructible: Dictionary = terrain[t["obstacle"]].get("destructible", {})
	if destructible.is_empty():
		return false
	t["obstacle_hp"] -= damage
	if t["obstacle_hp"] <= 0:
		set_obstacle(pos, destructible.get("becomes"))
		return true
	return false

func serialize() -> Dictionary:
	return {
		"width": width, "height": height, "seed": seed_value,
		"tiles": tiles.duplicate(true),
		"xcom_spawns": xcom_spawns.map(func(p: Vector2i) -> Array: return [p.x, p.y]),
		"alien_spawns": alien_spawns.map(func(p: Vector2i) -> Array: return [p.x, p.y]),
		"ufo_door_tiles": ufo_door_tiles.map(func(p: Vector2i) -> Array: return [p.x, p.y]),
	}
