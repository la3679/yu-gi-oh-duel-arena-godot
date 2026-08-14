class_name BattleRules
extends RefCounted

## Battle Phase, attack declaration, attack replay and the Damage Step.
## RULES_SPEC.md 6 and 7, master prompt 32/33/34.
##
## The Damage Step is a five sub-step sequence, not a single comparison [S3]:
##
##   1 START_OF_DAMAGE_STEP     effects that activate "at the start of the Damage Step"
##   2 BEFORE_DAMAGE_CALCULATION an attacked face-down monster is flipped face-up;
##                              ATK/DEF-changing effects may still activate; Flip
##                              effects do NOT activate yet
##   3 DURING_DAMAGE_CALCULATION ATK/DEF comparison and battle damage; destruction is
##                              DETERMINED here but nothing is sent to the GY yet
##   4 AFTER_DAMAGE_CALCULATION  battle triggers, and the Flip effects of monsters
##                              flipped face-up in sub-step 2
##   5 END_OF_DAMAGE_STEP        monsters destroyed by battle are SENT to the GY, and
##                              "destroyed by battle and sent to the GY" triggers fire
##
## Which effects may be activated inside the Damage Step is enforced by
## ActivationRules.damage_step_ok(), from the rule printed at [S1 p.41].
##
## DuelEngine owns the pacing: it opens a real response window between sub-steps, so a
## timing window is never skipped.

enum Stage {
	NONE,
	## The attack has been declared; the response window before the Damage Step is open.
	AFTER_DECLARATION,
	DS_START,
	DS_BEFORE,
	DS_DURING,
	DS_AFTER,
	DS_END,
}

var state: GameState = null

var stage: Stage = Stage.NONE

## Monsters whose destruction was determined during damage calculation. They stay on the
## field until the end of the Damage Step [S3].
var pending_destroyed: Array = []
## Monsters flipped face-up in sub-step 2, whose Flip effects belong to sub-step 4.
var flipped_before_damage: Array = []
## The opponent's monsters when the attack was declared, for replay detection [S1 p.39].
var opponent_monsters_at_declaration: Array = []
## After a replay this monster may declare an attack again without it counting twice.
var replay_attacker_id: int = -1

## Set when a resolved effect NEGATED the declared attack (`Maiden with Eyes of Blue`).
## RULES_SPEC.md 6.3.
##
## Attack NEGATION is not attack PREVENTION and the two are deliberately different mechanisms
## living in different places:
##
##   * PREVENTION is asked by `can_declare_attack()` BEFORE anything happens. The attack is
##     never declared, no `ATTACK_DECLARED` event exists, and the monster has not used its
##     attack for the turn.
##   * NEGATION happens AFTER a legal declaration. `ATTACK_DECLARED` really was emitted, the
##     response window really opened, the attacking monster really has attacked this turn,
##     and what stops is the rest of the battle: no Damage Step, no damage calculation.
##
## It is also not a REPLAY. A Replay hands the choice back — the attacker may attack again
## with itself or another monster. A negated attack is spent. `begin_replay()` clears
## `has_attacked_this_turn`; this path deliberately does not.
var attack_negated: bool = false
## Instance id of the card whose effect negated the attack, for the event payload.
var attack_negated_by_id: int = -1

var last_damage: Dictionary = {}


func _init(p_state: GameState) -> void:
	state = p_state


# ---------------------------------------------------------------------------
# Attack legality. RULES_SPEC.md 6.1 [S1 p.38]
# ---------------------------------------------------------------------------

func can_declare_attack(card: CardInstance, pid: int) -> bool:
	if state.is_duel_over():
		return false
	if card == null or not card.is_monster():
		return false
	if state.phase != Enums.Phase.BATTLE or state.battle_step != Enums.BattleStep.BATTLE:
		return false
	if state.turn_player_id != pid or card.controller_id != pid:
		return false
	if card.zone != Enums.Zone.MONSTER_ZONE:
		return false
	# Only a face-up Attack Position monster may attack.
	if card.position != Enums.Position.FACE_UP_ATTACK:
		return false
	# One attack per turn by default. A monster that got a Replay may re-declare.
	if card.has_attacked_this_turn and card.id != replay_attacker_id:
		return false
	# Two separate PREVENTION channels, asked here and only here, so that an attack which
	# may not be declared is never declared and then unwound. RULES_SPEC.md 6.1.
	#
	#   per-CARD:   "that monster cannot attack" (`Fiendish Chain`, `Hieratic Dragon of
	#               Tefnuit`) — travels with the monster.
	#   per-PLAYER: "your opponent's monsters cannot declare an attack" (`Swords of
	#               Revealing Light`) — covers monsters that arrive later.
	#
	# Neither is expressed in terms of the other; see ContinuousEffects.ATTACK_LOCK_KEY.
	if bool(card.flags.get("cannot_attack", false)):
		return false
	if ContinuousEffects.attacks_restricted(state, pid):
		return false
	return true


## Legal attack targets: the opponent's monsters, face-up or face-down.
func attack_targets(pid: int) -> Array:
	return state.opponent_of(pid).monsters()


## "If there are no monsters on your opponent's side of the field, you can attack
## directly." [S1 p.38, p.43]
func can_attack_directly(pid: int) -> bool:
	return attack_targets(pid).is_empty()


# ---------------------------------------------------------------------------
# Declaration
# ---------------------------------------------------------------------------

## `target` is null for a direct attack. Returns false when the declaration is illegal.
func declare_attack(attacker: CardInstance, target, pid: int) -> bool:
	if not can_declare_attack(attacker, pid):
		return false
	var direct := target == null
	if direct:
		if not can_attack_directly(pid):
			return false
	elif not attack_targets(pid).has(target):
		return false

	# Declaring with a different monster after a Replay spends the original monster's
	# attack: "the original monster is still treated as having declared an attack and
	# cannot attack again this turn." [S1 p.39]
	if replay_attacker_id != -1 and attacker.id != replay_attacker_id:
		var previous = state.instance(replay_attacker_id)
		if previous != null:
			previous.has_attacked_this_turn = true
	replay_attacker_id = -1

	state.current_attacker = attacker
	state.current_attack_target = target
	state.attack_is_direct = direct
	attacker.has_attacked_this_turn = true
	attacker.attacks_declared_this_turn += 1

	opponent_monsters_at_declaration = attack_targets(pid).map(func(c): return c.id)
	stage = Stage.AFTER_DECLARATION
	pending_destroyed = []
	flipped_before_damage = []
	last_damage = {}
	attack_negated = false
	attack_negated_by_id = -1

	state.emit(GameEvent.Kind.ATTACK_DECLARED, {
		"attacker_id": attacker.id, "attacker_name": attacker.card_name(),
		"player": pid, "direct": direct,
		"target_id": -1 if direct else target.id,
	})
	if not direct:
		state.emit(GameEvent.Kind.ATTACK_TARGET_SELECTED, {
			"attacker_id": attacker.id, "target_id": target.id, "player": pid,
		})
	return true


## A Replay occurs when, after an attack is declared but before the Damage Step, the set
## of monsters the opponent controls changes. [S1 p.39]
func replay_required() -> bool:
	if state.current_attacker == null:
		return false
	var now := attack_targets(state.turn_player_id).map(func(c): return c.id)
	if now.size() != opponent_monsters_at_declaration.size():
		return true
	for cid in now:
		if not opponent_monsters_at_declaration.has(cid):
			return true
	return false


## Cancel the attack and hand the choice back to the attacking player. The attacker is
## NOT yet considered to have used its attack — it may re-declare, attack with a
## different monster, or not attack at all.
func begin_replay() -> void:
	var attacker = state.current_attacker
	if attacker != null:
		attacker.has_attacked_this_turn = false
		replay_attacker_id = attacker.id
	state.emit(GameEvent.Kind.ATTACK_REPLAY, {
		"attacker_id": attacker.id if attacker != null else -1,
		"player": state.turn_player_id,
	})
	clear_battle()


## Negate the attack that has been declared. RULES_SPEC.md 6.3.
##
## Only legal while an attack is live and the Damage Step has not begun: "negate the attack"
## belongs to the Battle Step response window opened by the declaration, and once damage
## calculation has started there is no attack left to negate — the effects legal from that
## point change ATK/DEF instead [S1 p.41]. Returns false rather than half-applying, so a card
## that asks at the wrong moment fails visibly instead of corrupting the battle.
##
## The `ATTACK_NEGATED` event is emitted HERE, at the moment the negation applies, rather
## than later when `DuelEngine` unwinds the battle. That keeps the event ordering honest —
## `ATTACK_DECLARED` … the negating Chain Link resolving … `ATTACK_NEGATED` — and lets
## anything that wants to trigger off the negation see it in the same batch.
func negate_attack(negated_by_id: int = -1) -> bool:
	if state.current_attacker == null:
		return false
	if stage != Stage.AFTER_DECLARATION:
		return false
	if attack_negated:
		return false
	attack_negated = true
	attack_negated_by_id = negated_by_id
	state.emit(GameEvent.Kind.ATTACK_NEGATED, {
		"attacker_id": state.current_attacker.id,
		"player": state.current_attacker.controller_id,
		"target_id": -1 if state.attack_is_direct \
			else (state.current_attack_target.id if state.current_attack_target != null else -1),
		"direct": state.attack_is_direct,
		"negated_by": negated_by_id,
	})
	return true


func attack_is_negated() -> bool:
	return attack_negated


## The ATTACKER left the field or stopped being face-up before damage calculation: the
## attack simply does not happen.
##
## This is deliberately about the attacker only. If the TARGET leaves the field the
## attack is not cancelled — the set of monsters the opponent controls changed, which is
## a Replay [S1 p.39], and the attacking player gets to choose again. Checking the target
## here would silently swallow that Replay, which is exactly the defect BattleTests
## "removing the attack target causes a Replay" caught.
func attacker_still_valid() -> bool:
	var a = state.current_attacker
	return a != null and a.zone == Enums.Zone.MONSTER_ZONE and a.is_face_up()


## The declared target is still a monster on the field. A false result always coincides
## with `replay_required()`, since the opponent's monsters must have changed for the
## target to have gone.
func target_still_valid() -> bool:
	if state.attack_is_direct:
		return true
	var d = state.current_attack_target
	return d != null and d.zone == Enums.Zone.MONSTER_ZONE


func clear_battle() -> void:
	state.current_attacker = null
	state.current_attack_target = null
	state.attack_is_direct = false
	attack_negated = false
	attack_negated_by_id = -1
	state.battle_step = Enums.BattleStep.BATTLE
	state.damage_substep = Enums.DamageSubStep.NONE
	stage = Stage.NONE
	pending_destroyed = []
	flipped_before_damage = []


# ---------------------------------------------------------------------------
# Damage Step sub-steps. RULES_SPEC.md 7.1 [S3]
# ---------------------------------------------------------------------------

func _enter_substep(sub: Enums.DamageSubStep) -> void:
	state.damage_substep = sub
	state.emit(GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED, {
		"substep": sub,
		"attacker_id": state.current_attacker.id if state.current_attacker != null else -1,
	})


func begin_damage_step() -> void:
	state.battle_step = Enums.BattleStep.DAMAGE
	state.emit(GameEvent.Kind.BATTLE_STEP_CHANGED, {"step": Enums.BattleStep.DAMAGE})
	stage = Stage.DS_START
	_enter_substep(Enums.DamageSubStep.START_OF_DAMAGE_STEP)


## Sub-step 2: an attacked face-down monster is flipped face-up. Its Flip effect does
## NOT activate here — that is sub-step 4. [S1 p.41]
func step_before_damage_calculation() -> void:
	stage = Stage.DS_BEFORE
	_enter_substep(Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION)
	var target = state.current_attack_target
	if target != null and target.is_face_down():
		state.set_battle_position(target, Enums.Position.FACE_UP_DEFENSE, true)
		flipped_before_damage.append(target)


## Sub-step 3: compare, inflict battle damage, and DETERMINE destruction.
## Nothing is sent to the Graveyard until sub-step 5.
func step_damage_calculation() -> void:
	stage = Stage.DS_DURING
	_enter_substep(Enums.DamageSubStep.DURING_DAMAGE_CALCULATION)

	var attacker: CardInstance = state.current_attacker
	var defender = state.current_attack_target
	var attacker_pid := attacker.controller_id
	var defender_pid := state.opponent_id(attacker_pid)
	var atk := attacker.current_atk()

	var result := {
		"attacker_id": attacker.id, "attacker_atk": atk,
		"direct": state.attack_is_direct,
		"damage_to": -1, "damage": 0,
		"destroyed": [],
	}

	if state.attack_is_direct:
		# "The full amount of your attacking monster's ATK is subtracted from the
		# opponent's LP as battle damage." [S1 p.43]
		result["damage_to"] = defender_pid
		result["damage"] = atk
	elif defender.is_in_defense_position():
		var def_value: int = defender.current_def()
		result["defender_id"] = defender.id
		result["defender_def"] = def_value
		if atk > def_value:
			if atk > 0 and _can_be_destroyed_by_battle(defender):
				result["destroyed"].append(defender.id)
			# Piercing damage only when a card grants it. [S1 p.42]
			if bool(attacker.flags.get("piercing", false)):
				result["damage_to"] = defender_pid
				result["damage"] = atk - def_value
		elif atk < def_value:
			result["damage_to"] = attacker_pid
			result["damage"] = def_value - atk
		# atk == def_value: neither destroyed, no damage.
	else:
		var def_atk: int = defender.current_atk()
		result["defender_id"] = defender.id
		result["defender_atk"] = def_atk
		if atk > def_atk:
			if _can_be_destroyed_by_battle(defender):
				result["destroyed"].append(defender.id)
			result["damage_to"] = defender_pid
			result["damage"] = atk - def_atk
		elif atk < def_atk:
			if _can_be_destroyed_by_battle(attacker):
				result["destroyed"].append(attacker.id)
			result["damage_to"] = attacker_pid
			result["damage"] = def_atk - atk
		else:
			# A tie destroys both — but a 0 ATK monster cannot destroy anything by
			# battle, so two 0 ATK monsters destroy neither. [S1 p.51]
			if atk > 0:
				if _can_be_destroyed_by_battle(defender):
					result["destroyed"].append(defender.id)
				if _can_be_destroyed_by_battle(attacker):
					result["destroyed"].append(attacker.id)

	attacker.battled_this_turn = true
	if defender != null:
		defender.battled_this_turn = true

	for cid in result["destroyed"]:
		var c = state.instance(cid)
		if c != null:
			pending_destroyed.append(c)

	state.emit(GameEvent.Kind.DAMAGE_CALCULATED, result)

	if int(result["damage"]) > 0 and int(result["damage_to"]) != -1:
		state.change_life_points(int(result["damage_to"]), -int(result["damage"]),
			"battle damage", attacker.id)
		state.emit(GameEvent.Kind.BATTLE_DAMAGE_INFLICTED, {
			"player": int(result["damage_to"]), "amount": int(result["damage"]),
			"attacker_id": attacker.id, "direct": state.attack_is_direct,
		})
	last_damage = result


## Whether damage calculation may DETERMINE that this monster is destroyed.
##
## Prevention is asked here rather than in sub-step 5 because a monster that cannot be
## destroyed by battle was never determined to be destroyed at all — nothing about it
## should appear in the DAMAGE_CALCULATED payload. A COUNTED prevention
## (`Gagagashield`: "Twice per turn, it cannot be destroyed by battle or card effects")
## spends one of its uses here for the same reason. RULES_SPEC.md 17.
func _can_be_destroyed_by_battle(card: CardInstance) -> bool:
	if card == null:
		return false
	return not state.destruction_prevented(card, Enums.MoveReason.DESTROYED_BY_BATTLE)


## Sub-step 4: battle triggers, and the Flip effects of monsters flipped in sub-step 2.
## The engine runs a trigger check over the events of sub-steps 2 and 3 here, which is
## exactly why the flip event was withheld until now. [S1 p.41]
func step_after_damage_calculation() -> void:
	stage = Stage.DS_AFTER
	_enter_substep(Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION)


## Sub-step 5: monsters destroyed by battle are sent to the Graveyard now.
func step_end_of_damage_step() -> void:
	stage = Stage.DS_END
	_enter_substep(Enums.DamageSubStep.END_OF_DAMAGE_STEP)
	for card in pending_destroyed:
		if card != null and card.zone == Enums.Zone.MONSTER_ZONE:
			# `carry_out_destruction`, not `destroy`: prevention was already asked (and a
			# counted use already spent) at damage calculation. What is still outstanding
			# is the REPLACEMENT check — "destroy this card instead" applies at the moment
			# the destruction is actually carried out. RULES_SPEC.md 17.
			state.carry_out_destruction(card, Enums.MoveReason.DESTROYED_BY_BATTLE,
				state.current_attacker.id if state.current_attacker != null else -1)
	pending_destroyed = []
	# "Until the end of the Damage Step" modifiers expire here.
	for card in state.all_instances():
		card.remove_modifiers_with_duration("end_of_damage_step")


## Leave the Damage Step and return to the Battle Step.
func finish_damage_step() -> void:
	clear_battle()
	state.emit(GameEvent.Kind.BATTLE_STEP_CHANGED, {"step": Enums.BattleStep.BATTLE})


## Called when the Battle Phase ends, so a Replay allowance does not leak into later
## turns.
func end_battle_phase() -> void:
	if replay_attacker_id != -1:
		var previous = state.instance(replay_attacker_id)
		if previous != null:
			previous.has_attacked_this_turn = true
		replay_attacker_id = -1
	clear_battle()
	state.battle_step = Enums.BattleStep.END
	state.emit(GameEvent.Kind.BATTLE_STEP_CHANGED, {"step": Enums.BattleStep.END})
