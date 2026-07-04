class_name BattleRules
extends RefCounted
## Deterministic, scene-free tactical rules: TU movement, sight checks, and
## the first weapon attack resolver. Presentation layers call into this.

const ERR_NOT_ENOUGH_TU := ERR_BUSY
const ERR_BLOCKED := ERR_CANT_CREATE
const ERR_NO_LOS := ERR_QUERY_FAILED

static func step_tu_cost(map: BattleMap, origin: Vector2i, to: Vector2i) -> int:
	var delta := to - origin
	if maxi(absi(delta.x), absi(delta.y)) != 1 or delta == Vector2i.ZERO:
		return -1
	var cost := map.tu_cost(to)
	if delta.x != 0 and delta.y != 0:
		cost = int(ceil(float(cost) * 1.5))
	return cost

static func move_step(map: BattleMap, unit: BattleUnit, destination: Vector2i) -> Error:
	if not unit.is_alive():
		return ERR_INVALID_DATA
	if not map.is_walkable(destination):
		return ERR_BLOCKED
	var cost := step_tu_cost(map, unit.pos, destination)
	if cost < 0:
		return ERR_INVALID_PARAMETER
	if unit.tu_current < cost:
		return ERR_NOT_ENOUGH_TU
	unit.tu_current -= cost
	unit.pos = destination
	return OK

static func move_path(map: BattleMap, unit: BattleUnit, path: Array[Vector2i]) -> Error:
	for destination: Vector2i in path:
		var result := move_step(map, unit, destination)
		if result != OK:
			return result
	return OK

static func can_see(map: BattleMap, origin: Vector2i, to: Vector2i, max_range: int = 999) -> bool:
	if not map.in_bounds(origin) or not map.in_bounds(to):
		return false
	if origin.distance_to(to) > float(max_range):
		return false
	var line := _bresenham_line(origin, to)
	for i in range(1, line.size()):
		var pos: Vector2i = line[i]
		if pos == to:
			return true
		if map.blocks_sight(pos):
			return false
	return true

static func attack(
		map: BattleMap,
		attacker: BattleUnit,
		target: BattleUnit,
		items: Dictionary,
		fire_mode: String,
		rng: RandomNumberGenerator) -> Dictionary:
	var weapon_id := attacker.primary_weapon_id()
	var weapon: Dictionary = items.get(weapon_id, {})
	if weapon.is_empty():
		return {"ok": false, "error": ERR_DOES_NOT_EXIST}
	if not attacker.is_alive() or not target.is_alive():
		return {"ok": false, "error": ERR_INVALID_DATA}
	if not can_see(map, attacker.pos, target.pos, int(attacker.stats.get("vision_range", 20))):
		return {"ok": false, "error": ERR_NO_LOS}
	if not weapon.get("accuracy", {}).has(fire_mode):
		return {"ok": false, "error": ERR_INVALID_PARAMETER}

	var tu_cost := _tu_cost_for_action(attacker, weapon, fire_mode)
	if attacker.tu_current < tu_cost:
		return {"ok": false, "error": ERR_NOT_ENOUGH_TU, "tu_cost": tu_cost}

	attacker.tu_current -= tu_cost
	var hit_chance := hit_chance_percent(attacker, target, weapon, fire_mode, map.cover_at(target.pos))
	var roll := rng.randi_range(1, 100)
	var hit := roll <= hit_chance
	var damage := 0
	if hit:
		damage = _weapon_damage(weapon, items) - int(target.armor.get("front", 0))
		damage = maxi(0, damage)
		target.apply_damage(damage)
	return {
		"ok": true,
		"weapon": weapon_id,
		"fire_mode": fire_mode,
		"tu_cost": tu_cost,
		"roll": roll,
		"hit_chance": hit_chance,
		"hit": hit,
		"damage": damage,
		"target_killed": not target.is_alive()
	}

static func hit_chance_percent(
		attacker: BattleUnit,
		target: BattleUnit,
		weapon: Dictionary,
		fire_mode: String,
		target_cover: int) -> int:
	var stat_accuracy := int(attacker.stats.get("firing_accuracy", 0))
	var weapon_accuracy := int(weapon.get("accuracy", {}).get(fire_mode, 0))
	var chance := int(round(float(stat_accuracy * weapon_accuracy) / 100.0))
	chance -= target_cover
	if attacker.pos.distance_to(target.pos) > 15.0:
		chance -= 10
	return clampi(chance, 1, 95)

static func _tu_cost_for_action(attacker: BattleUnit, weapon: Dictionary, fire_mode: String) -> int:
	var tu_percent := int(weapon.get("tu_percent", {}).get(fire_mode, 0))
	return int(ceil(float(attacker.stats.get("tu", 0)) * float(tu_percent) / 100.0))

static func _weapon_damage(weapon: Dictionary, items: Dictionary) -> int:
	if weapon.has("damage"):
		return int(weapon["damage"])
	var clip_id: String = weapon.get("clip", "")
	if clip_id != "":
		return int(items.get(clip_id, {}).get("damage", 0))
	return 0

static func _bresenham_line(origin: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var x0 := origin.x
	var y0 := origin.y
	var x1 := to.x
	var y1 := to.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return points
