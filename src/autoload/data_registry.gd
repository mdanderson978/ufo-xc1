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

func _load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("DataRegistry: JSON error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
