# DB Fangame - Godot Isometric MVP

This repository now includes a Godot 4.x vertical-slice foundation for a top-down isometric exploration flow with turn-based Dragon Ball-inspired combat.

## Implemented foundation
- Godot project bootstrap (`project.godot`) with main scene wiring.
- Isometric world scene scaffold with:
  - player controller (`WASD` input),
  - enemy NPC interaction (`E` to challenge),
  - optional pre-battle dialogue/cutscene flow with portraits,
  - world-to-battle transition signal flow.
- Battle scene scaffold with:
  - battle controller,
  - action buttons (`strike`, `ki_blast`, `ki_volley`, `ki_barrage`, `power_up`) plus a `transform` dropdown (`Super Saiyan`, `Shuten`),
  - ki infusion slider,
  - log/status labels.
- Data-driven combat definitions via `Resource` files:
  - fighter stats,
  - attack definitions,
  - transformation definition (Shuten).
- Core combat resolver logic for:
  - escalation hold-back suppression,
  - stamina/drawn-ki mitigation,
  - vanish + potential counter,
  - hit/miss and damage resolution,
  - per-turn Shuten drain.

## Quick start (Godot)
1. Install Godot 4.x.
2. Open this folder as a Godot project.
3. Run the project (`F5`) to launch `scenes/main/Main.tscn`.

## Exporting executable
In Godot:
1. `Project -> Export`
2. Add preset: **Windows Desktop**
3. Export project to produce self-contained desktop build artifacts.

## Key directories
- `scenes/` scene hierarchy
- `scripts/` gameplay logic (world, battle, core models)
- `resources/` data-driven combat configuration
- `assets/` placeholder art folders and templates
- `docs/` implementation notes
