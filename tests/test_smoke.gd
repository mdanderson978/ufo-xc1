extends GutTest
## Phase 0 smoke tests: project skeleton is intact, autoloads exist,
## every registered screen scene instantiates, save round-trips.

func test_autoloads_present() -> void:
	assert_not_null(EventBus, "EventBus autoload missing")
	assert_not_null(DataRegistry, "DataRegistry autoload missing")
	assert_not_null(GameState, "GameState autoload missing")
	assert_not_null(SaveManager, "SaveManager autoload missing")

func test_all_registered_screens_instantiate() -> void:
	var main_script: GDScript = load("res://src/main.gd")
	for screen_id: String in main_script.SCREENS:
		var scene: PackedScene = load(main_script.SCREENS[screen_id])
		assert_not_null(scene, "screen '%s' failed to load" % screen_id)
		var node: Node = scene.instantiate()
		assert_not_null(node, "screen '%s' failed to instantiate" % screen_id)
		node.free()

func test_new_campaign_sets_state() -> void:
	GameState.new_campaign()
	assert_true(GameState.campaign_active)
	assert_eq(GameState.campaign["calendar"]["year"], 1999)

func test_save_load_round_trip() -> void:
	GameState.new_campaign()
	GameState.campaign["funds"] = 1_234_567
	var before := GameState.to_save_dict()
	assert_eq(SaveManager.save_campaign("gut_test_slot"), OK)
	GameState.campaign = {}
	assert_eq(SaveManager.load_campaign("gut_test_slot"), OK)
	# JSON round-trip turns ints into floats; compare via JSON normal form.
	assert_eq(JSON.stringify(GameState.to_save_dict()), JSON.stringify(_json_normalised(before)))

func _json_normalised(data: Dictionary) -> Variant:
	var json := JSON.new()
	json.parse(JSON.stringify(data))
	return json.data
