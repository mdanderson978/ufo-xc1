extends Node
## Loads and validates all static game data from res://data/*.json.
## Content is data-driven: adding an item/alien/facility means adding JSON,
## not code. Phase 1 fills in the schemas; for now this loads any JSON
## files present and exposes them by table name.

const DATA_DIR := "res://data"

## table name (file stem) -> Dictionary of id -> record
var tables: Dictionary = {}

func _ready() -> void:
	load_all()
	var problems := validate()
	for problem in problems:
		push_error("DataRegistry: %s" % problem)
	if problems.is_empty():
		print("DataRegistry: %d tables loaded, all cross-references valid" % tables.size())

func load_all() -> void:
	tables.clear()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("DataRegistry: no data directory at %s" % DATA_DIR)
		return
	for file_name in dir.get_files():
		if file_name.get_extension() != "json":
			continue
		var table_name := file_name.get_basename()
		var parsed: Variant = _load_json("%s/%s" % [DATA_DIR, file_name])
		if parsed == null:
			push_error("DataRegistry: failed to parse %s" % file_name)
			continue
		tables[table_name] = parsed

func get_table(table_name: String) -> Dictionary:
	return tables.get(table_name, {})

func get_record(table_name: String, id: String) -> Dictionary:
	return get_table(table_name).get(id, {})

## Cross-reference validation. Returns a list of human-readable problems;
## empty means the content set is consistent.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var items: Dictionary = get_table("items")
	var research: Dictionary = get_table("research")
	var aliens: Dictionary = get_table("aliens")
	var facilities: Dictionary = get_table("facilities")

	for table_name: String in ["items", "aliens", "facilities", "research", "crafts", "ufos", "nations", "soldiers"]:
		if not tables.has(table_name):
			problems.append("missing table '%s'" % table_name)

	for id: String in items:
		var item: Dictionary = items[id]
		if item.has("clip") and not items.has(item["clip"]):
			problems.append("items/%s: clip '%s' not found" % [id, item["clip"]])
		if item.has("requires_research") and not research.has(item["requires_research"]):
			problems.append("items/%s: research '%s' not found" % [id, item["requires_research"]])

	for id: String in research:
		var project: Dictionary = research[id]
		for req: String in project.get("requires", []):
			if not research.has(req):
				problems.append("research/%s: prerequisite '%s' not found" % [id, req])
		if project.has("needs_item") and not items.has(project["needs_item"]):
			problems.append("research/%s: needs_item '%s' not found" % [id, project["needs_item"]])
		if project.has("needs_live_alien") and not aliens.has(project["needs_live_alien"]):
			problems.append("research/%s: needs_live_alien '%s' not found" % [id, project["needs_live_alien"]])
		if project.has("unlocks_manufacture") and not items.has(project["unlocks_manufacture"]):
			problems.append("research/%s: unlocks_manufacture '%s' not found" % [id, project["unlocks_manufacture"]])
		if project.has("unlocks_facility") and not facilities.has(project["unlocks_facility"]):
			problems.append("research/%s: unlocks_facility '%s' not found" % [id, project["unlocks_facility"]])
		if project.has("unlocks_research"):
			for unlocked: String in project["unlocks_research"]:
				if not research.has(unlocked):
					problems.append("research/%s: unlocks_research '%s' not found" % [id, unlocked])

	for id: String in aliens:
		var alien: Dictionary = aliens[id]
		if alien.has("corpse_item") and not items.has(alien["corpse_item"]):
			problems.append("aliens/%s: corpse_item '%s' not found" % [id, alien["corpse_item"]])
		if alien.has("live_capture_research") and not research.has(alien["live_capture_research"]):
			problems.append("aliens/%s: live_capture_research '%s' not found" % [id, alien["live_capture_research"]])
		var loadout: Dictionary = alien.get("loadout", {})
		for slot: String in loadout:
			var contents: Variant = loadout[slot]
			var slot_items: Array = contents if contents is Array else [contents]
			for item_id: String in slot_items:
				if not items.has(item_id):
					problems.append("aliens/%s: loadout item '%s' not found" % [id, item_id])

	for id: String in facilities:
		var facility: Dictionary = facilities[id]
		var req: Variant = facility.get("requires_research")
		if req != null and not research.has(req):
			problems.append("facilities/%s: research '%s' not found" % [id, req])

	for id: String in get_table("ufos"):
		var ufo: Dictionary = get_table("ufos")[id]
		for alien_id: String in ufo.get("crew", {}):
			if not aliens.has(alien_id):
				problems.append("ufos/%s: crew alien '%s' not found" % [id, alien_id])
		for item_id: String in ufo.get("loot", {}):
			if not items.has(item_id):
				problems.append("ufos/%s: loot item '%s' not found" % [id, item_id])

	var soldier_config: Dictionary = get_table("soldiers").get("config", {})
	for portrait: String in soldier_config.get("portraits", []):
		if not ResourceLoader.exists(portrait):
			problems.append("soldiers/config: portrait '%s' not found" % portrait)

	return problems

func _load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("DataRegistry: JSON error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
