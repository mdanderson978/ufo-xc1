extends Node
## JSON save/load of the campaign in GameState.
## Saves live in user:// so they survive project updates.

const SAVE_DIR := "user://saves"

func save_campaign(slot_name: String) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := _slot_path(slot_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(GameState.to_save_dict(), "\t"))
	return OK

func load_campaign(slot_name: String) -> Error:
	var path := _slot_path(slot_name)
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return ERR_FILE_NOT_FOUND
	var json := JSON.new()
	if json.parse(text) != OK:
		return ERR_PARSE_ERROR
	GameState.from_save_dict(json.data)
	return OK

func list_saves() -> PackedStringArray:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return PackedStringArray()
	var slots := PackedStringArray()
	for file_name in dir.get_files():
		if file_name.get_extension() == "json":
			slots.append(file_name.get_basename())
	return slots

func _slot_path(slot_name: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot_name.validate_filename()]
