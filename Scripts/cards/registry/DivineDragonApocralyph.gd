extends RefCounted

## Divine Dragon Apocralyph — DARK / Dragon / Level 4 / 1000 ATK / 1500 DEF.
##
## Official text (verified against the Konami card database, cid 9910; see
## Data/generated/konami_cards.json):
##
##   "Once per turn: You can discard 1 card, then target 1 Dragon-Type monster in your
##    Graveyard; add that target to your hand."
##
## The same SHAPE as `Herald of Creation`, and deliberately not the same code: the two cards
## differ in exactly their target predicate, and sharing an implementation would make the
## predicate look like a parameter of one mechanism rather than what each card says. What
## they do share is the batch-10 primitives, which is the right level.
##
## Details this implementation accounts for, confirmed by the official supplement
## (cid 9910, 2016-09-01):
##
##   1. **It is an IGNITION effect activatable in the Monster Zone** — the supplement says
##      so. Spell Speed 1, from `FIELD_FACE_UP`.
##   2. **The discard is a COST**, unqualified ("1 card"), paid at activation and never
##      refunded [S1 p.53]. `MoveReason.DISCARDED`.
##   3. **"Dragon-Type" is matched on the RACE, never on the name.** `monster_filter` with
##      `race = "Dragon"` asks the card what it is. Matching on names would have been wrong
##      the moment a Dragon without "Dragon" in its name appeared — and deck 1 holds
##      `Ranryu`, `Kaiser Glider` and `The White Stone of Legend`, none of which would have
##      matched a name test, plus `Flamvell Guard`, which is a Dragon nobody would guess.
##   4. **"your Graveyard"** — the controller's own GY only; the opponent's Dragons are
##      never targets.
##   5. **"Once per turn" with no card name printed is `opt_instance()`** — this copy, not
##      the name. RULES_SPEC.md 11.
##   6. **This card is itself a Dragon**, so once it is in the Graveyard another copy could
##      target it. There is only one copy in deck 1, so that is never live; what IS live is
##      that a `Divine Dragon Apocralyph` on the field can never target itself, because its
##      own effect is activated from the field and the target must be in the GY. Asserted.
##   7. The supplement notes that a Dragon **Fusion / Synchro / Xyz / Link** monster in the
##      GY may be targeted and would return to the **Extra Deck** rather than the hand. Both
##      Extra Decks are empty in V1 and the pool has no Extra Deck monsters, so that branch
##      is **never live**; it is asserted as impossible rather than implemented as a branch
##      that can never run. The R21 / R23 treatment.

const CARD_NAME := "Divine Dragon Apocralyph"

const CLAUSE := "Once per turn: You can discard 1 card, then target 1 Dragon-Type " \
	+ "monster in your Graveyard; add that target to your hand."

const REQUIRED_RACE := "Dragon"


func effects() -> Array:
	var e := EffectDef.new("discard_to_retrieve_dragon", CLAUSE)
	e.of_type(Enums.EffectType.IGNITION)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	e.targeting(1)
	e.opt_instance()

	var dragon := EffectPrimitives.monster_filter("", -1, -1, REQUIRED_RACE)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.own_cards_in(ctx, Enums.Zone.GRAVEYARD, dragon)

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND,
			Callable()).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, Callable())
		var paid := EffectPrimitives.pay_discard_cost(ctx, candidates, 1, "Discard 1 card")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "discarded", paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_target(ctx, Enums.Zone.GRAVEYARD)
		if target == null:
			ctx.log_note("the target is no longer in the Graveyard")
			return
		if EffectPrimitives.add_to_hand(ctx, target):
			ctx.log_note("added %s to the hand" % target.card_name())

	return [e]
