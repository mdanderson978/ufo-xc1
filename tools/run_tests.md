# Running tests

The project uses GUT tests under `res://tests`.

From the repository root, run:

```powershell
.\tools\godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
```

For a specific test file:

```powershell
.\tools\godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/test_battle_rules.gd
```

The character import smoke check is separate because it extends `SceneTree`:

```powershell
.\tools\godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/verify_character.gd -- res://assets/characters/soldier_test.glb
```

Use the `_console.exe` launcher on Windows so PowerShell receives script and
test output.
