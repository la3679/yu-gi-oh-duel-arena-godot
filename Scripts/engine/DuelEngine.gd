class_name DuelEngine
extends RefCounted

## The authoritative duel API and the Fast Effect Timing state machine.
## RULES_SPEC.md 3 (transcribed from the official Fast Effect Timing chart, S2).
## Master prompt 7B, 11, 68, 87.
##
## Everything a player can do goes through get_legal_actions() / get_legal_responses()
## and submit_action(). The UI renders what the engine says is legal and the engine
## re-validates on submit, so no input path can bypass the rules.
##
## The machine's boxes map one-to-one onto RULES_SPEC.md 3:
##
##   OPEN         box A   open game state; the turn player acts
##   TRIGGER_CHECK        the A1 "does this activate a triggered effect?" node, which is
##                        also the "After a Chain Resolves" node
##   FAST_TURN    box B   turn player may activate a fast effect
##   FAST_OPP     box C   opponent may activate a fast effect
##   CHAIN_BUILD  box D   alternate responses until two consecutive passes, then resolve
##   TP_PASSED    box E   turn player passed; opponent may respond before the phase moves
##
## Two rules the machine enforces structurally rather than by convention:
##   * A new Chain never starts mid-resolution. Events raised while a Chain resolves are
##     collected afterwards and handled at the trigger-check node (master prompt 45).
##   * A Summon does not return to an open game state while a response window is open.
##     The monster waits in Zone.IN_TRANSIT until the window closes, which is what makes
##     `Champion's Vigilance` ("when a monster(s) would be Summoned: Negate the Summon")
##     implementable rather than approximated.

enum Timing {
	SETUP,
	OPEN,
	TRIGGER_CHECK,
	FAST_TURN,
	FAST_OPP,
	CHAIN_BUILD,
	TP_PASSED,
	DUEL_OVER,
}

var state: GameState = null
var chain: ChainManager = null
var triggers: TriggerCollector = null
var summons: SummonRules = null
var battle: BattleRules = null
var continuous: ContinuousEffects = null
var flow: TurnFlow = null
var log: DuelLog = null

## PlayerController per player id.
var controllers: Array = []

var timing: Timing = Timing.SETUP

# --- Chain building state. RULES_SPEC.md 3 box D. ---
## Whose turn it is to respond while building a Chain.
var _responder_id: int = 0
## Two consecutive passes close the Chain [S2 box D].
var _consecutive_passes: int = 0

# --- Window bookkeeping ---
## Events awaiting trigger collection.
var _pending_events: Array = []
## Events that opened the current response window. A Quick Effect that declares specific
## trigger events is only offered while one of them is in here.
var _window_events: Array = []
## Events deliberately withheld from one Damage Step sub-step and handed to a later one.
## A monster attacked while face-down is flipped in sub-step 2, but its Flip effect must
## activate in sub-step 4 [S1 p.41], so the flip event travels in here.
var _carried_events: Array = []

## Events raised by paying an activation COST, held until the Chain that cost belongs to
## has fully resolved.
##
## A cost is paid while the Chain is being BUILT, before the link is even on the Chain, so
## `_resolve_current_chain()`'s mark is taken long after it happened and the trigger check
## that follows the resolution would never see it. That is a real gap and not a theoretical
## one: "If this card is sent to the GY" on a card DISCARDED AS A COST is a standard
## interaction (`The White Stone of Legend` discarded by `Cards of Consonance`), and before
## batch 10 no card in the pool triggered off a cost, so nothing had exercised it.
##
## Held rather than acted on immediately, because a Trigger Effect that meets its condition
## while a Chain is being built does not interrupt it — it activates after that Chain has
## finished resolving. Master prompt 45. This is deliberately the SAME shape as
## `_carried_events` above, which withholds the Damage Step's flip for sub-step 4.
var _cost_events: Array = []
## Index into state.events marking where the current step began.
var _event_mark: int = 0

## A Summon that has been declared and is waiting for its response window to close.
var _pending_summon: Dictionary = {}
## Phase/step transition the turn player asked for, executed once box E closes.
var _pending_transition: Enums.ActionKind = Enums.ActionKind.PASS
var _has_pending_transition: bool = false

## Guards against re-entrant advancing while a submit is already being processed.
var _advancing: bool = false

## Pending events for CONTINUOUS clauses that respond to a discrete event
## (`ContinuousEffects.respond_to()`). A response changes state and so emits events of its
## own; queueing rather than recursing keeps the order of application equal to the order of
## emission, which is what makes a replay reproduce it. RULES_SPEC.md 5.7.
var _event_response_queue: Array = []
var _dispatching_event_responses: bool = false


func _init(seed_value: int = 0) -> void:
	state = GameState.new(seed_value)
	chain = ChainManager.new(state, self)
	log = DuelLog.new()
	state.event_emitted.connect(log.record_event)
	state.event_emitted.connect(_queue_continuous_event_response)


## Every emitted event is offered to the continuous clauses that respond to events.
##
## `continuous` does not exist until `setup_duel()`, and events emitted while the Decks are
## being built have no field to respond from, so a null system simply drops them.
func _queue_continuous_event_response(event: GameEvent) -> void:
	if continuous == null:
		return
	_event_response_queue.append(event)
	if _dispatching_event_responses:
		return
	_dispatching_event_responses = true
	while not _event_response_queue.is_empty():
		var next: GameEvent = _event_response_queue.pop_front()
		continuous.respond_to(next)
	_dispatching_event_responses = false


# ---------------------------------------------------------------------------
# Duel setup. RULES_SPEC.md 1, master prompt 52.
# ---------------------------------------------------------------------------

## `decks` is [Array[CardDef], Array[CardDef]] in Deck order before shuffling.
func setup_duel(decks: Array, p_controllers: Array, first_player: int = 0,
		deck_names: Array = ["", ""]) -> void:
	controllers = p_controllers
	triggers = TriggerCollector.new(state, controllers)
	summons = SummonRules.new(state)
	battle = BattleRules.new(state)
	continuous = ContinuousEffects.new(state)
	flow = TurnFlow.new(state, controllers)
	# Every question either subsystem puts to a player is a duel input; the replay payload
	# is only complete if all of them are recorded. Master prompt 70.
	triggers.log = log
	flow.log = log

	for pid in range(GameState.PLAYER_COUNT):
		var p := state.player(pid)
		p.deck_name = str(deck_names[pid]) if pid < deck_names.size() else ""
		if pid < controllers.size() and controllers[pid] != null:
			p.display_name = controllers[pid].display_name
		for card_def in decks[pid]:
			var inst := CardInstance.new(card_def, pid)
			state.register_instance(inst)
			inst.zone = Enums.Zone.DECK
			inst.position = Enums.Position.FACE_DOWN
			p.deck.append(inst)

	state.first_player_id = first_player
	log.begin(state)

	state.emit(GameEvent.Kind.DUEL_STARTED, {
		"seed": state.rng.get_seed(), "first_player": first_player,
		"deck_names": deck_names.duplicate(),
	})

	for pid in range(GameState.PLAYER_COUNT):
		state.shuffle_deck(pid)
	for pid in range(GameState.PLAYER_COUNT):
		state.draw(pid, 5)  # [S1 p.33]

	flow.begin_first_turn(first_player)
	_pending_events = _events_since(0)
	timing = Timing.TRIGGER_CHECK
	_advance()


# ---------------------------------------------------------------------------
# Public API. Master prompt 68.
# ---------------------------------------------------------------------------

func get_visible_state(viewer_id: int) -> Dictionary:
	return state.get_visible_state(viewer_id)


func get_public_log() -> Array:
	return state.get_public_log()


func is_duel_over() -> bool:
	return state.is_duel_over()


## The player the engine is currently waiting on, or -1 when nobody must act.
func waiting_player() -> int:
	match timing:
		Timing.OPEN:
			return state.turn_player_id
		Timing.FAST_TURN:
			return state.turn_player_id
		Timing.FAST_OPP, Timing.TP_PASSED:
			return state.opponent_id(state.turn_player_id)
		Timing.CHAIN_BUILD:
			return _responder_id
		_:
			return -1


## What the engine is waiting for and why. Master prompt 68's get_pending_decision():
## the engine states the request, the UI renders it, the answer comes back through
## submit_action() and is validated again.
func get_pending_decision() -> Dictionary:
	var pid := waiting_player()
	if pid == -1:
		return {"kind": "NONE", "player": -1, "timing": Timing.keys()[timing]}
	var is_response := timing != Timing.OPEN
	return {
		"kind": "RESPONSE" if is_response else "ACTION",
		"player": pid,
		"timing": Timing.keys()[timing],
		"phase": state.phase,
		"prompt": _prompt_for_timing(pid),
		"chain_size": chain.chain_size(),
		"actions": (get_legal_responses(pid) if is_response else get_legal_actions(pid)),
	}


func _prompt_for_timing(pid: int) -> String:
	match timing:
		Timing.OPEN:
			return "%s — %s" % [state.player(pid).display_name,
				Enums.phase_name(state.phase)]
		Timing.CHAIN_BUILD:
			return "%s — respond to Chain Link %d, or pass" % [
				state.player(pid).display_name, chain.chain_size()]
		Timing.TP_PASSED:
			return "%s — respond before the phase ends, or pass" % \
				state.player(pid).display_name
		_:
			return "%s — activate a fast effect, or pass" % state.player(pid).display_name


# ---------------------------------------------------------------------------
# Legal actions. RULES_SPEC.md 3 box A.
# ---------------------------------------------------------------------------

## Actions the turn player may take in an open game state (box A).
## Returns [] for anyone else, and [] when the engine is inside a response window —
## a response window offers get_legal_responses(), not general actions.
func get_legal_actions(pid: int) -> Array:
	var out: Array = []
	if state.is_duel_over() or timing != Timing.OPEN or pid != state.turn_player_id:
		return out

	out.append_array(_summon_actions(pid))
	out.append_array(_summon_procedure_actions(pid))
	out.append_array(_position_actions(pid))
	out.append_array(_set_spell_trap_actions(pid))
	out.append_array(_attack_actions(pid))
	# Box A2: the turn player may activate a card or effect of ANY Spell Speed.
	out.append_array(_activation_actions(pid, null))
	out.append_array(_phase_actions(pid))

	var surrender := DuelAction.make(Enums.ActionKind.SURRENDER, pid)
	surrender.label = "Surrender"
	out.append(surrender)
	return out


## Fast effects this player may activate right now (boxes B, C, D, E).
## A fast effect is Spell Speed 2 or 3 [S1 p.44-45]; Ignition/Trigger/Flip effects and
## Spell Speed 1 Spells are deliberately absent.
func get_legal_responses(pid: int) -> Array:
	var out: Array = []
	if state.is_duel_over():
		return out
	if not (timing in [Timing.FAST_TURN, Timing.FAST_OPP, Timing.CHAIN_BUILD,
			Timing.TP_PASSED]):
		return out
	if pid != waiting_player():
		return out

	out.append_array(_activation_actions(pid, _window_events, true))

	var pass_action := DuelAction.make(Enums.ActionKind.PASS, pid)
	pass_action.label = "Pass"
	out.append(pass_action)
	return out


func _has_any_response(pid: int) -> bool:
	# Cheaper than building the full list: PASS is always present, so "has a response"
	# means at least one real activation exists.
	return not _activation_actions(pid, _window_events, true).is_empty()


# --- Action builders ---

func _summon_actions(pid: int) -> Array:
	var out: Array = []
	var p := state.player(pid)
	for card in p.hand:
		if not card.is_monster():
			continue
		if not summons.can_normal_summon_or_set(card, pid):
			continue
		var need := summons.tributes_required(card)
		var candidates: Array = []
		if need > 0:
			candidates = summons.tribute_candidates(pid).map(func(c): return c.id)

		var summon := DuelAction.make(
			Enums.ActionKind.TRIBUTE_SUMMON if need > 0 else Enums.ActionKind.NORMAL_SUMMON,
			pid, card.id)
		summon.label = "Normal Summon %s" % card.card_name()
		summon.tributes_required = need
		summon.tribute_candidates = candidates
		summon.tribute_combinations = summons.tribute_combinations(card).map(func(g): return g.map(func(m): return m.id))
		summon.legal_positions = [Enums.Position.FACE_UP_ATTACK]
		summon.position = Enums.Position.FACE_UP_ATTACK
		out.append(summon)

		var set_action := DuelAction.make(
			Enums.ActionKind.TRIBUTE_SET if need > 0 else Enums.ActionKind.NORMAL_SET,
			pid, card.id)
		set_action.label = "Set %s" % card.card_name()
		set_action.tributes_required = need
		set_action.tribute_candidates = candidates
		set_action.tribute_combinations = summon.tribute_combinations
		set_action.legal_positions = [Enums.Position.FACE_DOWN_DEFENSE]
		set_action.position = Enums.Position.FACE_DOWN_DEFENSE
		out.append(set_action)

	for card in p.monsters():
		if summons.can_flip_summon(card, pid):
			var flip := DuelAction.make(Enums.ActionKind.FLIP_SUMMON, pid, card.id)
			flip.label = "Flip Summon %s" % card.card_name()
			out.append(flip)
	return out


## Special Summons the player performs themselves through a summoning PROCEDURE rather
## than by activating an effect — "you can Special Summon this card (from your hand)".
## These start no Chain, so they are box A1 actions, and like a Normal Summon they open a
## declaration window so `Champion's Vigilance` can negate the Summon.
## RULES_SPEC.md 3 box A1, 5.5.
func _summon_procedure_actions(pid: int) -> Array:
	var out: Array = []
	if state.phase != Enums.Phase.MAIN_1 and state.phase != Enums.Phase.MAIN_2:
		return out
	for card in state.all_instances():
		if card.controller_id != pid or card.definition == null:
			continue
		for effect in card.definition.effects:
			if effect.effect_type != Enums.EffectType.SUMMON_PROCEDURE:
				continue
			if not ActivationRules.can_use_summon_procedure(state, card, effect, pid):
				continue
			var a := DuelAction.make(Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, pid,
				card.id, effect.effect_id)
			a.label = "Special Summon %s" % card.card_name()
			a.clause_text = effect.clause_text
			# "The summoning player's choice of face-up Attack or face-up Defense, unless
			# the card specifies." RULES_SPEC.md 5.5.
			a.legal_positions = [Enums.Position.FACE_UP_ATTACK,
				Enums.Position.FACE_UP_DEFENSE]
			a.position = Enums.Position.FACE_UP_ATTACK
			out.append(a)
	return out


func _position_actions(pid: int) -> Array:
	var out: Array = []
	for card in state.player(pid).monsters():
		if summons.can_change_position(card, pid):
			var a := DuelAction.make(Enums.ActionKind.CHANGE_POSITION, pid, card.id)
			a.position = summons.opposite_face_up_position(card)
			a.label = "Change %s to %s" % [card.card_name(),
				"Defense Position" if a.position == Enums.Position.FACE_UP_DEFENSE
				else "Attack Position"]
			out.append(a)
	return out


## Setting a Spell/Trap is a box A1 action; it is not an activation and starts no Chain.
func _set_spell_trap_actions(pid: int) -> Array:
	var out: Array = []
	var p := state.player(pid)
	if state.phase != Enums.Phase.MAIN_1 and state.phase != Enums.Phase.MAIN_2:
		return out
	if not p.has_free_spell_trap_zone():
		return out
	for card in p.hand:
		if not (card.is_spell() or card.is_trap()):
			continue
		if card.definition != null and card.definition.st_kind == Enums.STKind.FIELD_SPELL \
				and p.field_zone != null:
			continue
		var a := DuelAction.make(Enums.ActionKind.SET_SPELL_TRAP, pid, card.id)
		a.label = "Set a Spell/Trap"
		out.append(a)
	return out


## Attack declarations, offered only during the Battle Step. RULES_SPEC.md 6.1.
func _attack_actions(pid: int) -> Array:
	var out: Array = []
	if state.phase != Enums.Phase.BATTLE \
			or state.battle_step != Enums.BattleStep.BATTLE:
		return out
	var targets := battle.attack_targets(pid).map(func(c): return c.id)
	var direct := battle.can_attack_directly(pid)
	for card in state.player(pid).monsters():
		if not battle.can_declare_attack(card, pid):
			continue
		var a := DuelAction.make(Enums.ActionKind.DECLARE_ATTACK, pid, card.id)
		a.label = "Attack with %s" % card.card_name()
		a.attack_target_candidates = targets.duplicate()
		a.allows_direct_attack = direct
		a.attack_target_id = -1
		out.append(a)
	return out


## Every card/effect this player may legally activate right now.
## `fast_only` restricts the result to Spell Speed 2+ (a response window).
func _activation_actions(pid: int, window_events, fast_only: bool = false) -> Array:
	var out: Array = []
	for card in state.all_instances():
		if card.owner_id != pid and card.controller_id != pid:
			continue
		if card.controller_id != pid:
			continue
		if card.definition == null:
			continue
		for effect in card.definition.effects:
			if fast_only and not ActivationRules.is_fast_effect(effect):
				continue
			if not effect.starts_chain:
				continue
			# A Trigger/Flip Effect is put on the Chain by the trigger system when its
			# event happens; it is never a free-choice action.
			if TriggerCollector._is_collectable(effect):
				continue
			if not effect.trigger_events.is_empty():
				if not _window_matches(effect, window_events):
					continue
			if not chain.can_respond_with_spell_speed(effect.spell_speed):
				continue
			if not ActivationRules.can_activate(state, card, effect, pid, null):
				continue

			var kind: Enums.ActionKind = Enums.ActionKind.ACTIVATE_CARD \
				if effect.effect_type == Enums.EffectType.CARD_ACTIVATION \
				else Enums.ActionKind.ACTIVATE_EFFECT
			var a := DuelAction.make(kind, pid, card.id, effect.effect_id)
			a.label = "Activate %s" % card.card_name()
			a.clause_text = effect.clause_text
			if effect.targets:
				var ctx := ActivationRules.make_context(state, card, effect, pid, null)
				a.target_candidates = ActivationRules.legal_targets(ctx).map(
					func(c): return c.id)
				a.target_min = effect.target_count_min
				a.target_max = effect.target_count_max
			out.append(a)
	return out


static func _window_matches(effect: EffectDef, window_events) -> bool:
	if not (window_events is Array):
		return false
	for ev in window_events:
		if effect.trigger_events.has(ev.kind):
			return true
	return false


func _phase_actions(pid: int) -> Array:
	var out: Array = []
	if flow.can_enter_battle_phase(pid):
		var b := DuelAction.make(Enums.ActionKind.ENTER_BATTLE_PHASE, pid)
		b.label = "Enter the Battle Phase"
		out.append(b)
	if state.phase == Enums.Phase.BATTLE:
		var eb := DuelAction.make(Enums.ActionKind.END_BATTLE_PHASE, pid)
		eb.label = "End the Battle Phase"
		out.append(eb)
		# END_BATTLE_PHASE already reaches Main Phase 2; a second identical option
		# would only confuse the UI.
		return out
	var adv := DuelAction.make(Enums.ActionKind.END_PHASE, pid)
	if state.phase == Enums.Phase.END:
		adv.label = "End your turn" if flow.end_phase_cleanup_done \
			else "Finish the End Phase"
	else:
		adv.label = "Proceed to the %s" % Enums.phase_name(
			flow.next_phase_after(state.phase))
	out.append(adv)
	return out


# ---------------------------------------------------------------------------
# Submitting actions
# ---------------------------------------------------------------------------

## Validate and apply an action. Returns false and changes nothing if it is not legal.
func submit_action(action: DuelAction) -> bool:
	if action == null or state.is_duel_over():
		return false
	if action.player_id != waiting_player():
		return false

	var is_response := timing != Timing.OPEN
	if is_response:
		if not _is_legal_response(action):
			return false
	elif not _is_legal_action(action):
		return false

	log.record_action(state, action)
	_event_mark = state.events.size()

	if is_response:
		_apply_response(action)
	else:
		_apply_open_action(action)

	_advance()
	return true


func _find_action(candidates: Array, action: DuelAction) -> DuelAction:
	for c in candidates:
		if c.kind == action.kind and c.card_id == action.card_id \
				and c.effect_id == action.effect_id:
			return c
	return null


func _is_legal_action(action: DuelAction) -> bool:
	var template := _find_action(get_legal_actions(action.player_id), action)
	if template == null:
		return false
	return _choices_valid(template, action)


func _is_legal_response(action: DuelAction) -> bool:
	if action.kind == Enums.ActionKind.PASS:
		return true
	var template := _find_action(get_legal_responses(action.player_id), action)
	if template == null:
		return false
	return _choices_valid(template, action)


## The parameters the caller chose must be a legal selection from what was offered.
## Master prompt 87 — the engine never trusts a submitted selection.
func _choices_valid(template: DuelAction, action: DuelAction) -> bool:
	if template.tributes_required > 0 or not action.tribute_ids.is_empty():
		for tid in action.tribute_ids:
			if not template.tribute_candidates.has(tid):
				return false
		if action.tribute_ids.size() != _unique_count(action.tribute_ids):
			return false
		var card: CardInstance = state.instance(action.card_id)
		var materials: Array = action.tribute_ids.map(func(i): return state.instance(i))
		if not summons.tributes_satisfy(card, materials):
			return false
	if template.kind == Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE \
			and not template.legal_positions.is_empty() \
			and not template.legal_positions.has(action.position):
		return false
	if template.kind == Enums.ActionKind.DECLARE_ATTACK:
		if action.attack_target_id == -1:
			if not template.allows_direct_attack:
				return false
		elif not template.attack_target_candidates.has(action.attack_target_id):
			return false
	if template.target_min > 0 or not action.target_ids.is_empty():
		if action.target_ids.size() < template.target_min \
				or action.target_ids.size() > template.target_max:
			return false
		if action.target_ids.size() != _unique_count(action.target_ids):
			return false
		for tid in action.target_ids:
			if not template.target_candidates.has(tid):
				return false
		# A heterogeneous target selection needs the clause's own opinion: the candidate list
		# and the count cannot express "one of these two must be the attacking monster".
		if not _target_selection_ok(action):
			return false
	return true


## Ask the activated effect whether the submitted SET of targets is legal for it.
## True when the card declares no such rule, which is every card but `Kunai with Chain`.
func _target_selection_ok(action: DuelAction) -> bool:
	var card: CardInstance = state.instance(action.card_id)
	var effect := _find_effect(card, action.effect_id)
	if effect == null or not effect.targets_valid.is_valid():
		return true
	var ctx := ActivationRules.make_context(state, card, effect, action.player_id, null)
	var chosen: Array = []
	for tid in action.target_ids:
		var c = state.instance(int(tid))
		if c != null:
			chosen.append(c)
	return ActivationRules.target_selection_ok(ctx, chosen)


static func _unique_count(arr: Array) -> int:
	var seen := {}
	for v in arr:
		seen[v] = true
	return seen.size()


# --- Box A actions ---

func _apply_open_action(action: DuelAction) -> void:
	var pid := action.player_id
	var card: CardInstance = state.instance(action.card_id)

	match action.kind:
		Enums.ActionKind.NORMAL_SUMMON, Enums.ActionKind.TRIBUTE_SUMMON:
			var materials: Array = action.tribute_ids.map(func(i): return state.instance(i))
			var pending := summons.begin_normal_summon(card, pid, materials,
				action.zone_index)
			if pending.is_empty():
				return
			_pending_summon = pending
			_open_window_from_events(_events_since(_event_mark))

		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE:
			var effect := _find_effect(card, action.effect_id)
			if effect == null:
				return
			var ctx := ActivationRules.make_context(state, card, effect, pid, null)
			ctx.engine = self
			ctx.decider = _controller(pid)
			if effect.pay_cost.is_valid() and not bool(effect.pay_cost.call(ctx)):
				push_error("DuelEngine: summon procedure cost failed for %s after it "
					% card.card_name() + "was offered")
				return
			ActivationRules.mark_used(state, card, effect, pid)
			var ss_pending := summons.begin_special_summon(card, pid, action.position,
				card.id, action.zone_index)
			if ss_pending.is_empty():
				return
			# Which procedure was used is carried through to completion: a card that
			# restricts what it may do "the turn it is Special Summoned this way" has to
			# tell its own procedure apart from every other Special Summon.
			ss_pending["procedure_effect_id"] = effect.effect_id
			_pending_summon = ss_pending
			_open_window_from_events(_events_since(_event_mark))

		Enums.ActionKind.NORMAL_SET, Enums.ActionKind.TRIBUTE_SET:
			var materials2: Array = action.tribute_ids.map(func(i): return state.instance(i))
			summons.normal_set_monster(card, pid, materials2, action.zone_index)
			_open_window_from_events(_events_since(_event_mark))

		Enums.ActionKind.FLIP_SUMMON:
			# A Flip Summon is a Summon, so it declares and waits for its window like the
			# other two routes. RULES_SPEC.md 5.4 [S1 p.24].
			var flip_pending := summons.begin_flip_summon(card, pid)
			if flip_pending.is_empty():
				return
			_pending_summon = flip_pending
			_open_window_from_events(_events_since(_event_mark))

		Enums.ActionKind.CHANGE_POSITION:
			summons.change_position(card, pid)
			_open_window_from_events(_events_since(_event_mark))

		Enums.ActionKind.SET_SPELL_TRAP:
			_set_spell_trap(card, pid, action.zone_index)
			_open_window_from_events(_events_since(_event_mark))

		Enums.ActionKind.DECLARE_ATTACK:
			var target = null if action.attack_target_id == -1 \
				else state.instance(action.attack_target_id)
			if not battle.declare_attack(card, target, pid):
				return
			# The response window after an attack declaration is a real window: the
			# Damage Step only begins once both players have finished with it.
			_open_window_from_events(_events_since(_event_mark))

		Enums.ActionKind.ACTIVATE_CARD, Enums.ActionKind.ACTIVATE_EFFECT:
			var effect := _find_effect(card, action.effect_id)
			var link := _perform_activation(card, effect, pid, action.target_ids,
				action.params, null)
			if link == null:
				return
			_begin_chain_build(pid)

		Enums.ActionKind.ENTER_BATTLE_PHASE, Enums.ActionKind.END_BATTLE_PHASE, \
		Enums.ActionKind.END_PHASE:
			# Box A3: the turn player passes with a declared intent. The opponent still
			# gets box E before the phase actually changes.
			_pending_transition = action.kind
			_has_pending_transition = true
			timing = Timing.TP_PASSED

		Enums.ActionKind.SURRENDER:
			state.surrender(pid)

		_:
			push_error("DuelEngine: unhandled open action %s"
				% DuelAction.kind_name(action.kind))


func _set_spell_trap(card: CardInstance, pid: int, zone_index: int) -> void:
	var zone := Enums.Zone.SPELL_TRAP_ZONE
	if card.definition != null and card.definition.st_kind == Enums.STKind.FIELD_SPELL:
		zone = Enums.Zone.FIELD_ZONE
	if not state.move_card(card, zone, Enums.MoveReason.SET, {
			"index": zone_index, "to_player": pid,
			"position": Enums.Position.FACE_DOWN}):
		return
	card.turn_set = state.turn_number
	state.emit(GameEvent.Kind.CARD_SET, {
		"card_id": card.id, "card_name": card.card_name(), "player": pid,
		"is_monster": false, "private_to": [pid],
	})


# --- Response windows ---

func _apply_response(action: DuelAction) -> void:
	var pid := action.player_id

	if action.kind == Enums.ActionKind.PASS:
		state.emit(GameEvent.Kind.RESPONSE_PASSED, {"player": pid, "timing": timing})
		_on_pass(pid)
		return

	var card = state.instance(action.card_id)
	var effect := _find_effect(card, action.effect_id)
	var link := _perform_activation(card, effect, pid, action.target_ids, action.params,
		_matching_window_event(effect))
	if link == null:
		return
	_begin_chain_build(pid)


func _matching_window_event(effect: EffectDef):
	for ev in _window_events:
		if effect.trigger_events.has(ev.kind):
			return ev
	return null


func _on_pass(pid: int) -> void:
	match timing:
		Timing.FAST_TURN:
			timing = Timing.FAST_OPP
		Timing.FAST_OPP:
			_close_window()
		Timing.TP_PASSED:
			_execute_pending_transition()
		Timing.CHAIN_BUILD:
			_consecutive_passes += 1
			_responder_id = state.opponent_id(pid)
		_:
			pass


## After any activation the Chain is being built, and the next chance to respond goes to
## the player who did NOT activate the most recent Chain Link [S2 box D].
func _begin_chain_build(activating_player: int) -> void:
	_window_events.append_array(_events_since(_event_mark))
	_consecutive_passes = 0
	_responder_id = state.opponent_id(activating_player)
	timing = Timing.CHAIN_BUILD


# ---------------------------------------------------------------------------
# Activation
# ---------------------------------------------------------------------------

static func _find_effect(card, effect_id: String) -> EffectDef:
	if card == null or card.definition == null:
		return null
	for e in card.definition.effects:
		if e.effect_id == effect_id:
			return e
	return null


## Perform one activation: place/flip the card if it is a Spell/Trap card activation,
## pay the cost, then create the Chain Link. RULES_SPEC.md 10 — costs are paid and
## targets are fixed at activation, never at resolution.
func _perform_activation(card: CardInstance, effect: EffectDef, pid: int,
		target_ids: Array, params: Dictionary, trigger_event) -> ChainLink:
	if card == null or effect == null:
		push_error("DuelEngine: activation with no card/effect")
		return null

	var ctx := ActivationRules.make_context(state, card, effect, pid, trigger_event)
	ctx.engine = self
	ctx.decider = _controller(pid)
	ctx.chosen_target_ids = target_ids.duplicate()

	if effect.effect_type == Enums.EffectType.CARD_ACTIVATION:
		_reveal_for_activation(card, pid)

	if effect.pay_cost.is_valid():
		var cost_mark := state.events.size()
		if not bool(effect.pay_cost.call(ctx)):
			push_error("DuelEngine: cost payment failed for %s '%s' after it was offered"
				% [card.card_name(), effect.effect_id])
			return null
		state.emit(GameEvent.Kind.COST_PAID, {
			"card_id": card.id, "card_name": card.card_name(),
			"effect_id": effect.effect_id, "player": pid,
			"payload": ctx.cost_payload.duplicate(),
		})
		# Anything the cost raised waits for this Chain to finish resolving. See
		# `_cost_events`.
		_cost_events.append_array(_events_since(cost_mark))

	var link := chain.add_link(card, effect, pid, target_ids, ctx.cost_payload, params)
	ActivationRules.mark_used(state, card, effect, pid)
	return link


## Activating a Spell/Trap reveals it: from the hand it is placed face-up in a zone,
## and a Set card is flipped face-up in place. [S1 p.28-30]
func _reveal_for_activation(card: CardInstance, pid: int) -> void:
	if card.zone == Enums.Zone.HAND:
		var zone := Enums.Zone.SPELL_TRAP_ZONE
		if card.definition != null \
				and card.definition.st_kind == Enums.STKind.FIELD_SPELL:
			zone = Enums.Zone.FIELD_ZONE
			# A new Field Spell replaces the one already there. [S1 p.29]
			var existing = state.player(pid).field_zone
			if existing != null:
				state.move_card(existing, Enums.Zone.GRAVEYARD,
					Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {"source_id": card.id})
		state.move_card(card, zone, Enums.MoveReason.RULE, {
			"to_player": pid, "position": Enums.Position.FACE_UP})
	elif card.is_on_field() and card.is_face_down():
		state.set_battle_position(card, Enums.Position.FACE_UP, true)


## A card whose OWN TEXT says it stays on the field after its activation resolves, despite
## its printed kind. `Swords of Revealing Light` is a NORMAL Spell that prints "After this
## card's activation, it remains on the field", and [S1 p.28] says a Normal Spell goes to
## the GY once it resolves — so the card overrides the rule, and the override has to be
## something the card DECLARES rather than something the engine infers.
##
## Declarative, like `SummonRules.CONTROL_LIMIT_EFFECT_ID` and
## `GameState.DESTRUCTION_REPLACEMENT_EFFECT_ID`: the card declares an EffectDef carrying
## this id and `_cleanup_resolved_spell_traps()` asks for it by id. No card name ever
## reaches the sweeper, and a second card that prints the same sentence needs no engine
## change.
##
## **Deliberately NOT `Enums.stays_on_field()`.** That answers "does this KIND of card stay",
## which is a property of the printed icon and must keep its single, kind-only answer — a
## Normal Spell is still a Normal Spell, and every other Normal Spell in the pool must still
## be swept. This is the separate question "does THIS card override it", and keeping the two
## apart is what stops one card's exception from silently becoming a rule about its kind.
const REMAINS_ON_FIELD_EFFECT_ID := "remains_on_field_after_activation"


## Does `card` declare the override? Static so the rules layer and the tests can ask without
## holding an engine.
##
## **Deliberately NOT negation-aware**, unlike `CONTROL_LIMIT_EFFECT_ID` and
## `TRIBUTE_VALUE_EFFECT_ID`. Those are continuous effects applying a modifier to the board,
## and switching them off is exactly what negation means. This is not a modifier: it says
## where the card GOES after it resolves, which is the same kind of statement as a Continuous
## Spell's icon — and `Enums.stays_on_field()` is not negation-aware either. Making it so
## would mean that negating a card's effects sent it to the Graveyard, and negation does not
## do that [S1 p.28-30]. Asserted directly in `SpellTrapTests`.
static func card_remains_on_field_after_activation(card: CardInstance) -> bool:
	if card == null or card.definition == null:
		return false
	for effect in card.definition.effects:
		if effect.effect_id == REMAINS_ON_FIELD_EFFECT_ID:
			return true
	return false


## After a Chain resolves, a Spell/Trap that does not remain on the field is sent to the
## GY. This happens whether or not the activation was negated: it was still activated.
## Continuous / Equip / Field Spells and Continuous Traps stay. [S1 p.28-30]
func _cleanup_resolved_spell_traps(links: Array) -> void:
	for link in links:
		var card: CardInstance = link.source_card
		if card == null or card.definition == null:
			continue
		if link.effect == null \
				or link.effect.effect_type != Enums.EffectType.CARD_ACTIVATION:
			continue
		if not card.is_on_field():
			continue
		# An Equip Card that found its monster stays on the field whatever kind of card it
		# is: "Equipped Traps remain Trap Cards" but they are Equip Cards now [S1 p.53].
		# `Gagagashield` is a NORMAL Trap and must not be swept away after equipping.
		if card.equipped_to_id != -1:
			continue
		if Enums.stays_on_field(card.definition.st_kind):
			# …and an Equip Spell that resolved WITHOUT equipping has no monster to give
			# its effect to, so it does not stay either [S1 p.29].
			if card.definition.st_kind == Enums.STKind.EQUIP_SPELL:
				state.move_card(card, Enums.Zone.GRAVEYARD, Enums.MoveReason.RESOLVED_TO_GY)
			continue
		# A card whose own text overrides its kind. Asked AFTER the kind question so the
		# override can only ever keep a card that would otherwise be swept — it can never
		# send one to the GY that the rules say stays.
		if card_remains_on_field_after_activation(card):
			continue
		state.move_card(card, Enums.Zone.GRAVEYARD, Enums.MoveReason.RESOLVED_TO_GY)


# ---------------------------------------------------------------------------
# Summon negation hook, called by card effects through EffectContext.engine.
# ---------------------------------------------------------------------------

## `Champion's Vigilance`: "when a monster(s) would be Summoned: Negate the Summon".
## Returns the monster whose Summon was negated, or null when no Summon is pending.
func negate_pending_summon(by_card_id: int = -1):
	if _pending_summon.is_empty() or bool(_pending_summon.get("negated", false)):
		return null
	_pending_summon["negated"] = true
	_pending_summon["negated_by"] = by_card_id
	return _pending_summon["card"]


func pending_summon_card():
	return _pending_summon.get("card", null)


# ---------------------------------------------------------------------------
# Special Summon hook, called by card effects through EffectContext.engine.
# ---------------------------------------------------------------------------

## Special Summon `card` for `controller_id` from wherever it currently is.
## RULES_SPEC.md 5.5 [S1 p.24].
##
## This is the RESOLUTION-time path: the `Shining Angel` family Special Summons while an
## effect resolves, and a new Chain never starts mid-resolution (master prompt 45), so the
## Summon is declared and completed in one step with no window between the two. That is
## not a shortcut around summon negation — a card that negates a Summon performed by a
## resolving effect is activated in response to that effect's ACTIVATION, which is an
## ordinary Chain response the engine already supports.
##
## The other path is `Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE`: a Special Summon the
## player performs themselves in an open game state. That one DOES open a declaration
## window, because there is no activation to respond to instead.
##
## Returns true only when the monster actually reached a Monster Zone. A caller must not
## assume success: a full Monster Zone makes the Summon illegal and it simply does not
## happen (the card stays where it was).
func special_summon(card: CardInstance, controller_id: int, position: Enums.Position,
		source_id: int = -1, zone_index: int = -1,
		to_zone: Enums.Zone = Enums.Zone.MONSTER_ZONE) -> bool:
	var pending := summons.begin_special_summon(card, controller_id, position,
		source_id, zone_index, to_zone)
	if pending.is_empty():
		return false
	return summons.complete_summon(pending)


# ---------------------------------------------------------------------------
# The state machine. RULES_SPEC.md 3.
# ---------------------------------------------------------------------------

func _advance() -> void:
	if _advancing:
		return
	_advancing = true
	var guard := 0
	while true:
		guard += 1
		if guard > 512:
			push_error("DuelEngine: timing machine did not settle")
			break
		if state.is_duel_over():
			timing = Timing.DUEL_OVER
			break

		# Continuous effects are state-derived: recompute before any legality question
		# is asked, so a modifier or restriction is never stale. Master prompt 25.
		if continuous != null:
			continuous.recompute()

		# A control lease worded "while this card is face-up on the field" ends the moment
		# its source stops being that, so it is checked at the same cadence as the
		# continuous recompute. It is a state MUTATION rather than a derived flag, which is
		# why it does not live inside recompute(). RULES_SPEC.md 5.6.
		state.expire_control_leases()
		# The temporary-banish leases are checked at exactly the same cadence, for the same
		# reason and so the two can never disagree about a shared end condition. Nothing in
		# the V1 pool has a banish duration that ends anywhere but the End Phase, so this
		# call is a no-op today — it is here so that adding one cannot forget it.
		# RULES_SPEC.md 8.3.
		state.expire_banish_leases()

		match timing:
			Timing.TRIGGER_CHECK:
				if _do_trigger_check():
					continue
				timing = Timing.FAST_TURN
				continue

			Timing.FAST_TURN:
				if _has_any_response(state.turn_player_id):
					break
				timing = Timing.FAST_OPP
				continue

			Timing.FAST_OPP:
				if _has_any_response(state.opponent_id(state.turn_player_id)):
					break
				_close_window()
				continue

			Timing.CHAIN_BUILD:
				if _consecutive_passes >= 2:
					_resolve_current_chain()
					continue
				if _has_any_response(_responder_id):
					break
				# No legal response: that side passes automatically. Full Response Mode
				# only ever prompts a player who actually has something to do.
				state.emit(GameEvent.Kind.RESPONSE_PASSED,
					{"player": _responder_id, "automatic": true})
				_consecutive_passes += 1
				_responder_id = state.opponent_id(_responder_id)
				continue

			Timing.TP_PASSED:
				if _has_any_response(state.opponent_id(state.turn_player_id)):
					break
				_execute_pending_transition()
				continue

			Timing.OPEN, Timing.DUEL_OVER, Timing.SETUP:
				break
			_:
				break
	_advancing = false


## The A1 "does this activate a triggered effect?" node, also reached after every Chain
## resolves. Returns true when triggers formed a new Chain. RULES_SPEC.md 3, 4.4.
func _do_trigger_check() -> bool:
	_window_events = _pending_events.duplicate()
	var batch := _pending_events
	_pending_events = []
	if batch.is_empty():
		return false

	var ordered := triggers.collect_ordered(batch)
	if ordered.is_empty():
		return false

	var mark := state.events.size()
	var last_controller := -1
	for entry in ordered:
		var card: CardInstance = entry["source"]
		var effect: EffectDef = entry["effect"]
		var controller_id: int = int(entry["controller"])
		# Conditions are rechecked: an earlier link in this same batch may have made a
		# later one illegal.
		if not ActivationRules.can_activate(state, card, effect, controller_id,
				entry["event"]):
			continue
		# Explicitly typed: _choose_targets_for returns null when no legal target set
		# exists, so its declared type is Variant and := would infer Variant here.
		var chosen = _choose_targets_for(card, effect, controller_id, entry["event"])
		if chosen == null:
			continue
		if _perform_activation(card, effect, controller_id, chosen, {},
				entry["event"]) != null:
			last_controller = controller_id

	if chain.chain_size() == 0:
		return false

	_window_events.append_array(_events_since(mark))
	_consecutive_passes = 0
	_responder_id = state.opponent_id(last_controller) if last_controller != -1 \
		else state.turn_player_id
	timing = Timing.CHAIN_BUILD
	return true


## Ask a trigger's controller which targets to use. Returns null when the effect targets
## but no legal set of targets exists, in which case it cannot be activated at all.
func _choose_targets_for(card: CardInstance, effect: EffectDef, pid: int,
		trigger_event) -> Variant:
	if not effect.targets:
		return []
	var ctx := ActivationRules.make_context(state, card, effect, pid, trigger_event)
	var legal := ActivationRules.legal_targets(ctx)
	if legal.size() < effect.target_count_min:
		return null
	var options := legal.map(func(c): return c.id)
	var ctrl = _controller(pid)
	if ctrl == null:
		return options.slice(0, effect.target_count_min)
	var req := DecisionRequest.select(Enums.DecisionKind.CHOOSE_TARGETS, pid,
		"Choose target(s) for %s" % card.card_name(), options,
		effect.target_count_min, effect.target_count_max, card, effect)
	var answer = ctrl.decide(req)
	log.record_decision(state, req, answer)
	if not req.validate(answer):
		push_error("DuelEngine: invalid target selection for %s" % card.card_name())
		return options.slice(0, effect.target_count_min)
	return answer


func _resolve_current_chain() -> void:
	var mark := state.events.size()
	chain.resolve_chain(controllers)
	_cleanup_resolved_spell_traps(chain.last_resolved_links)
	state.check_life_point_loss()
	# Everything raised while the Chain resolved is handled now, after it fully
	# resolved — never as an interruption. Master prompt 45.
	#
	# The COST events come first: they happened first, before any link was even on the
	# Chain, and a batch's order decides the order simultaneous triggers are offered in
	# (RULES_SPEC.md 4.4).
	_pending_events = _cost_events + _events_since(mark)
	_cost_events = []
	timing = Timing.TRIGGER_CHECK


## Box E closed with both players declining: carry out the phase/step change the turn
## player asked for, then run a trigger check on whatever it produced.
func _execute_pending_transition() -> void:
	if not _has_pending_transition:
		timing = Timing.OPEN
		return
	var kind := _pending_transition
	_has_pending_transition = false
	_pending_transition = Enums.ActionKind.PASS

	var mark := state.events.size()
	match kind:
		Enums.ActionKind.ENTER_BATTLE_PHASE:
			flow.enter_phase(Enums.Phase.BATTLE)
			# The Battle Phase opens with its Start Step. [S1 p.37]
			state.battle_step = Enums.BattleStep.START
			state.emit(GameEvent.Kind.BATTLE_STEP_CHANGED,
				{"step": Enums.BattleStep.START})
		Enums.ActionKind.END_BATTLE_PHASE:
			battle.end_battle_phase()
			flow.enter_phase(Enums.Phase.MAIN_2)
		Enums.ActionKind.END_PHASE:
			if flow.needs_end_phase_cleanup():
				# Discard for hand size at the END of the End Phase, so anything it
				# triggers still resolves during this End Phase. [S1 p.40]
				flow.perform_end_phase_cleanup()
			elif state.phase == Enums.Phase.END:
				flow.begin_next_turn()
			else:
				flow.enter_phase(flow.next_phase_after(state.phase))
		_:
			pass

	_pending_events = _events_since(mark)
	timing = Timing.TRIGGER_CHECK


## Both players declined in boxes B and C. Anything that was waiting on this window
## happens now, and only then does the open game state return.
func _close_window() -> void:
	_window_events = []
	if not _pending_summon.is_empty():
		var pending := _pending_summon
		_pending_summon = {}
		var mark := state.events.size()
		if bool(pending.get("negated", false)):
			summons.abort_summon(pending, int(pending.get("negated_by", -1)))
		else:
			summons.complete_summon(pending)
		_pending_events = _events_since(mark)
		timing = Timing.TRIGGER_CHECK
		return
	if battle != null and battle.stage != BattleRules.Stage.NONE:
		_advance_battle()
		return
	if state.phase == Enums.Phase.BATTLE \
			and state.battle_step == Enums.BattleStep.START:
		# The Start Step's window is over; the Battle Step begins. [S1 p.37]
		state.battle_step = Enums.BattleStep.BATTLE
		state.emit(GameEvent.Kind.BATTLE_STEP_CHANGED,
			{"step": Enums.BattleStep.BATTLE})
	timing = Timing.OPEN


## Step the Damage Step forward one sub-step. RULES_SPEC.md 7.1 [S3].
##
## Each sub-step ends by handing control back to the timing machine, which opens a
## response window before the next one begins — that is what makes the Damage Step
## activation restriction [S1 p.41] meaningful rather than cosmetic.
func _advance_battle() -> void:
	var mark := state.events.size()

	match battle.stage:
		BattleRules.Stage.AFTER_DECLARATION:
			if battle.attack_is_negated():
				# The attack was legally declared and then negated. The Battle Phase
				# CONTINUES — only this attack is over — so the battle is cleared and the
				# machine goes back to the Battle Step. RULES_SPEC.md 6.3.
				#
				# This is checked FIRST, ahead of both the attacker check and the Replay
				# check, and the order is load-bearing rather than incidental. `Maiden with
				# Eyes of Blue` negates the attack and then Special Summons a monster to the
				# ATTACKED player's field, which changes the set of monsters the attacker
				# faces — so `replay_required()` answers true on exactly the path where a
				# negation just happened. Asking about a Replay first would turn a spent
				# attack back into a fresh choice and hand the attacking player a second
				# declaration the negation was supposed to have taken away.
				#
				# `clear_battle()`, not `begin_replay()`: the attacker keeps
				# `has_attacked_this_turn`, because the attack really was declared.
				battle.clear_battle()
				_pending_events = _events_since(mark)
				timing = Timing.TRIGGER_CHECK
				return
			if not battle.attacker_still_valid():
				# The ATTACKER left the field: the attack does not happen at all.
				# The target leaving is a different case and is handled by the Replay
				# check below, which must therefore come second. [S1 p.39]
				battle.clear_battle()
				_pending_events = _events_since(mark)
				timing = Timing.TRIGGER_CHECK
				return
			if battle.replay_required():
				battle.begin_replay()
				_pending_events = _events_since(mark)
				timing = Timing.TRIGGER_CHECK
				return
			if not battle.target_still_valid():
				# Unreachable in principle: a target that left the field means the
				# opponent's monsters changed, which replay_required() already reported.
				# Cancelling is still safer than calculating damage against a card that
				# is not on the field.
				battle.clear_battle()
				_pending_events = _events_since(mark)
				timing = Timing.TRIGGER_CHECK
				return
			battle.begin_damage_step()
			_pending_events = _events_since(mark)

		BattleRules.Stage.DS_START:
			battle.step_before_damage_calculation()
			# The flip itself is withheld: its Flip effect belongs to sub-step 4.
			var evs := _events_since(mark)
			_carried_events = evs.filter(
				func(e): return e.kind == GameEvent.Kind.CARD_FLIPPED_FACE_UP)
			_pending_events = evs.filter(
				func(e): return e.kind != GameEvent.Kind.CARD_FLIPPED_FACE_UP)

		BattleRules.Stage.DS_BEFORE:
			# Damage calculation itself offers no window: cards may only be activated
			# "up until the start of damage calculation" [S1 p.41]. Sub-steps 3 and 4
			# therefore run back to back, and the trigger check happens in sub-step 4.
			battle.step_damage_calculation()
			state.check_life_point_loss()
			battle.step_after_damage_calculation()
			_pending_events = _carried_events + _events_since(mark)
			_carried_events = []

		BattleRules.Stage.DS_AFTER:
			battle.step_end_of_damage_step()
			_pending_events = _events_since(mark)

		BattleRules.Stage.DS_END:
			battle.finish_damage_step()
			_pending_events = _events_since(mark)

		_:
			timing = Timing.OPEN
			return

	timing = Timing.TRIGGER_CHECK


## Open a response window for the events an A1 action just produced.
func _open_window_from_events(events: Array) -> void:
	_pending_events = events
	timing = Timing.TRIGGER_CHECK


func _events_since(mark: int) -> Array:
	var out: Array = []
	for i in range(mark, state.events.size()):
		out.append(state.events[i])
	return out


func _controller(pid: int):
	if pid >= 0 and pid < controllers.size():
		return controllers[pid]
	return null
