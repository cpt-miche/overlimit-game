# Dialogue Authoring Format

Dialogue content is data-driven under `resources/dialogue/`.

## Files

- `resources/dialogue/speakers.json` — speaker metadata and default portraits.
- `resources/dialogue/dialogues/*.json` — dialogue graphs split by character/arc.
- `resources/dialogue/localization/en.json` — localized string table (`text_key` -> text).

## Naming Conventions

- **Speaker IDs**: `snake_case`, stable identifiers (e.g. `martial_artist_battle`).
- **Dialogue IDs**: `<encounter>_intro` style (e.g. `martial_artist_intro`).
- **Node IDs**: short local IDs in a dialogue (`intro_1`, `battle_event`, `check_victory`).
- **Text keys**: `dlg.<dialogue_id>.<node_or_choice_id>`.


## Fast Path: Linear Scene Authoring (No Localization Required)

If your story is mostly linear, you can author dialogue under the optional `scenes` map in any file under `resources/dialogue/dialogues/`.
Each scene is automatically converted into nodes at load-time, so you only write line order and portraits.

```json
{
  "scenes": {
    "martial_artist_linear_intro": {
      "player_speaker_id": "player",
      "npc_speaker_id": "martial_artist",
      "lines": [
        {
          "speaker_id": "martial_artist",
          "npc_portrait": "res://assets/portraits/martial_artist_angry.png",
          "text": "So this is Earth? Pathetic."
        },
        {
          "speaker_id": "player",
          "player_portrait": "res://assets/portraits/player_determined.png",
          "text": "You're not getting past me."
        }
      ],
      "end_action": "request_battle"
    }
  }
}
```

Scene fields:
- `lines` (required): ordered array of dialogue lines.
- `speaker_id` (required on each line): used for name + default side/portrait fallback.
- `text` or `text_key` (one required): inline text is supported, so localization is optional.
- `player_portrait` / `npc_portrait` (optional): per-line PNG override.
- `end_action` (optional): e.g. `request_battle` to jump into combat after the last line.
- `enemy_id` (optional): explicit enemy for `request_battle` events.

Use the scene key as your NPC `dialogue_key` in `WorldIso.tscn`/`enemy_npc.gd` config.

## Node Types

- `line`
  - Required: `speaker_id`, (`text` or `text_key`), `next`.
  - Optional: `player_speaker_id`, `npc_speaker_id`, `player_portrait`, `npc_portrait`.
- `choice`
  - Required: `choices` (array).
  - Each choice requires: `text_key`, `next`.
  - Optional on choice: `set_flags`.
- `condition`
  - Required: `check`, `true_next`, `false_next`.
  - `check.kind` examples:
    - `prior_victory` with `id` set to an enemy id (`martial_artist`).
    - `prior_victory_current_enemy` (no `id` needed; uses the current encounter enemy).
- `event`
  - Required: `action`.
  - Optional: `next` for non-terminal events.
- `jump`
  - Required: `target`.
- `end`
  - Explicit terminal node.

## Localization Key Pattern

User-facing text can be authored with either inline `text` or a `text_key`. Use `text_key` only when you want localization support.

Example:

```json
{
  "type": "line",
  "speaker_id": "martial_artist",
  "text_key": "dlg.martial_artist_intro.intro_1",
  "next": "intro_2"
}
```

Localization entries live in `resources/dialogue/localization/en.json`:

```json
{
  "entries": {
    "dlg.martial_artist_intro.intro_1": "Hey. You move like someone who's trained hard."
  }
}
```

## Fallback Rules

Runtime fallback order:

1. If `text_key` exists and is found in localization, localized text is used.
2. If `text_key` is missing or unresolved, optional inline `text` fallback is used.
3. If neither exists, `"..."` is shown.

Portrait fallback order:

1. Per-node portrait override (`player_portrait` / `npc_portrait`).
2. Per-node speaker override (`player_speaker_id` / `npc_speaker_id`) default portrait.
3. Dialogue-level default speaker portrait.
4. Existing portrait texture in UI.


Enemy despawn behavior in the world is controlled per NPC via `despawn_on_defeat` on `EnemyNPC` instances.
Set it to `false` for bosses/story NPCs you want to keep interactable after wins.

## Validation (Editor-Time)

Run the validator script:

```bash
godot --headless --path . --script res://scripts/tools/dialogue_validator.gd
```

Validator checks:

- broken node links (`next`, `target`, `true_next`, `false_next`, choice `next`)
- missing or unknown speaker IDs
- missing/invalid portraits
- duplicate IDs across dialogue JSON files (`dialogues`, `speakers`, `entries`)
- missing dialogue text (`text`/`text_key`) and unknown localization keys when `text_key` is used

## Optional CSV Workflow

Use `scripts/tools/dialogue_import_export.py` for localization tables:

```bash
python scripts/tools/dialogue_import_export.py export-localization \
  --input resources/dialogue/localization/en.json \
  --output /tmp/dialogue_en.csv

python scripts/tools/dialogue_import_export.py import-localization \
  --input /tmp/dialogue_en.csv \
  --output resources/dialogue/localization/en.json \
  --locale en
```
