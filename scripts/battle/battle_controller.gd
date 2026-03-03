extends Node

signal battle_finished(result: String)

@export var player_base: FighterStats
@export var enemy_base: FighterStats

@export var attack_pool: Array[AttackDef] = []
@export var transformation_pool: Array[TransformationDef] = []

@onready var ui = $"../BattleUI"

var state := BattleState.new()
var resolver := CombatResolver.new()
var enemy_ai := EnemyAI.new()
var rng := RandomNumberGenerator.new()
var infusion_ratio: float = 0.0

var attacks: Dictionary = {}
var transformations: Dictionary = {}
var pending_result: String = ""

func _ready() -> void:
	rng.randomize()
	_initialize_skill_pools()
	ui.action_pressed.connect(_on_action_pressed)
	ui.infusion_changed.connect(func(v: float) -> void: infusion_ratio = v)
	ui.debug_mode_toggled.connect(_on_debug_mode_toggled)
	ui.exit_requested.connect(_on_exit_requested)
	if not ui.is_node_ready():
		await ui.ready
	start_battle(enemy_base)

func start_battle(enemy: FighterStats) -> void:
	enemy_base = enemy
	state.setup(player_base, enemy_base)
	_apply_form_scaling(state.player, true)
	_apply_form_scaling(state.enemy, true)
	pending_result = ""
	ui.clear_log()
	ui.set_battle_active(true)
	ui.set_exit_message("Exit battle")
	_refresh_view()

func _initialize_skill_pools() -> void:
	attacks.clear()
	for attack in attack_pool:
		if attack and attack.id != &"":
			attacks[attack.id] = attack

	transformations.clear()
	for trans in transformation_pool:
		if trans and trans.id != &"":
			transformations[trans.id] = trans

func get_player_stat_lines() -> PackedStringArray:
	return _fighter_stat_lines(state.player)

func _on_action_pressed(action_id: StringName) -> void:
	if state.is_finished():
		return

	var action_consumed := _match_player_action(action_id)
	if not action_consumed:
		_refresh_view()
		return
	state.player.guarding = false
	if _check_end():
		return

	_resolve_enemy_turn()
	_apply_end_round()
	_check_end()
	_refresh_view()

func _match_player_action(action_id: StringName) -> bool:
	return _process_action(state.player, state.enemy, action_id, infusion_ratio)

func _resolve_enemy_turn() -> void:
	state.enemy.guarding = false
	var action := enemy_ai.choose_action(state.enemy, attacks, transformations, 0.25)
	_process_action(state.enemy, state.player, action, 0.25)

func _process_action(actor: FighterStats, target: FighterStats, action_id: StringName, action_infusion: float) -> bool:
	match action_id:
		&"power_up":
			_power_up(actor)
			return true
		&"guard":
			if not actor.has_utility_skill(&"guard"):
				_log("%s cannot guard." % actor.fighter_name)
				return true
			actor.guarding = true
			actor.stamina += 8
			_log("%s guards and steadies stance." % actor.fighter_name)
			return true
		&"kaioken":
			return _toggle_kaioken(actor)
		&"transform_form":
			_transform_higher_form(actor)
			return true
		_:
			if not attacks.has(action_id) or not actor.has_attack_skill(action_id):
				_log("%s cannot use %s." % [actor.fighter_name, String(action_id)])
				return true
			var selected_attack: AttackDef = attacks[action_id]
			if not _can_use_attack_with_active_buffs(actor, selected_attack):
				_log("%s cannot use %s without required transformation." % [actor.fighter_name, selected_attack.label])
				return true
			var active_boost := _get_kaioken_transformation(actor)
			var attack_result := resolver.resolve_attack(actor, target, selected_attack, action_infusion, active_boost, rng)
			_log_attack_result(actor.fighter_name, selected_attack, attack_result)
			return attack_result.get("ok", false)

func _apply_end_round() -> void:
	state.turn += 1
	state.player.escalation += 3
	state.enemy.escalation += 3
	_apply_form_upkeep(state.player)
	_apply_form_upkeep(state.enemy)
	_apply_kaioken_upkeep(state.player)
	_apply_kaioken_upkeep(state.enemy)
	state.player.stamina = clampi(state.player.stamina + 10, 0, state.player.max_stamina)
	state.enemy.stamina = clampi(state.enemy.stamina + 10, 0, state.enemy.max_stamina)
	state.player.clamp_resources()
	state.enemy.clamp_resources()

func _power_up(fighter: FighterStats) -> void:
	if not fighter.has_utility_skill(&"power_up"):
		_log("%s cannot power up." % fighter.fighter_name)
		return
	var amount := mini(45, mini(fighter.stored_ki, fighter.max_drawn_ki - fighter.drawn_ki))
	if amount <= 0:
		_log("%s cannot draw more ki." % fighter.fighter_name)
		return
	fighter.stored_ki -= amount
	fighter.drawn_ki += amount
	fighter.escalation += 5
	_log("%s powers up (+%d drawn ki)." % [fighter.fighter_name, amount])

func _transform_higher_form(fighter: FighterStats) -> void:
	if not fighter.has_utility_skill(&"transform_form"):
		_log("%s cannot transform." % fighter.fighter_name)
		return

	var transform := _get_next_form_transformation(fighter)
	if transform == null:
		_log("%s has no available transformations." % fighter.fighter_name)
		return
	if not transform.can_activate(fighter):
		_log("%s lacks activation requirements for %s." % [fighter.fighter_name, transform.label])
		return

	var previous_stamina := fighter.stamina
	var previous_max_stamina := fighter.max_stamina
	_deactivate_incompatible_transformations(fighter, transform)
	fighter.form_level = transform.form_level
	fighter.active_form_transformation_id = transform.id
	_apply_form_scaling(fighter, false)
	var stamina_multiplier := float(fighter.max_stamina) / maxf(1.0, float(previous_max_stamina))
	fighter.stamina = clampi(int(round(float(previous_stamina) * stamina_multiplier)), 0, fighter.max_stamina)
	fighter.highest_form_rewarded_this_rest = maxi(fighter.highest_form_rewarded_this_rest, fighter.form_level)
	_log("%s uses %s. Stamina %d/%d -> %d/%d." % [
		fighter.fighter_name,
		transform.label,
		previous_stamina,
		previous_max_stamina,
		fighter.stamina,
		fighter.max_stamina,
	])

func _deactivate_incompatible_transformations(fighter: FighterStats, transform: TransformationDef) -> void:
	if transform == null:
		return
	if transform.incompatible_transformation_ids.has(&"kaioken") and fighter.kaioken_active:
		fighter.kaioken_active = false
		_log("%s's Kaioken is cancelled by %s." % [fighter.fighter_name, transform.label])

func _toggle_kaioken(fighter: FighterStats) -> bool:
	if not fighter.has_utility_skill(&"kaioken") or not fighter.has_transformation_skill(&"kaioken"):
		_log("%s cannot use Kaioken." % fighter.fighter_name)
		return true
	if fighter.kaioken_active:
		fighter.kaioken_active = false
		_apply_form_scaling(fighter, false)
		_log("%s deactivates Kaioken." % fighter.fighter_name)
		return true
	if fighter.form_level > 0:
		_log("%s can only use Kaioken in base form." % fighter.fighter_name)
		return false
	var kaioken: TransformationDef = transformations.get(&"kaioken", null)
	if kaioken == null:
		_log("Kaioken transformation is not configured.")
		return true
	if not kaioken.can_activate(fighter):
		_log("%s lacks activation requirements for Kaioken." % fighter.fighter_name)
		return true
	fighter.kaioken_active = true
	_apply_form_scaling(fighter, false)
	fighter.escalation += 12
	_log("%s activates Kaioken!" % fighter.fighter_name)
	return true

func _apply_kaioken_upkeep(fighter: FighterStats) -> void:
	if not fighter.kaioken_active:
		return
	var kaioken := _get_kaioken_transformation(fighter)
	if kaioken == null:
		return
	var hp_upkeep := int(round(float(fighter.max_hp) * kaioken.hp_upkeep_pct))
	var stamina_upkeep := int(round(float(fighter.max_stamina) * kaioken.stamina_upkeep_pct))
	var drawn_ki_upkeep := int(round(float(fighter.max_drawn_ki) * kaioken.drawn_ki_upkeep_pct))
	fighter.hp -= hp_upkeep
	fighter.stamina -= stamina_upkeep
	fighter.drawn_ki -= drawn_ki_upkeep
	if hp_upkeep > 0 or stamina_upkeep > 0 or drawn_ki_upkeep > 0:
		_log("%s Kaioken upkeep: -%d HP, -%d stamina, -%d drawn ki." % [fighter.fighter_name, hp_upkeep, stamina_upkeep, drawn_ki_upkeep])

func _apply_form_upkeep(fighter: FighterStats) -> void:
	var active_form := _get_active_form_transformation(fighter)
	if active_form == null:
		return
	if active_form.stored_ki_upkeep_pct <= 0.0 and active_form.stored_to_drawn_pct <= 0.0:
		return

	var upkeep_amount := active_form.get_upkeep_amount(fighter.max_stored_ki, active_form.stored_ki_upkeep_pct, fighter.form_mastery_level)
	var conversion_amount := active_form.get_upkeep_amount(fighter.max_stored_ki, active_form.stored_to_drawn_pct, fighter.form_mastery_level)
	upkeep_amount = mini(upkeep_amount, fighter.stored_ki)
	fighter.stored_ki -= upkeep_amount

	var convert_spend := mini(conversion_amount, fighter.stored_ki)
	fighter.stored_ki -= convert_spend
	var draw_gain := mini(convert_spend, fighter.max_drawn_ki - fighter.drawn_ki)
	fighter.drawn_ki += draw_gain

	if upkeep_amount > 0 or convert_spend > 0 or draw_gain > 0:
		_log("%s form upkeep drains %d stored ki and converts %d to drawn ki." % [fighter.fighter_name, upkeep_amount + convert_spend, draw_gain])

func _apply_form_scaling(fighter: FighterStats, preserve_stamina_ratio: bool) -> void:
	var stamina_ratio := float(fighter.stamina) / maxf(1.0, float(fighter.max_stamina))
	var active_form := _get_active_form_transformation(fighter)
	var kaioken := _get_kaioken_transformation(fighter)
	var physical_mult := 1.0
	var ki_mult := 1.0
	var speed_mult := 1.0
	var stamina_mult := 1.0
	if active_form:
		physical_mult = active_form.strength_multiplier
		ki_mult = active_form.strength_multiplier
		speed_mult = active_form.speed_multiplier
		stamina_mult = active_form.max_stamina_multiplier
	if kaioken:
		physical_mult *= kaioken.strength_multiplier
		ki_mult *= kaioken.strength_multiplier
		speed_mult *= kaioken.speed_multiplier
		stamina_mult *= kaioken.max_stamina_multiplier

	fighter.physical_strength = int(round(float(fighter.base_physical_strength) * physical_mult))
	fighter.ki_strength = int(round(float(fighter.base_ki_strength) * ki_mult))
	fighter.speed = int(round(float(fighter.base_speed) * speed_mult))
	fighter.max_stamina = int(round(float(fighter.base_max_stamina) * stamina_mult))
	if preserve_stamina_ratio:
		fighter.stamina = int(round(float(fighter.max_stamina) * clampf(stamina_ratio, 0.0, 1.0)))
	fighter.clamp_resources()

func _get_next_form_transformation(fighter: FighterStats) -> TransformationDef:
	var candidate: TransformationDef = null
	for id in fighter.transformation_skill_ids:
		var transform: TransformationDef = transformations.get(id, null)
		if transform == null or not transform.is_form_transformation:
			continue
		if transform.required_form_level != fighter.form_level:
			continue
		if transform.form_level <= fighter.form_level:
			continue
		if candidate == null or transform.form_level < candidate.form_level:
			candidate = transform
	return candidate

func _get_active_form_transformation(fighter: FighterStats) -> TransformationDef:
	if fighter.active_form_transformation_id == &"":
		return null
	return transformations.get(fighter.active_form_transformation_id, null)

func _get_kaioken_transformation(fighter: FighterStats) -> TransformationDef:
	if not fighter.kaioken_active:
		return null
	return transformations.get(&"kaioken", null)

func _can_use_attack_with_active_buffs(fighter: FighterStats, attack: AttackDef) -> bool:
	if attack.required_transformation_id == &"":
		return true
	if attack.required_transformation_id == &"kaioken":
		return fighter.kaioken_active
	return fighter.active_form_transformation_id == attack.required_transformation_id

func _log_attack_result(attacker_name: String, attack: AttackDef, result: Dictionary) -> void:
	if not result.get("ok", false):
		_log("%s failed %s (no resources)." % [attacker_name, attack.label])
		return
	match result.get("result", ""):
		"miss":
			_log("%s used %s but missed." % [attacker_name, attack.label])
		"vanished":
			_log("%s used %s but target vanished." % [attacker_name, attack.label])
		"hit":
			var damage := int(result.get("damage", 0))
			_log("%s used %s for %d dmg." % [attacker_name, attack.label, damage])
			var extra_strikes := int(result.get("extra_strikes", 0))
			if extra_strikes > 0:
				var strike_text := "strike" if extra_strikes == 1 else "two strikes"
				var extra_damage := int(result.get("extra_damage", 0))
				_log("%s is faster and gains an extra %s for %d damage" % [attacker_name, strike_text, extra_damage])

func _check_end() -> bool:
	if not state.is_finished():
		return false
	var result := state.winner()
	pending_result = result
	if result == "player":
		_log("%s defeated" % state.enemy.fighter_name)
		ui.set_exit_message("%s defeated - Exit battle" % state.enemy.fighter_name)
	elif result == "enemy":
		_log("%s defeated" % state.player.fighter_name)
		ui.set_exit_message("%s defeated - Exit battle" % state.player.fighter_name)
	else:
		_log("Battle result: %s" % result)
		ui.set_exit_message("Draw - Exit battle")
	ui.set_battle_active(false)
	_refresh_view()
	return true

func _on_exit_requested() -> void:
	if pending_result == "":
		return
	battle_finished.emit(pending_result)

func _log(line: String) -> void:
	ui.append_log(line)

func _refresh_view() -> void:
	$"../BattleUI/Margin/VBox/Status".text = "Turn %d | Escalation P:%d E:%d" % [state.turn, int(state.player.escalation), int(state.enemy.escalation)]
	$"../BattleUI/Margin/VBox/PlayerStats".text = _fighter_line(state.player)
	$"../BattleUI/Margin/VBox/EnemyStats".text = _fighter_line(state.enemy)
	_refresh_debug_overlay()

func _fighter_line(f: FighterStats) -> String:
	return "%s HP %d/%d | Stam %d/%d | StoredKi %d/%d | DrawnKi %d/%d | Form %d%s" % [
		f.fighter_name, f.hp, f.max_hp, f.stamina, f.max_stamina, f.stored_ki, f.max_stored_ki, f.drawn_ki, f.max_drawn_ki, f.form_level,
		" +Kaioken" if f.kaioken_active else ""
	]

func _fighter_stat_lines(f: FighterStats) -> PackedStringArray:
	return PackedStringArray([
		"Name: %s" % f.fighter_name,
		"HP: %d / %d" % [f.hp, f.max_hp],
		"Stamina: %d / %d" % [f.stamina, f.max_stamina],
		"Stored Ki: %d / %d" % [f.stored_ki, f.max_stored_ki],
		"Drawn Ki: %d / %d" % [f.drawn_ki, f.max_drawn_ki],
		"Physical Strength: %d" % f.physical_strength,
		"Ki Strength: %d" % f.ki_strength,
		"Speed: %d" % f.speed,
		"Escalation: %d" % int(f.escalation),
		"Form Level: %d" % f.form_level,
		"Active Form Transform: %s" % String(f.active_form_transformation_id),
		"Base Form Override: %d" % f.base_form_override_level,
		"Form Mastery: %d" % f.form_mastery_level,
		"Kaioken Active: %s" % ("Yes" if f.kaioken_active else "No"),
	])


func _on_debug_mode_toggled(enabled: bool) -> void:
	if enabled:
		_refresh_debug_overlay()

func _refresh_debug_overlay() -> void:
	if not ui.debug_mode_enabled:
		return
	var lines := PackedStringArray()
	lines.append("[b]Player Stats[/b]")
	for line in _fighter_debug_lines(state.player):
		lines.append(line)
	lines.append("")
	lines.append("[b]Enemy Stats[/b]")
	for line in _fighter_debug_lines(state.enemy):
		lines.append(line)
	ui.set_debug_stats(lines)

func _fighter_debug_lines(f: FighterStats) -> PackedStringArray:
	return PackedStringArray([
		"Name: %s" % f.fighter_name,
		"HP: %d / %d" % [f.hp, f.max_hp],
		"Stamina: %d / %d" % [f.stamina, f.max_stamina],
		"Stored Ki: %d / %d" % [f.stored_ki, f.max_stored_ki],
		"Drawn Ki: %d / %d" % [f.drawn_ki, f.max_drawn_ki],
		"Physical: %d (base %d)" % [f.physical_strength, f.base_physical_strength],
		"Ki: %d (base %d)" % [f.ki_strength, f.base_ki_strength],
		"Speed: %d (base %d)" % [f.speed, f.base_speed],
		"Form: %d | Active: %s | Kaioken: %s" % [f.form_level, String(f.active_form_transformation_id), "On" if f.kaioken_active else "Off"],
		"Attack Skills: %s" % _join_skill_ids(f.attack_skill_ids),
		"Utility Skills: %s" % _join_skill_ids(f.utility_skill_ids),
		"Transformation Skills: %s" % _join_skill_ids(f.transformation_skill_ids),
	])


func _join_skill_ids(ids: PackedStringArray) -> String:
	var out: PackedStringArray = PackedStringArray()
	for id in ids:
		out.append(String(id))
	return ", ".join(out)
