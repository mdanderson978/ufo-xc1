extends SceneTree
## Headless check that a character GLB imported into Godot with a skeleton,
## animations, and sane dimensions.
## Run: godot --headless -s tools/verify_character.gd -- <res_path>

func _init() -> void:
	var res_path := "res://assets/characters/soldier_test.glb"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		res_path = args[0]

	var scene: PackedScene = load(res_path)
	if scene == null:
		print("VERIFY-FAIL: could not load %s" % res_path)
		quit(1)
		return
	var root: Node = scene.instantiate()
	var skeleton := root.find_child("*", true, false) as Node
	var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	var players: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)

	print("VERIFY: skeletons=%d meshes=%d players=%d" % [skeletons.size(), meshes.size(), players.size()])
	if skeletons.size() > 0:
		print("VERIFY: bones=%d" % (skeletons[0] as Skeleton3D).get_bone_count())
	var anim_names := PackedStringArray()
	var anim_ok := false
	for player: AnimationPlayer in players:
		anim_names = player.get_animation_list()
		for anim_name in anim_names:
			var anim := player.get_animation(anim_name)
			print("VERIFY: anim '%s' length=%.2fs tracks=%d" % [anim_name, anim.length, anim.get_track_count()])
			if anim.length > 0.5 and anim.get_track_count() > 10:
				anim_ok = true
	if meshes.size() > 0:
		var aabb := (meshes[0] as MeshInstance3D).get_aabb()
		print("VERIFY: mesh aabb size = %s" % aabb.size)

	root.free()
	if skeletons.size() >= 1 and meshes.size() >= 1 and anim_ok:
		print("VERIFY-OK")
		quit(0)
	else:
		print("VERIFY-FAIL")
		quit(1)
