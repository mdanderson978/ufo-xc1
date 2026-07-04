class_name CampaignFactory
extends RefCounted
## Builds new-campaign state as plain data. Scene-free and deterministic
## given a seed, so the whole starting state is unit-testable.

const START_FUNDS := 5_000_000
const START_SOLDIERS := 8
const START_SCIENTISTS := 10
const START_ENGINEERS := 10
const BASE_GRID := 6
const RANKS: Array[Dictionary] = [
	{"name": "Rookie", "xp": 0},
	{"name": "Squaddie", "xp": 30},
	{"name": "Sergeant", "xp": 90},
	{"name": "Captain", "xp": 180},
	{"name": "Commander", "xp": 320},
]

## registry: DataRegistry-like (needs get_table()). seed_value drives all rolls.
static func new_campaign(registry: Object, seed_value: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var nations := {}
	for nation_id: String in registry.get_table("nations"):
		var nation: Dictionary = registry.get_table("nations")[nation_id]
		nations[nation_id] = {
			"funding": nation["funding_start"],
			"attitude": 0, # -2 furious .. +2 delighted, drives funding shifts
		}

	return {
		"version": 1,
		"seed": seed_value,
		"funds": START_FUNDS,
		"calendar": {"year": 1999, "month": 1, "day": 1, "minute": 0},
		"score": {"month_xcom": 0, "month_alien": 0},
		"nations": nations,
		"bases": [_starting_base(registry, rng)],
		"research": {"active": {}, "completed": []},
		"next_ids": {"soldier": START_SOLDIERS + 1, "craft": 3, "ufo": 1},
		"ufos": [],
	}

static func _starting_base(registry: Object, rng: RandomNumberGenerator) -> Dictionary:
	var soldiers: Array = []
	for i in range(START_SOLDIERS):
		soldiers.append(generate_soldier(registry, rng, i + 1))

	return {
		"name": "XC1 Command",
		"lon": 3.0, "lat": 46.5, # central Europe start
		"facilities": [
			{"type": "access_lift", "x": 2, "y": 2, "days_left": 0},
			{"type": "living_quarters", "x": 3, "y": 2, "days_left": 0},
			{"type": "laboratory", "x": 2, "y": 1, "days_left": 0},
			{"type": "workshop", "x": 3, "y": 1, "days_left": 0},
			{"type": "general_stores", "x": 2, "y": 3, "days_left": 0},
			{"type": "small_radar", "x": 3, "y": 3, "days_left": 0},
			{"type": "hangar", "x": 0, "y": 0, "days_left": 0},
			{"type": "hangar", "x": 4, "y": 0, "days_left": 0},
		],
		"soldiers": soldiers,
		"scientists": START_SCIENTISTS,
		"engineers": START_ENGINEERS,
		"stores": {
			"rifle": 8, "rifle_clip": 24,
			"pistol": 4, "pistol_clip": 12,
			"grenade": 10, "medikit": 2, "stun_rod": 1,
		},
		"crafts": [
			{"id": 1, "type": "interceptor", "name": "Interceptor-1", "fuel": 100, "damage": 0, "status": "ready"},
			{"id": 2, "type": "skyranger", "name": "Skyranger-1", "fuel": 100, "damage": 0, "status": "ready"},
		],
		"manufacture": {"queue": [], "hours_done": 0},
	}

static func generate_soldier(registry: Object, rng: RandomNumberGenerator, id: int) -> Dictionary:
	var soldier_data: Dictionary = registry.get_table("soldiers")
	var config: Dictionary = soldier_data["config"]
	var stats := {}
	for stat: String in config["stat_ranges"]:
		var stat_range: Array = config["stat_ranges"][stat]
		stats[stat] = rng.randi_range(int(stat_range[0]), int(stat_range[1]))
	var first_names: Array = soldier_data["first_names"]
	var last_names: Array = soldier_data["last_names"]
	var portraits: Array = config["portraits"]
	return {
		"id": id,
		"name": "%s %s" % [first_names[rng.randi() % first_names.size()], last_names[rng.randi() % last_names.size()]],
		"portrait": portraits[rng.randi() % portraits.size()],
		"appearance_seed": rng.randi(), # drives the Blender character factory model
		"stats": stats,
		"missions": 0, "kills": 0, "xp": 0, "rank": "Rookie",
		"wounds_days_left": 0,
		"status": "active", # active | wounded | dead
		"loadout": {},
	}

static func apply_battle_result(campaign: Dictionary, battle_result: Dictionary, base_index: int = 0) -> Dictionary:
	var updated := campaign.duplicate(true)
	var bases: Array = updated.get("bases", [])
	if base_index < 0 or base_index >= bases.size():
		return updated

	var base: Dictionary = bases[base_index]
	var survivors := _string_set(battle_result.get("xcom_survivors", []))
	var losses := _string_set(battle_result.get("xcom_losses", []))
	var mission_kills: Dictionary = battle_result.get("xcom_kills", {})
	var mission_xp: Dictionary = battle_result.get("xcom_xp", {})
	var mission_wounds: Dictionary = battle_result.get("xcom_wounds", {})
	var recovered_items: Dictionary = battle_result.get("recovered_items", {})

	updated["score"]["month_xcom"] = int(updated["score"].get("month_xcom", 0)) + int(battle_result.get("score_xcom", 0))
	var stores: Dictionary = base.get("stores", {})
	for item_id: String in recovered_items:
		stores[item_id] = int(stores.get(item_id, 0)) + int(recovered_items[item_id])
	base["stores"] = stores

	var participants := survivors.duplicate()
	for unit_id: String in losses:
		participants[unit_id] = true

	for soldier: Dictionary in base.get("soldiers", []):
		var unit_id := _xcom_unit_id_for_soldier(soldier)
		if not participants.has(unit_id):
			continue
		var kills_earned := int(mission_kills.get(unit_id, 0))
		var xp_earned := int(mission_xp.get(unit_id, 0))
		soldier["missions"] = int(soldier.get("missions", 0)) + 1
		soldier["kills"] = int(soldier.get("kills", 0)) + kills_earned
		soldier["xp"] = int(soldier.get("xp", 0)) + xp_earned
		soldier["rank"] = _rank_for_xp(int(soldier["xp"]))
		if losses.has(unit_id):
			soldier["status"] = "dead"
			soldier["wounds_days_left"] = 0
		else:
			var wound_days := int(mission_wounds.get(unit_id, 0))
			soldier["wounds_days_left"] = wound_days
			soldier["status"] = "wounded" if wound_days > 0 else "active"
	return updated

static func _string_set(values: Variant) -> Dictionary:
	var result := {}
	for value: Variant in values:
		result[String(value)] = true
	return result

static func _xcom_unit_id_for_soldier(soldier: Dictionary) -> String:
	return "xcom_%s" % soldier.get("id", 0)

static func _rank_for_xp(xp: int) -> String:
	var rank := "Rookie"
	for rank_def: Dictionary in RANKS:
		if xp >= int(rank_def["xp"]):
			rank = rank_def["name"]
	return rank
