# Afterburner Zero — Progress & Context Summary

**Last Updated:** Phase 3 Parallax Background System (2026-11-28)  
**Engine:** Godot 4.7.1 (GDScript)  
**Main Specification:** `2026-11-18-afterburner-zero-5level-design.md`  
**GitHub Repository:** [https://github.com/babajix-lol/Afterburner-Zero](https://github.com/babajix-lol/Afterburner-Zero) (`master` branch, Public)  
**Godot CLI Executable:** `C:\Users\razi ahnaf fawwaz\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`

---

## 1. Quick Orientation for AI Agents

When continuing this project, read this file first. It summarizes the architecture, completed phases, and exact paths so you don't need to re-read the entire codebase.

### Key Architectural Rules (from Design Spec):
- **Single Source of Truth:** `2026-11-18-afterburner-zero-5level-design.md`.
- **Hybrid Level Architecture:** All levels inherit `res://levels/base_level.tscn` driven by `LevelData.tres` and `WaveData.tres`.
- **Decoupling:** Gameplay logic only emits signals on `EventBus`. UI/HUD only listens to `EventBus` and reads `GameManager`.
- **Entities Container:** All instanced bullets, enemies, pickups, and bosses must be children of `Entities` (or the `entities` group) for clean per-level garbage collection.
- **Asset Reuse Principle:** No new sprite files needed. Elite enemies and bosses use existing sprites with `modulate` color tint, `scale` increases, and unique firing patterns.
- **Weapon Persistence:** Weapons reset to Default Cannon on level transitions and on player death (§4.1).
- **Bomb Persistence:** Player starts each level with 1 bomb (§4.2).

---

## 2. Completed Work (Phase 1 & Phase 2)

### Autoload Singletons (`autoload/`)
- `GameManager.gd`: Owns run state (lives, score, bombs, active weapon, level index). Reset logic for death & level change implemented.
- `EventBus.gd`: Global event bus (`score_changed`, `lives_changed`, `bomb_changed`, `weapon_changed`, `shield_changed`, `combo_changed`, `wave_started`, `boss_started`, `level_completed`, `player_died`).
- `SceneRouter.gd`: Handles smooth screen fade-in/out and level loading.
- `SaveManager.gd`: Saves/loads `unlocked_level`, `best_score`, and volume settings to `user://afterburner_zero_save.json`.
- `AudioManager.gd`: Background music channel (`process_mode = PROCESS_MODE_ALWAYS`, auto-loop via `finished`, fade-in/fade-out, `play_music_path()`) + 8-voice concurrent SFX pool.

### Core Data Models (`resources/`)
- `LevelData.gd`: Level index, briefing/victory dialog, scroll speed, BGM, boss scene, wave list, difficulty dictionary.
- `WaveData.gd`: Enemy scene, count, spawn group (`spawn_top`, `spawn_left`, `spawn_right`), interval, delay, formation (`line`, `vee`, `random`), `is_boss_arena`.
- `WeaponData.gd`: Display name, bullet scene, fire rate, damage, projectile count, spread angle, `is_homing`.
- `EnemyData.gd`: HP, move pattern, fire pattern, fire interval, bullet scene, score value, drop table, elite flags (`is_elite`, `elite_modulate`, `elite_scale`).

### Player (`player/`)
- `player.tscn` / `player.gd`: 8-way floating movement (170 px/s), Barrel Roll (`Shift`/`Space`) with 0.3s i-frames and 1.0s cooldown, Hurtbox, take damage, invulnerability flash, screen-clear bomb activation (`B`/`L`).
- `player_weapon.gd`: Reads active weapon from `GameManager.weapon` or falls back to Default Cannon. Spawns single, spread fan, or homing missiles.
- `shield_ring.gd`: Procedurally rendered dynamic shield bubble when Shield pickup is active.

### Projectiles & Weapons (`projectiles/`, `data/weapons/`)
- `player_bullet.gd` / `player_bullet.tscn`: Configurable speed, damage, heading, homing, and piercing (`is_piercing`).
- `missile.gd` / `missile.tscn`: Homing missile projectile with target tracking.
- `laser.tscn`: Fast piercing beam projectile.
- `enemy_bullet.gd` / `enemy_bullet.tscn`: Supports custom tint, scale, direction, and damage. Group `enemy_bullets`.
- Weapons:
  - `data/weapons/spread.tres`: 3-way spread (30°), fire rate 7.0, damage 1.
  - `data/weapons/laser.tres`: Piercing beam, fire rate 3.0, damage 3.
  - `data/weapons/homing.tres`: 2 tracking missiles, fire rate 2.5, damage 2.

### Pickups & Combos (`pickups/`, `levels/combo_tracker.gd`)
- `pickup_base.gd`: Reusable drop script with bobbing animation and despawn blink.
- `heart.tscn`: Restores +1 life.
- `shield.tscn`: Grants 6 seconds temporary invulnerability.
- `bomb.tscn`: Adds +1 bomb.
- `weapon_crate.tscn`: Grants Spread, Laser, or Homing weapon (random if unspecified).
- `combo_tracker.gd`: Increases score multiplier from `×1` to `×5` on rapid kills within 2 seconds.

### Enemies (`enemies/`)
- `enemy_base.gd`: Unified enemy logic. Handles move patterns (`straight`, `sine`, `hover`, `dive`, `static`), fire patterns (`straight`, `burst3`, `aimed`, `spread_fan`, `triple`, `carpet`, `cross_volley`, `sweep_line`), difficulty scaling from `LevelData`, hit flash, drop spawning, and combo tracking.
- Enemy scenes:
  - `army.tscn`: Basic soldier (HP 1, straight fire).
  - `humvee.tscn`: Armored vehicle (HP 2, straight fire).
  - `heli.tscn`: Helicopter (HP 3, sine movement, burst-3 fire).
  - `bomber.tscn`: Heavy aircraft (HP 5, hover movement, carpet bomb fire).
  - `turret.tscn`: Static AA Turret (HP 2, aimed fire at player).
  - `army_elite.tres`: Elite soldier variant (recolored crimson, larger, fires 3-way fan).

### Base Level Template & HUD (`levels/`, `ui/`)
- `levels/base_level.tscn` / `base_level.gd`: Root template with `Background` (Ground/Props `TileMapLayer`), `Entities`, `SpawnPoints` (`spawn_top`, `spawn_left`, `spawn_right`), `PlayerSpawn`, `BossArena`, scrolling `Camera2D`, `WaveManager`, `ComboTracker`, and `HUD`.
- `levels/wave_manager.gd`: Spawns waves sequentially from `LevelData.waves`.
- `ui/hud.tscn` / `ui/hud.gd`: Displays score, heart containers, bomb counter, active weapon, animated combo multiplier (`x1`–`x5`), and wave banner alerts.
- Level 1 Test: `levels/level_01.tscn` backed by `data/levels/level_01.tres` (5 waves).

### Audio & Background Music (`assets/audio/bgm/`, `_tools/generate_bgm.py`)
- `_tools/generate_bgm.py`: Pure-Python procedural Arcade Synthwave / Darksynth WAV generator (44.1 kHz, 16-bit stereo, seamless bar-aligned loops).
- Generated tracks in `assets/audio/bgm/`:
  - `bgm_menu.wav` (110 BPM): Wired to `ui/splash.gd`, `ui/main_menu.gd`, `ui/level_select.gd`.
  - `bgm_level_01.wav` – `bgm_level_05.wav` (128–154 BPM): Assigned to `background_music` in `data/levels/level_01.tres` – `level_05.tres`.
  - `bgm_boss.wav` (156 BPM): Triggered in `levels/base_level.gd` inside `enter_boss_arena()`.
  - `bgm_victory.wav` (105 BPM): Triggered in `levels/base_level.gd` (`_on_level_completed`) and `ui/victory.gd`.
  - `bgm_gameover.wav` (84 BPM): Triggered in `ui/game_over.gd`.
- **Note for next agent:** Open the project in Godot Editor (or run a Godot import pass) so `.wav.import` files are generated for the new files in `assets/audio/bgm/`. SFX streams are still unassigned (only BGM was added).

### Parallax Background System (`levels/`, `resources/`, `data/levels/`)
- `resources/LevelData.gd`: Added `background_texture: Texture2D`, `midground_texture: Texture2D`, and `sky_color: Color` exports.
- `levels/base_level.tscn`: Added `Sky` (ColorRect, z=-3), `Midground` (Sprite2D, z=-1) nodes under `Background`. Both driven by `LevelData` values at runtime.
- `levels/base_level.gd`:
  - On `_ready()`: reads `data.sky_color` → `Sky.color`; reads `data.background_texture` → `Backdrop.texture`; reads `data.midground_texture` → `Midground.texture` with 72% alpha tinted by `environment_tint`.
  - On `_physics_process()`: `Midground` scrolls at **55% of camera speed** for parallax depth effect; wraps at 8000 px to match tile region.
- Level data (`data/levels/level_01.tres` – `level_05.tres`): assigned unique `background_texture`, `midground_texture`, and `sky_color` per level:
  - L1 Highway Breach: `background_1.png` / `Building2_1.png` / sky `Color(0.72, 0.84, 1.0)` (siang cerah)
  - L2 Downtown Corridor: `Ruin_City_1.png` / `Building3_1.png` / sky `Color(1.0, 0.55, 0.18)` (sore merah-oranye)
  - L3 Industrial District: `background_1.png` / `Building1_1.png` / sky `Color(0.44, 0.48, 0.52)` (mendung abu-abu)
  - L4 Harbor Siege: `sprBG_1.png` / `Building2_1.png` / sky `Color(0.12, 0.18, 0.38)` (malam biru tua)
  - L5 Zero Hour: `Black_1.png` / `Ruin_City_1.png` / sky `Color(0.56, 0.06, 0.04)` (merah perang)
- Level scenes (`levels/level_01.tscn` – `level_05.tscn`): `environment_tint` updated per level for consistent Backdrop modulation.
- **Note for next agent:** `Midground` node needs `region_rect` and `texture_repeat` verified in Godot Editor for each per-level texture (especially `Ruin_City_1.png` which is 4340×725 — may need `region_rect = Rect2(0,0,640,725)` tiled). SFX streams still unassigned.

---

## 3. What Needs to Be Built Next (Phase 3)

1. **Bosses (`bosses/`):**
   - `boss_base.gd`: Common boss controller (health bar, phases, arena behavior, death event).
   - `boss_heli.tscn`: Gunship Heli (Level 2 mini-boss, spread fire).
   - `boss_bomber.tscn`: Bomber Command (Level 3 boss, carpet bomb + spread).
   - `boss_twin.tscn`: Twin Gunship (Level 4 boss, 2 large helis, 2 phases).
   - `boss_dreadnought.tscn`: Warlord Dreadnought (Level 5 final boss, 3 phases: fan+adds, carpet+sweep line, spiral+helis).
2. **Levels 1–5 Data & Scenes (`data/levels/`, `levels/`):**
   - Level 2: Downtown Corridor (`level_02.tres` / `level_02.tscn`)
   - Level 3: Industrial District (`level_03.tres` / `level_03.tscn`)
   - Level 4: Harbor Siege (`level_04.tres` / `level_04.tscn`)
   - Level 5: Zero Hour: Black Site (`level_05.tres` / `level_05.tscn`)
   - Tilemaps & environment palettes (siang, sore, mendung, malam, merah) using existing assets.
3. **UI & Menus (`ui/`):**
   - `splash.tscn`: Brief 2-line premise story intro (§3.1).
   - `main_menu.tscn`: Play, Level Select, Settings, Quit.
   - `level_select.tscn`: Shows unlocked levels (reads `SaveManager.get_unlocked_level()`).
   - `dialog_box.tscn`: Briefing and victory dialogue (§3.5).
   - `pause_menu.tscn`: In-game pause menu (`process_mode = PROCESS_MODE_ALWAYS`).
   - `game_over.tscn`: Retry level from beginning or return to menu.
   - `victory.tscn`: Ending mission complete screen.

---

## 4. Useful Verification Commands

Run these from the project root (`c:\Users\razi ahnaf fawwaz\OneDrive\Dokumen\afterburner-zero`):

- **Script Syntax & Compile Check:**
  ```powershell
  & "C:\Users\razi ahnaf fawwaz\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script "C:\Users\razi ahnaf fawwaz\.trae\skills\godot-gdscript\assets\check_scripts_compile.gd"
  ```
- **Project Structure & Node Reference Check:**
  ```powershell
  python "C:\Users\razi ahnaf fawwaz\.trae\skills\godot-nodes-scenes\scripts\check_godot_project.py" .
  ```
- **Headless Scene Smoke Test:**
  ```powershell
  & "C:\Users\razi ahnaf fawwaz\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --fixed-fps 60 --quit-after 180 --scene "res://levels/level_01.tscn"
  ```
- **Regenerate Procedural BGM Tracks:**
  ```powershell
  python _tools/generate_bgm.py
  ```
- **Push to GitHub:**
  ```powershell
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User"); gh auth setup-git; git push origin master
  ```
