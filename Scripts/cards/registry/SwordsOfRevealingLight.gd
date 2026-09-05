extends RefCounted

## Swords of Revealing Light — Normal Spell. One copy, deck 2.
##
## Official text (verified against the Konami card database, `Data/cards/cards.json`,
## cid 4354):
##
##   "After this card's activation, it remains on the field, but you must destroy it during
##    the End Phase of your opponent's 3rd turn. When this card is activated: If your
##    opponent controls a face-down monster, flip all monsters they control face-up. While
##    this card is face-up on the field, your opponent's monsters cannot declare an attack."
##
## **Three sentences, three EffectDefs**, and they are three genuinely different shapes —
## which is the whole reason this card is interesting. `Research/CARD_RULINGS.md` **R6**.
##
## | # | Sentence | Shape |
## |---|---|---|
## | 1 | "After this card's activation, it remains on the field, but you must destroy it during the End Phase of your opponent's 3rd turn." | CONTINUOUS, `respond_to_event` on `PHASE_CHANGED → END`, **and** the `DuelEngine.REMAINS_ON_FIELD_EFFECT_ID` marker |
## | 2 | "When this card is activated: If your opponent controls a face-down monster, flip all monsters they control face-up." | CARD_ACTIVATION — this is the Chain Link the card makes |
## | 3 | "While this card is face-up on the field, your opponent's monsters cannot declare an attack." | CONTINUOUS, `apply_continuous` |
##
## Six things this card pins down, each of which has a test:
##
##   1. **It is a NORMAL Spell that stays on the field.** [S1 p.28] sends a Normal Spell to
##      the GY once it resolves, so the card overrides the rule for its kind. The override is
##      declared, not inferred: clause 1 carries `DuelEngine.REMAINS_ON_FIELD_EFFECT_ID`, and
##      the generic channel plus its own tests were written before this card existed
##      (`SpellTrapTests`). Its `st_kind` is still `NORMAL_SPELL` and must stay so.
##   2. **R6 — which End Phase is the 3rd.** Only the OPPONENT's turns are counted, and the
##      count starts from the first opponent turn after activation. A Normal Spell can only
##      be activated during its controller's own Main Phase [S1 p.31], so the controller's
##      own turn is never one of the three and the question has one answer in this pool. The
##      turn counter is `EffectPrimitives.count_turn_for()`, which counts at most once per
##      turn number and takes the counted player as a parameter rather than assuming the two
##      players alternate.
##   3. **Clause 1 is not a Trigger Effect.** "You must destroy it during the End Phase" puts
##      no link on the Chain and is never offered as a choice, so it is a CONTINUOUS clause
##      responding to an event (`respond_to_event`), the shape `Judge of the Ice Barrier`
##      clause 1 established. Modelling it as a TRIGGER would wrongly open a response window
##      and wrongly let the destruction be negated as an effect activation.
##   4. **"If your opponent controls a face-down monster" is checked at RESOLUTION, not at
##      activation.** It sits AFTER the colon, so it is part of the effect [S1 p.51 PSCT].
##      The card may be activated with no face-down monster anywhere — it simply flips
##      nothing. Making it an activation `condition` would forbid a legal play.
##   5. **Flipping is not a Flip Summon.** `EffectPrimitives.flip_face_up()` emits
##      `CARD_FLIPPED_FACE_UP` and no Summon event, so real FLIP effects are collected at the
##      resulting window while the once-per-turn Normal Summon allowance is untouched. A
##      face-down monster is in Defense Position and stays there: FACE_UP_DEFENSE.
##   6. **Clause 3 is attack PREVENTION, not attack negation.** `restrict_opponent_attacks()`
##      — the attack is never DECLARED, no `ATTACK_DECLARED` event exists, and the monster
##      keeps its attack for the turn. `CARD_RULINGS.md` R34 part A, proved generically in
##      `AttackRestrictionTests`.
##
## The three clauses have three different lifetimes and they are deliberately not merged:
## clause 1 outlives resolution and ends the card, clause 3 applies only while the card is
## face-up on the field, and clause 2 happens once.

const CARD_NAME := "Swords of Revealing Light"

## How many of the opponent's turns the card survives. Named rather than inlined so R6 is
## one number in one place if it is ever corrected.
const OPPONENT_TURNS := 3

## The per-instance turn-counter key. Per-card state on `CardInstance.turn_counters`, which
## is cleared when the card leaves the field — a second copy would count its own turns.
const TURN_COUNTER_KEY := "swords_opponent_turns"

const CLAUSE_LIFETIME := "After this card's activation, it remains on the field, but you " \
	+ "must destroy it during the End Phase of your opponent's 3rd turn."
const CLAUSE_FLIP := "When this card is activated: If your opponent controls a face-down " \
	+ "monster, flip all monsters they control face-up."
const CLAUSE_ATTACK_LOCK := "While this card is face-up on the field, your opponent's " \
	+ "monsters cannot declare an attack."


func effects() -> Array:
	return [_lifetime(), _flip_on_activation(), _attack_lock()]


# ---------------------------------------------------------------------------
# Clause 1 — it remains on the field, and destroys itself on a schedule.
# ---------------------------------------------------------------------------

## The effect id IS the marker `DuelEngine._cleanup_resolved_spell_traps()` reads. That is
## not a trick: this sentence is the card's lifetime sentence, and "it remains on the field"
## is half of what it says. The other half — the countdown — is `respond_to_event`.
func _lifetime() -> EffectDef:
	var e := EffectDef.new(DuelEngine.REMAINS_ON_FIELD_EFFECT_ID, CLAUSE_LIFETIME)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.on_events([GameEvent.Kind.PHASE_CHANGED])
	e.mandatory()
	e.ruling("R6")

	# Only the opponent's End Phases are counted, and only once each.
	e.condition = func(ctx: EffectContext) -> bool:
		var ev := ctx.trigger_event
		if ev == null or int(ev.data.get("to", -1)) != int(Enums.Phase.END):
			return false
		return ctx.state.turn_player_id == ctx.opponent_id()

	e.respond_to_event = func(ctx: EffectContext) -> void:
		var n := EffectPrimitives.count_turn_for(ctx, TURN_COUNTER_KEY, ctx.opponent_id())
		if n < OPPONENT_TURNS:
			ctx.log_note("this is the opponent's turn %d of %d" % [n, OPPONENT_TURNS])
			return
		# "you MUST destroy it" — mandatory, and it destroys ITSELF, so it is an ordinary
		# field destruction with this card as both source and victim.
		ctx.log_note("the opponent's %d turns have passed" % OPPONENT_TURNS)
		ctx.state.destroy(ctx.source, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id)

	return e


# ---------------------------------------------------------------------------
# Clause 2 — the activation, and the flip.
# ---------------------------------------------------------------------------

func _flip_on_activation() -> EffectDef:
	var e := EffectDef.new("flip_opponents_monsters_face_up", CLAUSE_FLIP)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Spell is activated from the hand or from a Set copy; it is never activated
	# from a face-up field position, because being face-up on the field is what activating
	# it does.
	e.from_locations([Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN])

	# Deliberately NO `condition`. "If your opponent controls a face-down monster" is after
	# the colon, so it belongs to the effect and is checked at resolution — the card is
	# legal to activate against an empty board.

	e.resolve = func(ctx: EffectContext) -> void:
		var pid := ctx.opponent_id()
		if not EffectPrimitives.controls_a_face_down_monster(ctx, pid):
			ctx.log_note("the opponent controls no face-down monster")
			return
		var flipped := EffectPrimitives.flip_face_up(ctx, pid)
		ctx.log_note("flipped %d monster(s) face-up" % flipped.size())

	return e


# ---------------------------------------------------------------------------
# Clause 3 — the attack lock.
# ---------------------------------------------------------------------------

func _attack_lock() -> EffectDef:
	var e := EffectDef.new("opponents_monsters_cannot_attack", CLAUSE_ATTACK_LOCK)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.ruling("R34")

	e.apply_continuous = func(ctx: EffectContext) -> void:
		EffectPrimitives.restrict_opponent_attacks(ctx)

	return e
