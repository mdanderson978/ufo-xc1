class_name BattleUnit
extends RefCounted
## Scene-free tactical unit state. Built from campaign soldier records or
## alien data records, then mutated by BattleRules during a mission.

const TEAM_XCOM := "xcom"
const TEAM_ALIEN := "alien"

var id: String
var team: String
var name: String
var pos: Vector2i
var stats: Dictionary
var armor: Dictionary
var loadout: Dictionary
var tu_current: int
var health_current: int
var morale_current: int = 100

static func from_soldier(soldier: Dictionary, spawn: Vector2i) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.id = "xcom_%s" % soldier.get("id", 0)
	unit.team = TEAM_XCOM
	unit.name = soldier.get("name", "Soldier")
	unit.pos = spawn
	unit.stats = soldier.get("stats", {}).duplicate(true)
	unit.armor = soldier.get("armor", {"front": 12, "side": 8, "rear": 6, "under": 4}).duplicate(true)
	unit.loadout = soldier.get("loadout", {}).duplicate(true)
	unit.tu_current = int(unit.stats.get("tu", 0))
	unit.health_current = int(unit.stats.get("health", 1))
	return unit

static func from_alien(alien_id: String, alien: Dictionary, spawn: Vector2i) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.id = alien_id
	unit.team = TEAM_ALIEN
	unit.name = alien.get("name", alien_id)
	unit.pos = spawn
	unit.stats = alien.get("stats", {}).duplicate(true)
	unit.armor = alien.get("armor", {}).duplicate(true)
	unit.loadout = alien.get("loadout", {}).duplicate(true)
	unit.tu_current = int(unit.stats.get("tu", 0))
	unit.health_current = int(unit.stats.get("health", 1))
	return unit

func is_alive() -> bool:
	return health_current > 0

func begin_turn() -> void:
	if is_alive():
		tu_current = int(stats.get("tu", 0))

func primary_weapon_id() -> String:
	return loadout.get("right_hand", "")

func apply_damage(amount: int) -> void:
	health_current = maxi(0, health_current - maxi(0, amount))

func serialize() -> Dictionary:
	return {
		"id": id,
		"team": team,
		"name": name,
		"pos": [pos.x, pos.y],
		"stats": stats.duplicate(true),
		"armor": armor.duplicate(true),
		"loadout": loadout.duplicate(true),
		"tu_current": tu_current,
		"health_current": health_current,
		"morale_current": morale_current
	}
