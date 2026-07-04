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

func test_all_registered_screens_enter_tree() -> void:
	var main_script: GDScript = load("res://src/main.gd")
	for screen_id: String in main_script.SCREENS:
		var scene: PackedScene = load(main_script.SCREENS[screen_id])
		var node: Node = scene.instantiate()
		add_child(node)
		await get_tree().process_frame
		assert_true(node.is_inside_tree(), "screen '%s' failed to enter tree" % screen_id)
		node.queue_free()
		await get_tree().process_frame

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
	# Campaign state is canonical (Jsonish.normalised) at creation and load,
	# so the round-trip must be byte-identical.
	assert_eq(JSON.stringify(GameState.to_save_dict()), JSON.stringify(before))
