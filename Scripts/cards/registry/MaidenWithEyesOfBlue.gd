extends RefCounted

## Maiden with Eyes of Blue — LIGHT / Spellcaster / Level 1 / Tuner, 0 ATK / 0 DEF.
## One copy, deck 1 ("Blue-Eyes Dragon Guard").
##
## Official text (verified against the Konami card database, `Data/cards/cards.json`,
## cid 10588):
##
##   "When a card or effect is activated that targets this card (Quick Effect): You can
##    Special Summon 1 "Blue-Eyes White Dragon" from your hand, Deck, or GY. When this card
##    is targeted for an attack: You can negate the attack, and if you do, change the battle
##    position of this card, then you can Special Summon 1 "Blue-Eyes White Dragon" from your
##    hand, Deck, or GY. You can only use 1 "Maiden with Eyes of Blue" effect per turn, and
##    only once that turn."
##
## **Two effect clauses plus a restriction sentence that governs both.**
## `Research/CARD_RULINGS.md` **R3**.
##
## Six things this card pins down, each of which has a test:
##
##   1. **The two clauses share ONE use per turn.** "You can only use 1 'Maiden with Eyes of
##      Blue' effect per turn, and only once that turn" is a single allowance across both
##      clauses, not one each. Both carry `opt_named_effect()` **and the same `in_group()`
##      key**, which is the mechanism `EffectDef.restriction_group` exists for and which
##      `AttackRestrictionTests` proved before this card was written. `opt_instance()` would
##      be wrong (it is per-copy, not per-name) and a separate `opt_named_effect()` per
##      clause would be wrong the other way — it would give the card two uses.
##   2. **Clause 1 is a QUICK effect; clause 2 is a TRIGGER.** Only clause 1 prints
##      "(Quick Effect)". Clause 1 is Spell Speed 2 and is chosen by its controller in the
##      response window the targeting activation opened; clause 2 is Spell Speed 1 and is put
##      on the Chain by the trigger system when the attack is declared.
##   3. **Clause 1's condition is read from the CHAIN, not from the trigger event.** A Quick
##      Effect is offered by `DuelEngine._activation_actions()`, which asks
##      `ActivationRules.can_activate()` with no event — so
##      `EffectPrimitives.is_targeted_by_a_live_activation()` reads the live, unresolved
##      Chain Links instead. See that primitive for why.
##   4. **Clause 2 negates the ATTACK, it does not cancel it.** The attack really was
##      declared, the monster really has attacked this turn, and `BattleRules.negate_attack()`
##      is the one channel — never the Replay path. `CARD_RULINGS.md` R34 parts A and B.
##   5. **"and if you do" gates the rest of clause 2.** If the negation does not happen there
##      is no position change and no Special Summon. The three steps are strictly ordered:
##      negate → change position → Special Summon, and the summon is a second "you can", so
##      it may be declined on its own.
##   6. **The Special Summon reaches three zones — hand, Deck and GY** — and uses the
##      established engine route (`special_summon_one_any_position()`), not a
##      Maiden-specific summon path. It does not target: there is no "target" in either
##      clause, so which copy is Summoned is chosen at RESOLUTION.
##
## The clause is genuinely live in this pool: `Blue-Eyes White Dragon` is in the same deck.

const CARD_NAME := "Maiden with Eyes of Blue"

const SUMMONS := "Blue-Eyes White Dragon"

## The shared once-per-turn group. Both clauses carry it, so using either spends the single
## allowance the printed restriction sentence grants.
const SHARED_USE_GROUP := "maiden_with_eyes_of_blue_effect"

## The three zones the Special Summon reaches, in the order the card names them.
const SUMMON_ZONES := [Enums.Zone.HAND, Enums.Zone.DECK, Enums.Zone.GRAVEYARD]

const CLAUSE_TARGETED := "When a card or effect is activated that targets this card " \
	+ "(Quick Effect): You can Special Summon 1 \"Blue-Eyes White Dragon\" from your " \
	+ "hand, Deck, or GY."
const CLAUSE_ATTACKED := "When this card is targeted for an attack: You can negate the " \
	+ "attack, and if you do, change the battle position of this card, then you can " \
	+ "Special Summon 1 \"Blue-Eyes White Dragon\" from your hand, Deck, or GY."
const CLAUSE_RESTRICTION := "You can only use 1 \"Maiden with Eyes of Blue\" effect per " \
	+ "turn, and only once that turn."


func effects() -> Array:
	return [_when_targeted(), _when_attacked()]


## "Special Summon 1 'Blue-Eyes White Dragon' from your hand, Deck, or GY" — the tail both
## clauses share, word for word. Returns the monster Summoned, or null.
static func _summon_blue_eyes(ctx: EffectContext, prompt: String):
	var candidates := EffectPrimitives.own_cards_in_zones(ctx, SUMMON_ZONES,
		EffectPrimitives.monster_named(SUMMONS))
	if candidates.is_empty():
		ctx.log_note("no \"%s\" in the hand, Deck or GY" % SUMMONS)
		return null
	var summoned := EffectPrimitives.special_summon_one_any_position(ctx, candidates, prompt)
	if summoned != null:
		ctx.log_note("Special Summoned %s" % summoned.card_name())
	return summoned


# ---------------------------------------------------------------------------
# Clause 1 — the Quick Effect, when something targets this card.
# ---------------------------------------------------------------------------

func _when_targeted() -> EffectDef:
	var e := EffectDef.new("summon_blue_eyes_when_targeted",
		CLAUSE_TARGETED + " " + CLAUSE_RESTRICTION)
	e.of_type(Enums.EffectType.QUICK)
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_UP])
	e.on_events([GameEvent.Kind.TARGET_SELECTED])
	e.opt_named_effect()
	e.in_group(SHARED_USE_GROUP)
	e.ruling("R3")

	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.is_targeted_by_a_live_activation(ctx, ctx.source)

	e.resolve = func(ctx: EffectContext) -> void:
		_summon_blue_eyes(ctx, "Special Summon 1 \"%s\" from your hand, Deck, or GY"
			% SUMMONS)

	return e


# ---------------------------------------------------------------------------
# Clause 2 — the Trigger Effect, when this card is targeted for an attack.
# ---------------------------------------------------------------------------

func _when_attacked() -> EffectDef:
	var e := EffectDef.new("negate_attack_and_summon_blue_eyes",
		CLAUSE_ATTACKED + " " + CLAUSE_RESTRICTION)
	e.of_type(Enums.EffectType.TRIGGER)
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_UP])
	e.on_events([GameEvent.Kind.ATTACK_DECLARED])
	e.opt_named_effect()
	e.in_group(SHARED_USE_GROUP)
	e.ruling("R3")

	# Read from the authoritative battle state rather than from the event payload, so it
	# stays true for the whole Battle Step window. A DIRECT attack has no target, so this
	# is correctly false then.
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.is_current_attack_target(ctx, ctx.source)

	e.resolve = func(ctx: EffectContext) -> void:
		# "You can negate the attack, AND IF YOU DO, …" — everything after depends on the
		# negation actually happening. A resolution that arrives too late (the Damage Step
		# has begun, or the attack was already negated) does nothing else at all.
		if not EffectPrimitives.negate_declared_attack(ctx):
			return
		# "…change the battle position of this card" — mandatory once the negation happened,
		# and it is an effect-driven change, so it does not spend the monster's own
		# once-per-turn manual position change.
		var to := SummonRules.opposite_face_up_position_of(ctx.source)
		ctx.state.set_battle_position(ctx.source, to, true, ctx.source.id)
		ctx.log_note("changed its own battle position")
		# "…THEN YOU CAN Special Summon" — a second, separate "you can", decided at
		# RESOLUTION once the negation and the position change have actually happened.
		# It is asked even when no copy is available to Summon, because declining and
		# having nothing to Summon are different outcomes and only the first is a choice;
		# the question is skipped when there is nothing to choose between.
		if EffectPrimitives.own_cards_in_zones(ctx, SUMMON_ZONES,
				EffectPrimitives.monster_named(SUMMONS)).is_empty():
			ctx.log_note("no \"%s\" in the hand, Deck or GY" % SUMMONS)
			return
		if not EffectPrimitives.may(ctx,
				"Special Summon 1 \"%s\" from your hand, Deck, or GY?" % SUMMONS):
			ctx.log_note("declined the Special Summon")
			return
		_summon_blue_eyes(ctx, "Special Summon 1 \"%s\" from your hand, Deck, or GY"
			% SUMMONS)

	return e
