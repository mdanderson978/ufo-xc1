extends GutTest
## Phase 1: data tables load, cross-references hold, campaign factory
## produces a coherent deterministic starting state that survives save/load.

func test_all_tables_present_and_valid() -> void:
	var problems := DataRegistry.validate()
	assert_eq(problems.size(), 0, "data problems: %s" % ", ".join(problems))
	assert_gt(DataRegistry.get_table("items").size(), 10)
	assert_eq(DataRegistry.get_table("nations").size(), 16)
	assert_eq(DataRegistry.get_table("aliens").size(), 3)
	assert_gte(DataRegistry.get_table("research").size(), 12)
	assert_gt(DataRegistry.get_table("terrain").size(), 10)

func test_new_campaign_is_deterministic() -> void:
	var a := CampaignFactory.new_campaign(DataRegistry, 1234)
	var b := CampaignFactory.new_campaign(DataRegistry, 1234)
	assert_eq(JSON.stringify(a), JSON.stringify(b), "same seed must give same campaign")
	var c := CampaignFactory.new_campaign(DataRegistry, 99)
	assert_ne(JSON.stringify(a), JSON.stringify(c), "different seed must differ")

func test_starting_base_shape() -> void:
	var campaign := CampaignFactory.new_campaign(DataRegistry, 7)
	assert_eq(campaign["bases"].size(), 1)
	var base: Dictionary = campaign["bases"][0]
	assert_eq(base["soldiers"].size(), CampaignFactory.START_SOLDIERS)
	assert_eq(base["crafts"].size(), 2)
	# Every facility type exists and every soldier stat is inside its range.
	for facility: Dictionary in base["facilities"]:
		assert_true(DataRegistry.get_table("facilities").has(facility["type"]),
			"unknown facility %s" % facility["type"])
	var ranges: Dictionary = DataRegistry.get_table("soldiers")["config"]["stat_ranges"]
	for soldier: Dictionary in base["soldiers"]:
		assert_eq(soldier["xp"], 0)
		assert_eq(soldier["rank"], "Rookie")
		for stat: String in ranges:
			var value: int = soldier["stats"][stat]
			assert_between(value, int(ranges[stat][0]), int(ranges[stat][1]),
				"%s.%s out of range" % [soldier["name"], stat])
	# Starting gear must reference real items.
	for item_id: String in base["stores"]:
		assert_true(DataRegistry.get_table("items").has(item_id))

func test_campaign_save_load_round_trip() -> void:
	GameState.new_campaign(4242)
	var before := JSON.stringify(GameState.to_save_dict())
	assert_eq(SaveManager.save_campaign("gut_campaign_slot"), OK)
	GameState.campaign = {}
	assert_eq(SaveManager.load_campaign("gut_campaign_slot"), OK)
	# Everything in the campaign dict is JSON-native, so this must be lossless.
	assert_eq(JSON.stringify(GameState.to_save_dict()), before)

func test_apply_battle_result_updates_soldier_records() -> void:
	var campaign := CampaignFactory.new_campaign(DataRegistry, 7)
	var battle_result := {
		"xcom_survivors": PackedStringArray(["xcom_1"]),
		"xcom_losses": PackedStringArray(["xcom_2"]),
		"xcom_kills": {"xcom_1": 1, "xcom_2": 2},
		"xcom_xp": {"xcom_1": 35, "xcom_2": 50}
	}
	var updated := CampaignFactory.apply_battle_result(campaign, battle_result)
	var original_soldier: Dictionary = campaign["bases"][0]["soldiers"][0]
	var survivor: Dictionary = updated["bases"][0]["soldiers"][0]
	var casualty: Dictionary = updated["bases"][0]["soldiers"][1]
	var uninvolved: Dictionary = updated["bases"][0]["soldiers"][2]

	assert_eq(original_soldier["missions"], 0, "campaign input should not be mutated")
	assert_eq(survivor["missions"], 1)
	assert_eq(survivor["kills"], 1)
	assert_eq(survivor["xp"], 35)
	assert_eq(survivor["rank"], "Squaddie")
	assert_eq(survivor["status"], "active")
	assert_eq(casualty["missions"], 1)
	assert_eq(casualty["kills"], 2)
	assert_eq(casualty["xp"], 50)
	assert_eq(casualty["rank"], "Squaddie")
	assert_eq(casualty["status"], "dead")
	assert_eq(casualty["wounds_days_left"], 0)
	assert_eq(uninvolved["missions"], 0)

func test_game_state_applies_battle_result_to_active_campaign() -> void:
	GameState.new_campaign(9)
	var battle_result := {
		"xcom_survivors": PackedStringArray(["xcom_1"]),
		"xcom_losses": PackedStringArray(),
		"xcom_kills": {"xcom_1": 1},
		"xcom_xp": {"xcom_1": 35}
	}
	GameState.apply_battle_result(battle_result)
	var soldier: Dictionary = GameState.campaign["bases"][0]["soldiers"][0]
	assert_eq(soldier["missions"], 1)
	assert_eq(soldier["kills"], 1)
	assert_eq(soldier["xp"], 35)
	assert_eq(soldier["rank"], "Squaddie")
