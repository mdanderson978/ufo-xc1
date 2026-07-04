class_name BattleState
extends RefCounted
## Scene-free mission controller. Owns the tactical map, units, active side,
## visibility cache, action dispatch, and win/loss state.

const OUTCOME_ACTIVE := "active"
const OUTCOME_XCOM_WIN := "xcom_win"
const OUTCOME_ALIEN_WIN := "alien_win"
const XP_MISSION_SURVIVED := 10
const XP_PER_KILL := 25

var map: BattleMap
var items: Dictionary
var units: Dictionary = {}
var unit_order: PackedStringArray = PackedStringArray()
var active_team: String = BattleUnit.TEAM_XCOM
var turn_number: int = 1
var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var visible_tiles: Dictionary = {"xcom": {}, "alien": {}}
var discovered_tiles: Dictionary = {"xcom": {}, "alien": {}}
var spotted_enemies: Dictionary = {"xcom": PackedStringArray(), "alien": PackedStringArray()}
var outcome: String = OUTCOME_ACTIVE
var reaction_fire_enabled: bool = true
var ufo_id: String = ""
var mission_recovery_loot: Dictionary = {}
var morale_events: Array[Dictionary] = []

static func create(initial_map: BattleMap, item_table: Dictionary, seed: int = 0) -> BattleState:
	var state := BattleState.new()
	state.map = initial_map
	state.items = item_table
	state.seed_value = seed
	state.rng.seed = seed
	return state

static func from_crash_site(registry: Object, ufo_id: String, soldiers: Array, seed: int = 0) -> BattleState:
	var state := BattleState.create(
		CrashSiteGenerator.generate(registry.get_table("terrain"), ufo_id, seed),
		registry.get_table("items"),
		seed)
	state.ufo_id = ufo_id
	for i in range(mini(soldiers.size(), state.map.xcom_spawns.size())):
		state.add_unit(BattleUnit.from_soldier(soldiers[i], state.map.xcom_spawns[i]))

	var ufo: Dictionary = registry.get_record("ufos", ufo_id)
	state.mission_recovery_loot = _roll_recovery_loot(ufo.get("loot", {}), state.rng)
	var alien_spawn_index := 0
	for alien_id: String in ufo.get("crew", {}):
		var count_range: Array = ufo["crew"][alien_id]
		var count := state.rng.randi_range(int(count_range[0]), int(count_range[1]))
		for i in range(count):
			if alien_spawn_index >= state.map.alien_spawns.size():
				break
			var unit_id := "%s_%d" % [alien_id, i + 1]
			state.add_unit(BattleUnit.from_alien(unit_id, registry.get_record("aliens", alien_id), state.map.alien_spawns[alien_spawn_index]))
			alien_spawn_index += 1

	state.begin_battle()
	return state

static func _roll_recovery_loot(loot_table: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var loot := {}
	for item_id: String in loot_table:
		var amount_range: Array = loot_table[item_id]
		var amount := rng.randi_range(int(amount_range[0]), int(amount_range[1]))
		if amount > 0:
			loot[item_id] = amount
	return loot

func add_unit(unit: BattleUnit) -> Error:
	if units.has(unit.id):
		return ERR_ALREADY_EXISTS
	if _unit_at(unit.pos) != null:
		return ERR_BUSY
	if not map.is_walkable(unit.pos):
		return BattleRules.ERR_BLOCKED
	units[unit.id] = unit
	unit_order.append(unit.id)
	return OK

func begin_battle() -> void:
	active_team = BattleUnit.TEAM_XCOM
	turn_number = 1
	outcome = OUTCOME_ACTIVE
	visible_tiles = _empty_team_tile_cache()
	discovered_tiles = _empty_team_tile_cache()
	spotted_enemies = {BattleUnit.TEAM_XCOM: PackedStringArray(), BattleUnit.TEAM_ALIEN: PackedStringArray()}
	morale_events.clear()
	for unit: BattleUnit in living_units(active_team):
		unit.begin_turn()
	_refresh_visibility()
	_update_outcome()

func get_unit(unit_id: String) -> BattleUnit:
	return units.get(unit_id) as BattleUnit

func living_units(team: String = "") -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit_id: String in unit_order:
		var unit := units[unit_id] as BattleUnit
		if unit.is_alive() and (team == "" or unit.team == team):
			result.append(unit)
	return result

func move_unit(unit_id: String, path: Array[Vector2i]) -> Dictionary:
	if outcome != OUTCOME_ACTIVE:
		return _error(ERR_UNAVAILABLE)
	var unit := get_unit(unit_id)
	if unit == null or not unit.is_alive():
		return _error(ERR_DOES_NOT_EXIST)
	if unit.team != active_team:
		return _error(ERR_INVALID_DATA)

	var start := unit.pos
	var reactions: Array[Dictionary] = []
	for destination: Vector2i in path:
		var occupant := _unit_at(destination)
		if occupant != null and occupant != unit:
			return _error(ERR_BUSY)
		var result := BattleRules.move_step(map, unit, destination)
		if result != OK:
			return _error(result)
		_refresh_visibility()
		if reaction_fire_enabled:
			reactions.append_array(_resolve_reaction_fire(unit))
		_update_outcome()
		if outcome != OUTCOME_ACTIVE or not unit.is_alive():
			break
	return {
		"ok": true,
		"unit_id": unit.id,
		"from": [start.x, start.y],
		"to": [unit.pos.x, unit.pos.y],
		"tu_current": unit.tu_current,
		"reactions": reactions,
		"morale_events": morale_events.duplicate(true),
		"outcome": outcome
	}

func attack_unit(attacker_id: String, target_id: String, fire_mode: String) -> Dictionary:
	if outcome != OUTCOME_ACTIVE:
		return _error(ERR_UNAVAILABLE)
	var attacker := get_unit(attacker_id)
	var target := get_unit(target_id)
	if attacker == null or target == null or not attacker.is_alive() or not target.is_alive():
		return _error(ERR_DOES_NOT_EXIST)
	if attacker.team != active_team or attacker.team == target.team:
		return _error(ERR_INVALID_DATA)

	var result := BattleRules.attack(map, attacker, target, items, fire_mode, rng)
	if not result.get("ok", false):
		return result
	_record_kill(attacker, target, result)
	_refresh_visibility()
	_update_outcome()
	result["outcome"] = outcome
	result["morale_events"] = morale_events.duplicate(true)
	return result

func end_turn() -> Dictionary:
	_update_outcome()
	if outcome != OUTCOME_ACTIVE:
		return {"ok": true, "active_team": active_team, "turn_number": turn_number, "outcome": outcome}
	active_team = _opposing_team(active_team)
	if active_team == BattleUnit.TEAM_XCOM:
		turn_number += 1
	for unit: BattleUnit in living_units(active_team):
		unit.begin_turn()
	var panic_events := _resolve_panic_for_active_team()
	_refresh_visibility()
	return {"ok": true, "active_team": active_team, "turn_number": turn_number, "outcome": outcome, "morale_events": panic_events}

func is_visible_to(team: String, pos: Vector2i) -> bool:
	var team_tiles: Dictionary = visible_tiles.get(team, {})
	return team_tiles.has(pos)

func has_seen(team: String, pos: Vector2i) -> bool:
	var team_tiles: Dictionary = discovered_tiles.get(team, {})
	return team_tiles.has(pos)

func visible_tile_list(team: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var team_tiles: Dictionary = visible_tiles.get(team, {})
	for pos: Vector2i in team_tiles:
		result.append(pos)
	return result

func discovered_tile_list(team: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var team_tiles: Dictionary = discovered_tiles.get(team, {})
	for pos: Vector2i in team_tiles:
		result.append(pos)
	return result

func unit_at(pos: Vector2i) -> BattleUnit:
	return _unit_at(pos)

func battle_result() -> Dictionary:
	_update_outcome()
	var recovered_items := {}
	if outcome == OUTCOME_XCOM_WIN:
		recovered_items = mission_recovery_loot.duplicate(true)
		for unit_id: String in unit_order:
			var unit := units[unit_id] as BattleUnit
			if unit.team == BattleUnit.TEAM_ALIEN and not unit.is_alive() and unit.corpse_item != "":
				recovered_items[unit.corpse_item] = int(recovered_items.get(unit.corpse_item, 0)) + 1
	return {
		"outcome": outcome,
		"turn_number": turn_number,
		"ufo_id": ufo_id,
		"xcom_survivors": _unit_ids_for(BattleUnit.TEAM_XCOM, true),
		"xcom_losses": _unit_ids_for(BattleUnit.TEAM_XCOM, false),
		"aliens_killed": _unit_ids_for(BattleUnit.TEAM_ALIEN, false),
		"aliens_survived": _unit_ids_for(BattleUnit.TEAM_ALIEN, true),
		"xcom_kills": _kill_counts_for(BattleUnit.TEAM_XCOM),
		"alien_kills": _kill_counts_for(BattleUnit.TEAM_ALIEN),
		"xcom_xp": _xp_awards_for_xcom(),
		"score_xcom": _score_for_killed_aliens(),
		"recovered_items": recovered_items,
		"morale_events": morale_events.duplicate(true)
	}

func serialize() -> Dictionary:
	var serialized_units: Array = []
	for unit_id: String in unit_order:
		serialized_units.append((units[unit_id] as BattleUnit).serialize())
	return {
		"map": map.serialize(),
		"units": serialized_units,
		"active_team": active_team,
		"turn_number": turn_number,
		"seed": seed_value,
		"ufo_id": ufo_id,
		"mission_recovery_loot": mission_recovery_loot.duplicate(true),
		"outcome": outcome,
		"morale_events": morale_events.duplicate(true),
		"visible_tiles": {
			BattleUnit.TEAM_XCOM: _serialize_positions(visible_tiles[BattleUnit.TEAM_XCOM].keys()),
			BattleUnit.TEAM_ALIEN: _serialize_positions(visible_tiles[BattleUnit.TEAM_ALIEN].keys())
		},
		"discovered_tiles": {
			BattleUnit.TEAM_XCOM: _serialize_positions(discovered_tiles[BattleUnit.TEAM_XCOM].keys()),
			BattleUnit.TEAM_ALIEN: _serialize_positions(discovered_tiles[BattleUnit.TEAM_ALIEN].keys())
		},
		"spotted_enemies": {
			BattleUnit.TEAM_XCOM: Array(spotted_enemies[BattleUnit.TEAM_XCOM]),
			BattleUnit.TEAM_ALIEN: Array(spotted_enemies[BattleUnit.TEAM_ALIEN])
		}
	}

func _refresh_visibility() -> void:
	visible_tiles[BattleUnit.TEAM_XCOM] = _visible_tiles_for(BattleUnit.TEAM_XCOM)
	visible_tiles[BattleUnit.TEAM_ALIEN] = _visible_tiles_for(BattleUnit.TEAM_ALIEN)
	_remember_visible_tiles(BattleUnit.TEAM_XCOM)
	_remember_visible_tiles(BattleUnit.TEAM_ALIEN)
	spotted_enemies[BattleUnit.TEAM_XCOM] = _spotted_enemies_for(BattleUnit.TEAM_XCOM)
	spotted_enemies[BattleUnit.TEAM_ALIEN] = _spotted_enemies_for(BattleUnit.TEAM_ALIEN)

func _remember_visible_tiles(team: String) -> void:
	var memory: Dictionary = discovered_tiles.get(team, {})
	var current: Dictionary = visible_tiles.get(team, {})
	for pos: Vector2i in current:
		memory[pos] = true
	discovered_tiles[team] = memory

func _visible_tiles_for(team: String) -> Dictionary:
	var visible: Dictionary = {}
	for unit: BattleUnit in living_units(team):
		var vision_range := int(unit.stats.get("vision_range", 20))
		var min_x := maxi(0, unit.pos.x - vision_range)
		var max_x := mini(map.width - 1, unit.pos.x + vision_range)
		var min_y := maxi(0, unit.pos.y - vision_range)
		var max_y := mini(map.height - 1, unit.pos.y + vision_range)
		for y in range(min_y, max_y + 1):
			for x in range(min_x, max_x + 1):
				var pos := Vector2i(x, y)
				if BattleRules.can_see(map, unit.pos, pos, vision_range):
					visible[pos] = true
	return visible

func _spotted_enemies_for(team: String) -> PackedStringArray:
	var spotted := PackedStringArray()
	var enemy_team := _opposing_team(team)
	for unit: BattleUnit in living_units(enemy_team):
		if is_visible_to(team, unit.pos):
			spotted.append(unit.id)
	return spotted

func _update_outcome() -> void:
	if living_units(BattleUnit.TEAM_XCOM).is_empty():
		outcome = OUTCOME_ALIEN_WIN
	elif living_units(BattleUnit.TEAM_ALIEN).is_empty():
		outcome = OUTCOME_XCOM_WIN
	else:
		outcome = OUTCOME_ACTIVE

func _resolve_reaction_fire(mover: BattleUnit) -> Array[Dictionary]:
	var reactions: Array[Dictionary] = []
	if mover == null or not mover.is_alive():
		return reactions
	var reaction_team := _opposing_team(mover.team)
	for reactor: BattleUnit in living_units(reaction_team):
		if not mover.is_alive():
			break
		if not _can_react_to(reactor, mover):
			continue
		var chance := _reaction_chance(reactor, mover)
		var roll := rng.randi_range(1, 100)
		if roll > chance:
			reactions.append({
				"ok": true,
				"type": "reaction_check",
				"actor": reactor.id,
				"target": mover.id,
				"roll": roll,
				"chance": chance,
				"fired": false
			})
			continue
		var result := BattleRules.attack(map, reactor, mover, items, "snap", rng)
		_record_kill(reactor, mover, result)
		result["type"] = "reaction_fire"
		result["actor"] = reactor.id
		result["target"] = mover.id
		result["roll_reaction"] = roll
		result["reaction_chance"] = chance
		result["fired"] = result.get("ok", false)
		reactions.append(result)
		_refresh_visibility()
	return reactions

func _can_react_to(reactor: BattleUnit, mover: BattleUnit) -> bool:
	if reactor == null or mover == null or not reactor.is_alive() or not mover.is_alive():
		return false
	if reactor.team == mover.team:
		return false
	var weapon_id := reactor.primary_weapon_id()
	var weapon: Dictionary = items.get(weapon_id, {})
	if weapon.is_empty() or not weapon.get("accuracy", {}).has("snap"):
		return false
	var tu_cost := int(ceil(float(reactor.stats.get("tu", 0)) * float(weapon.get("tu_percent", {}).get("snap", 0)) / 100.0))
	if reactor.tu_current < tu_cost:
		return false
	if not spotted_enemies[reactor.team].has(mover.id):
		return false
	return BattleRules.can_see(map, reactor.pos, mover.pos, int(reactor.stats.get("vision_range", 20)))

func _reaction_chance(reactor: BattleUnit, mover: BattleUnit) -> int:
	var reaction_delta := int(reactor.stats.get("reactions", 0)) - int(mover.stats.get("reactions", 0))
	return clampi(50 + reaction_delta, 5, 95)

func _record_kill(attacker: BattleUnit, target: BattleUnit, attack_result: Dictionary) -> void:
	if attack_result.get("ok", false) and attack_result.get("target_killed", false):
		attacker.kills_current += 1
		_apply_morale_loss_for_death(target)

func _apply_morale_loss_for_death(dead_unit: BattleUnit) -> void:
	for ally: BattleUnit in living_units(dead_unit.team):
		var bravery := int(ally.stats.get("bravery", 50))
		var loss := clampi(35 - int(round(float(bravery) / 4.0)), 5, 35)
		var before := ally.morale_current
		ally.morale_current = clampi(ally.morale_current - loss, 0, 100)
		morale_events.append({
			"type": "morale_loss",
			"unit_id": ally.id,
			"team": ally.team,
			"source": dead_unit.id,
			"before": before,
			"after": ally.morale_current,
			"amount": loss
		})

func _resolve_panic_for_active_team() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for unit: BattleUnit in living_units(active_team):
		if unit.morale_current >= 30:
			continue
		var bravery := int(unit.stats.get("bravery", 50))
		var chance := clampi(45 - unit.morale_current + int(round(float(50 - bravery) / 2.0)), 5, 100)
		var roll := rng.randi_range(1, 100)
		if roll > chance:
			continue
		unit.panicked_this_turn = true
		unit.tu_current = 0
		var event := {
			"type": "panic",
			"unit_id": unit.id,
			"team": unit.team,
			"roll": roll,
			"chance": chance
		}
		events.append(event)
		morale_events.append(event)
	return events

func _unit_ids_for(team: String, alive: bool) -> PackedStringArray:
	var ids := PackedStringArray()
	for unit_id: String in unit_order:
		var unit := units[unit_id] as BattleUnit
		if unit.team == team and unit.is_alive() == alive:
			ids.append(unit.id)
	return ids

func _kill_counts_for(team: String) -> Dictionary:
	var counts := {}
	for unit_id: String in unit_order:
		var unit := units[unit_id] as BattleUnit
		if unit.team == team and unit.kills_current > 0:
			counts[unit.id] = unit.kills_current
	return counts

func _xp_awards_for_xcom() -> Dictionary:
	var awards := {}
	for unit_id: String in unit_order:
		var unit := units[unit_id] as BattleUnit
		if unit.team != BattleUnit.TEAM_XCOM:
			continue
		var xp := unit.kills_current * XP_PER_KILL
		if unit.is_alive():
			xp += XP_MISSION_SURVIVED
		if xp > 0:
			awards[unit.id] = xp
	return awards

func _score_for_killed_aliens() -> int:
	var score := 0
	for unit_id: String in unit_order:
		var unit := units[unit_id] as BattleUnit
		if unit.team == BattleUnit.TEAM_ALIEN and not unit.is_alive():
			score += unit.score_kill
	return score

func _unit_at(pos: Vector2i) -> BattleUnit:
	for unit_id: String in unit_order:
		var unit := units[unit_id] as BattleUnit
		if unit.is_alive() and unit.pos == pos:
			return unit
	return null

func _opposing_team(team: String) -> String:
	return BattleUnit.TEAM_ALIEN if team == BattleUnit.TEAM_XCOM else BattleUnit.TEAM_XCOM

func _empty_team_tile_cache() -> Dictionary:
	return {BattleUnit.TEAM_XCOM: {}, BattleUnit.TEAM_ALIEN: {}}

func _serialize_positions(positions: Array) -> Array:
	var result := []
	for pos: Vector2i in positions:
		result.append([pos.x, pos.y])
	return result

func _error(error_code: Error) -> Dictionary:
	return {"ok": false, "error": error_code}
