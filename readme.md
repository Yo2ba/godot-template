# 🎮 Godot Utility Framework & Game Template

![Godot Engine](https://img.shields.io/badge/Godot-4.6+-%23478cbf?logo=godot-engine&logoColor=white)
![Language](https://img.shields.io/badge/GDScript-Strictly_Typed-blue)
![Architecture](https://img.shields.io/badge/Architecture-Zero_Autoload_Static_API-success)

A lightweight, strictly-typed **Godot Game Template & Utility Framework** designed for game development and effortless upstream maintenance. Built entirely on **self-initializing static classes** (`class_name` + `_static_init()`), it requires **zero Project Autoloads** while providing out-of-the-box support for asynchronous scene transitions, on-demand multi-threaded resource loading, an introspective developer console (Commands & ConVars), persistent configuration, real-time performance telemetry, modal UI prompts, and validated binary serialization.

---

## 📑 Table of Contents

1. [Architecture & The Red `res://api/` Folder Rule](#-architecture--the-red-resapi-folder-rule)
2. [Getting Started (Clone vs. Fork Workflow)](#-getting-started-clone-vs-fork-workflow)
   - [Option A: Forking for Upstream Updates (Recommended)](#option-a-forking-for-upstream-updates-recommended)
   - [Option B: Cloning as a Standalone Project](#option-b-cloning-as-a-standalone-project)
   - [Opening in Godot](#opening-in-godot)
3. [Framework Utilities & API Reference](#-framework-utilities--api-reference)
   - [1. Developer Console (`Console`)](#1-developer-console-console)
   - [2. Asynchronous Scene Manager (`Scenes` & `LoadingScreen`)](#2-asynchronous-scene-manager-scenes--loadingscreen)
   - [3. Multi-Threaded Resource Loader (`ThreadedLoader`)](#3-multi-threaded-resource-loader-threadedloader)
   - [4. Settings & Performance Telemetry (`Settings` & `DebugMenu`)](#4-settings--performance-telemetry-settings--debugmenu)
   - [5. Modal Prompts & Core Wrapper (`Utils` & `Prompt`)](#5-modal-prompts--core-wrapper-utils--prompt)
   - [6. Binary Serialization (`BinarySaver` & `BinaryLoader`)](#6-binary-serialization-binarysaver--binaryloader)
4. [Project Configuration Requirements](#-project-configuration-requirements)

---

## 🧱 Architecture & The Red `res://api/` Folder Rule

This template is architected to strictly separate **core framework systems** from **your game-specific code and assets**.

```text

res://

├── 🔴 api/ <-- CORE FRAMEWORK (DO NOT MODIFY)

|   └── 🔴 scripts/
   
|         ├── 🔴 globals/...

|         └── 🔴 utils/...

├── example_folder1/

├── example_folder2/

├── utils/

|	├── audio_bus.tres

|	└── languages.tres

├── icon.svg

├── readme.md

└── splash.png
```

> ### 🛑 DO NOT TOUCH THE RED `res://api/` FOLDER!
> In the Godot Editor FileSystem dock, the **`res://api/`** directory is color-coded **RED**.
>
> **Why?** All framework utilities, self-initializing static classes, and internal UI prefabs live inside `res://api/`. Because every core system uses globally accessible `class_name` static scripts rather than `project.godot` Autoload entries, treating `res://api/` as a **read-only internal library** and building your game entirely outside of it allows you to pull bug fixes, optimizations, and new features from the upstream template repository at any time with **zero merge conflicts**.

---

## 🚀 Getting Started (Clone vs. Fork Workflow)

Depending on whether you want to receive future framework updates, choose one of the two workflows below.

### Option A: Forking for Upstream Updates (Recommended)

Use this workflow if you want to develop your game while keeping the ability to merge future improvements made to the core `res://api/` framework.

1. **Fork the Repository:**
   Click the **Fork** button at the top-right of the repository page to create a copy under your own GitHub/GitLab account.

2. **Clone Your Fork:**
   ```bash
   git clone https://github.com/<your-username>/<your-game-repo>.git
   cd <your-game-repo>
   ```

3. **Add the Original Template as `upstream`:**
   ```bash
   git remote add upstream https://github.com/<original-owner>/<template-repo>.git
   git remote -v
   ```

4. **Syncing Updates from Upstream Later:**
   Whenever the framework receives an update, fetch and merge `upstream` into your main branch:
   ```bash
   git fetch upstream
   git checkout main
   git merge upstream/main
   ```
   *Because you never modified files inside the red `res://api/` folder, Git will cleanly update the framework without touching your game files!*

---

### Option B: Cloning as a Standalone Project

Use this workflow if you want a fresh, isolated starting point and do not need to pull future upstream updates.

1. **Clone the Repository into Your Game Folder:**
   ```bash
   git clone https://github.com/<original-owner>/<template-repo>.git my-awesome-game
   cd my-awesome-game
   ```

2. **(Optional) Re-initialize Git History:**
   If you want to start with a clean commit history for your new game:
   ```bash
   rm -rf .git
   git init
   git add .
   git commit -m "Initial commit from framework template"
   ```

---

### Opening in Godot

1. Launch **Godot Engine 4.6+**.
2. In the **Project Manager**, click **Import**.
3. Navigate to your cloned folder, select `project.godot`, and click **Import & Edit**.
4. Create your own folders (e.g., `res://game/`, `res://scenes/`, `res://scripts/`) and start building! Leave the **red `res://api/`** folder untouched.

---

## 🛠 Framework Utilities & API Reference

### 1. Developer Console (`Console`)

An introspective, zero-idle-overhead in-game developer console implemented as an `@abstract` static class (`class_name Console`). During `_static_init()`, it automatically mounts a dedicated `_ConsoleLayer` (`CanvasLayer` **10**) and instantiates the console UI onto the active `SceneTree`.

#### Key Features
* **Toggle Shortcut:** Press `` ` `` (Backtick / Grave Accent / `KEY_QUOTELEFT`) at any time during runtime to toggle the console window, or press `Escape` while open to close it.
* **Automatic Parameter Type Reflection:** `Console.register_command()` inspects the target `Callable`'s method signature once upon registration, caching parameter types (`int`, `float`, `bool`, `String`, `StringName`, `Variant`), default argument counts, and variadic flags so user input strings are validated and converted automatically before execution.
* **Implicit ConVar Binding & Type Inference:** `Console.register_convar()` automatically resolves the calling node instance via the call stack/scene tree and infers the property's `Variant.Type` from its initial value.
* **Smart Autocomplete & Navigation:**
  * Case-insensitive prefix and substring matching in the `HintList` dropdown, clamped vertically so suggestions never clip off-screen.
  * Smart auto-lowercasing on character entry when the typed prefix matches a registered command or ConVar (while preserving uppercase input when no prefix matches or when backspacing).
  * Hold `Up` / `Down` arrows for rapid scrolling through hints or command history, press `Tab` to cycle suggestions, or press `Right` arrow to accept an inline hint (automatically appending a trailing space for ConVars or commands taking arguments).
  * Free, unclamped window dragging with a $4\text{ px}$ drag deadzone on the close button and full `LineEdit` selection/hint persistence across focus loss and visibility toggles.

#### Static API Summary

| Static Method | Description |
|---|---|
| `Console.log(...args: Array) -> void` | Appends space-separated arguments to the console in $O(1)$ time. If the final argument is a `Color`, it tints that specific log line. |
| `Console.color(value: Color = Color.WHITE) -> void` | Sets the default fallback text color for subsequent `Console.log()` calls. |
| `Console.toggle_console() -> void` | Manually toggles the visibility of the console UI. |
| `Console.register_command(name: StringName, callback: Callable, description: String = "") -> void` | Registers a lowercase command and automatically extracts its parameter types, default arguments, and vararg flags. |
| `Console.register_convar(name: StringName, property: StringName = &"", description: String = "", target: Object = null) -> void` | Binds a console variable to a script property. Infers the property type and resolves `target` automatically if omitted. |
| `Console.unregister(name: StringName) -> void` | Removes a command or ConVar from the unified registry. |
| `Console.execute_command(name: StringName, raw_args: Array = []) -> void` | Parses string arguments into the callable's expected parameter types and executes the command. |
| `Console.get_convar_value(name: StringName) -> Variant` | Retrieves the current value of a registered ConVar. |
| `Console.set_convar_value(name: StringName, value: Variant) -> void` | Updates the value of a registered ConVar with strict type validation. |

#### Code Examples

```gdscript
extends CharacterBody3D

var god_mode: bool = false
var move_speed: float = 8.5

func _ready() -> void:
	# 1. Logging with optional trailing Color argument
	Console.log("Player initialized at position:", global_position, Color.GREEN)

	# 2. Registering Commands (parameter types & default args are inferred automatically!)
	Console.register_command(&"spawn_enemy", _cmd_spawn_enemy, "Spawns an enemy by ID and count")
	Console.register_command(&"heal", _cmd_heal, "Heals the player")

	# 3. Registering ConVars
	# Automatically binds to `self.god_mode` (property name matches ConVar name, owner & bool type inferred)
	Console.register_convar(&"god_mode", &"", "Toggle player invincibility")

	# Binds console ConVar `speed` to `self.move_speed`
	Console.register_convar(&"speed", &"move_speed", "Player movement speed")

func _exit_tree() -> void:
	# Clean up non-persistent scene commands/convars when the node leaves the tree
	Console.unregister(&"spawn_enemy")
	Console.unregister(&"heal")
	Console.unregister(&"god_mode")
	Console.unregister(&"speed")

# Typing `spawn_enemy goblin 3` in console automatically converts "goblin" -> String and "3" -> int
func _cmd_spawn_enemy(enemy_id: String, count: int = 1) -> void:
	Console.log("Spawning", count, "x", enemy_id, Color.CYAN)

func _cmd_heal(amount: float = 100.0) -> void:
	Console.log("Restored", amount, "HP", Color.GREEN_YELLOW)
```

---

### 2. Asynchronous Scene Manager (`Scenes` & `LoadingScreen`)

An `@abstract` static class (`class_name Scenes`) that manages background scene loading and transitions with a self-initializing `LoadingScreen` overlay (`CanvasLayer` **9**). Static signals are exposed cleanly through an internal `RefCounted` signal bus (`_SignalBus`).

It uses a **two-stage loading flow** (`Scenes.load_scene` $\rightarrow$ `Scenes.open_loaded_scene`), allowing you to transition immediately upon completion or wait for a player prompt (e.g., *"Press Any Key to Continue"*). While loading is active, `LoadingScreen` blocks all user inputs (`blocks_input = true`) until $0.2\text{ s}$ after the new scene is initialized.

#### Static Signals & Methods

| Member | Type | Description |
|---|---|---|
| `Scenes.scene_load_progress` | `Signal` | Emitted continuously during loading (`progress: float` from $0.0$ to $1.0$). |
| `Scenes.scene_load_finished` | `Signal` | Emitted when the background thread finishes loading the `PackedScene` (`success: bool`). |
| `Scenes.load_scene(scene_path: String) -> void` | `static func` | Shows the loading screen, blocks input, and begins loading `scene_path` via `ThreadedLoader`. |
| `Scenes.open_loaded_scene() -> void` | `static func` | Switches the active scene tree to the preloaded scene and hides the loading screen after stabilization. |

#### Code Example

```gdscript
# Immediate Scene Transition once background loading completes
func transition_to_level(level_path: String) -> void:
	Scenes.scene_load_finished.connect(
		func(success: bool) -> void:
			if success:
				Scenes.open_loaded_scene()
			else:
				Console.log("Failed to load scene:", level_path, Color.RED),
		CONNECT_ONE_SHOT
	)
	Scenes.load_scene(level_path)
```

---

### 3. Multi-Threaded Resource Loader (`ThreadedLoader`)

A static background resource loader (`class_name ThreadedLoader`) built on top of Godot's `ResourceLoader.load_threaded_request()`.

* **On-Demand Frame Polling:** Automatically connects `ThreadedLoader._process` to `SceneTree.process_frame` when a load request starts and disconnects itself the moment `active_load_requests` becomes empty—resulting in zero per-frame overhead when idle.
* **Smart Caching:** Immediately invokes the completion callback if the resource is already cached in memory.
* **Callback Batching:** If multiple scripts request the exact same uncached resource simultaneously, `ThreadedLoader` batches their callbacks onto a single background thread request.

#### Static API Summary

```gdscript
ThreadedLoader.load_async(
	resource_path: String,
	on_load_finished: Callable,               # Signature: func(resource: Resource) -> void
	on_progress_updated: Callable = Callable() # Optional Signature: func(progress: float) -> void
) -> void
```

#### Code Example

```gdscript
func load_heavy_boss_model() -> void:
	ThreadedLoader.load_async(
		"res://game/assets/models/dragon_boss.tscn",
		_on_boss_loaded,
		_on_boss_load_progress
	)

func _on_boss_load_progress(progress: float) -> void:
	print("Loading boss: %d%%" % int(progress * 100.0))

func _on_boss_loaded(resource: Resource) -> void:
	if resource == null:
		push_error("Failed to load boss resource!")
		return
	var boss_instance: Node3D = (resource as PackedScene).instantiate()
	add_child(boss_instance)
```

---

### 4. Settings & Performance Telemetry (`Settings` & `DebugMenu`)

Handles persistent user configuration saved to `user://settings.cfg` using `ConfigFile` and caches `AudioServer` bus indices at initialization for fast volume updates. Modifying any property on `Settings` automatically applies the engine/audio change **and** writes the updated setting to disk immediately.

It also drives the `DebugMenu` overlay on `CanvasLayer` **1**, which calculates and displays real-time **Max Frame Time ($\text{ms}$)**, **Average FPS** (color-coded green, orange, or red relative to `fps_max`), and **Physics Ticks per Second ($\text{t/s}$)** every $0.5\text{ s}$.

#### Built-in Properties & ConVars

| GDScript Property | Console ConVar | Type | Default | Description |
|---|---|---|---|---|
| `Settings.fps_max` | `fps_max` | `int` | `0` | Caps engine FPS (`0` = unlimited, otherwise clamped to $\ge 64$). |
| `Settings.showfps` | `showfps` | `bool` | `false` | Toggles the real-time Frame Time & Avg FPS counter overlay. |
| `Settings.showtick` | `showtick` | `bool` | `false` | Toggles the real-time Physics Ticks/s overlay. |
| `Settings.master_volume` | `volume` | `float` | `1.0` | Linear volume ($0.0$ to $1.0$) for the `Master` audio bus. Auto-mutes at $0.0$. |
| `Settings.music_volume` | `music` | `float` | `1.0` | Linear volume ($0.0$ to $1.0$) for the `music` audio bus. Auto-mutes at $0.0$. |
| `Settings.sfx_volume` | `sfx` | `float` | `1.0` | Linear volume ($0.0$ to $1.0$) for the `sfx` audio bus. Auto-mutes at $0.0$. |
| `Settings.console_position` | *(internal)* | `Vector2` | *Centered* | Persists the developer console window position. |
| `Settings.console_size` | *(internal)* | `Vector2` | `800x600` | Persists the developer console window dimensions. |

#### Code Example

```gdscript
# Changing properties automatically updates AudioServer/Engine and saves to user://settings.cfg
func _on_music_slider_value_changed(value: float) -> void:
	Settings.music_volume = value # Clamped between 0.0 and 1.0 automatically

func _on_fps_limit_selected(target_fps: int) -> void:
	Settings.fps_max = target_fps

# You can also save custom game settings to the same config file:
func save_custom_preference(fov: float) -> void:
	Settings.save_setting("camera_fov", fov)
```

---

### 5. Modal Prompts & Core Wrapper (`Utils` & `Prompt`)

`Utils` (`class_name Utils`) is a static utility facade for spawning modal confirmation dialogs (`Prompt`) onto `Engine.get_main_loop().root` and interacting with the binary save system.

#### Prompt Features
* **Singleton Safety:** Prevents multiple overlapping prompts from spawning simultaneously (`Utils.active_prompt` guard).
* **Pause Integration:** Can optionally pause the entire scene tree (`pause = true`) while remaining interactive via `Node.PROCESS_MODE_ALWAYS`.
* **Keyboard Navigation:** Automatically captures keyboard input—pressing `Enter` / `KP_Enter` confirms, and pressing `Escape` cancels and closes the modal.

#### Static API Summary

```gdscript
# Spawns a modal confirmation dialog
Utils.prompt(
	function: Callable,
	prompt_title: String,
	prompt_message: String,
	confirm_name: String = "Confirm",
	cancel_name: String = "Cancel",
	darken: bool = true,
	pause: bool = false
) -> Prompt

# Static wrapper methods for BinarySaver and BinaryLoader
Utils.save_file(path: String, data: Variant) -> Error
Utils.load_file(path: String) -> Dictionary
```

#### Code Example

```gdscript
func _on_quit_button_pressed() -> void:
	Utils.prompt(
		func() -> void: get_tree().quit(),
		"Exit Game",
		"Are you sure you want to quit? Any unsaved progress will be lost.",
		"Quit to Desktop",
		"Stay",
		true, # Darken background
		true  # Pause the scene tree while prompt is open
	)
```

---

### 6. Binary Serialization (`BinarySaver` & `BinaryLoader`)

`@abstract` static classes (`class_name BinarySaver` and `class_name BinaryLoader`) providing fast, custom-header binary file serialization and deserialization for saving game state, inventories, or profiles. Encodes any Godot `Variant` into bytes while validating file integrity and preventing memory overflow attacks.

#### Binary Format Specification (`YO2`)

| Offset | Size | Type | Value / Description |
|---|---|---|---|
| `0` | $3\text{ B}$ | `PackedByteArray` | Magic Identifier: `[89, 79, 50]` (`"YO2"`) |
| `3` | $4\text{ B}$ | `int32` | Format Version (`1`) |
| `7` | $8\text{ B}$ | `int64` | Payload Size in bytes (Max $256\text{ MiB}$) |
| `15` | $N\text{ B}$ | `PackedByteArray` | Encoded `Variant` Dictionary (`{"data": data}`) |

* **Auto-Directory Creation:** `Utils.save_file()` automatically creates any missing parent directories via `DirAccess.make_dir_recursive_absolute()`.
* **Corruption & Size Checks:** `Utils.load_file()` verifies the header length, magic bytes, format version, and ensures the payload size matches the remaining file bytes and does not exceed $256\text{ MiB}$ ($268,435,456\text{ B}$).

#### Code Example

```gdscript
const SAVE_PATH: String = "user://saves/slot_1.sav"

func save_player_progress() -> void:
	var save_data: Dictionary = {
		"level": 12,
		"health": 85.5,
		"inventory": ["sword_iron", "potion_health", "key_dungeon"],
		"position": Vector3(14.0, 2.0, -8.5)
	}
	var err: Error = Utils.save_file(SAVE_PATH, save_data)
	if err == OK:
		Console.log("Game saved successfully!", Color.GREEN)
	else:
		Console.log("Save failed with error code:", err, Color.RED)

func load_player_progress() -> void:
	var result: Dictionary = Utils.load_file(SAVE_PATH)
	if result["error"] != OK:
		Console.log("Failed to load save file! Error:", result["error"], Color.YELLOW)
		return
	var save_data: Dictionary = result["data"]
	Console.log("Loaded Level:", save_data["level"], "Inventory:", save_data["inventory"])
```

> [!NOTE]
> **Implementation Detail in `BinaryLoader`:** Ensure that `BinaryLoader.load_file()` reads `file.get_buffer(MAGIC.size())` ($3\text{ bytes}$) rather than `4` bytes when verifying `MAGIC = [89, 79, 50]`, as reading $4\text{ bytes}$ shifts the read cursor by $1\text{ byte}$ on the $15\text{-byte}$ header.

---

## ⚙️ Project Configuration Requirements

If you ever inspect or reconfigure `project.godot`, keep the following setup in mind:

1. **Zero Autoloads Required:**
   Because all framework utilities (`Console`, `Scenes`, `ThreadedLoader`, `Settings`, `Utils`, `BinarySaver`, and `BinaryLoader`) are implemented as globally registered `class_name` static scripts that self-bootstrap via `_static_init()` and `Engine.get_main_loop()`, **no scripts need to be added to Project Settings $\rightarrow$ Globals $\rightarrow$ Autoload**.

2. **Audio Buses:**
   The project's Audio Bus Layout (`res://utils/audio_bus.tres`) must include three buses (case-sensitive):
   * `Master`
   * `music`
   * `sfx`