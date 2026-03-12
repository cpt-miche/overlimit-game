# Dialogue Authoring Format

Dialogue content is data-driven under `resources/dialogue/`.

## Files

- `resources/dialogue/speakers.json` — speaker metadata and default portraits.
- `resources/dialogue/dialogues.json` — dialogue graphs (nodes + links).
- `resources/dialogue/localization/en.json` — localized string table (`text_key` -> text).

## Naming Conventions

- **Speaker IDs**: `snake_case`, stable identifiers (e.g. `martial_artist_battle`).
- **Dialogue IDs**: `<encounter>_intro` style (e.g. `raditz_intro`).
- **Node IDs**: short local IDs in a dialogue (`intro_1`, `battle_event`, `check_victory`).
- **Text keys**: `dlg.<dialogue_id>.<node_or_choice_id>`.

## Node Types

- `line`
  - Required: `speaker_id`, `text_key`, `next`.
  - Optional: `player_speaker_id`, `npc_speaker_id`, `player_portrait`, `npc_portrait`.
- `choice`
  - Required: `choices` (array).
  - Each choice requires: `text_key`, `next`.
  - Optional on choice: `set_flags`.
- `condition`
  - Required: `check`, `true_next`, `false_next`.
- `event`
  - Required: `action`.
  - Optional: `next` for non-terminal events.
- `jump`
  - Required: `target`.
- `end`
  - Explicit terminal node.

## Localization Key Pattern

All user-facing dialogue/choice text should be authored with `text_key`.

Example:

```json
{
  "type": "line",
  "speaker_id": "raditz",
  "text_key": "dlg.raditz_intro.intro_1",
  "next": "intro_2"
}
```

Localization entries live in `resources/dialogue/localization/en.json`:

```json
{
  "entries": {
    "dlg.raditz_intro.intro_1": "Kakarot's weakling friend? You're in my way."
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
- missing `text_key` and unknown localization keys

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

