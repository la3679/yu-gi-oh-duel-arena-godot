extends RefCounted

## Chiron the Mage — EARTH / Beast-Warrior / Level 4 / 1800 ATK / 1000 DEF.
##
## Official text (verified against the Konami card database, cid 5810; see
## `Data/cards/cards.json`):
##
##   "Once per turn: You can discard 1 Spell, then target 1 Spell/Trap your opponent
##    controls; destroy that target."
##
## The official supplement (cid 5810, 2020-04-01) confirms all three of the structural
## decisions this implementation makes, and it is worth having checked rather than assumed
## because the OCG print says 選択して破壊 — *select* and destroy — where the current TCG print
## says *target*. `CARD_RULINGS.md` **R41 Part D**:
##
##   * 「賢者ケイローン」のモンスター効果は、フィールドで発動する起動効果です — it is an **IGNITION**
##     effect activated **on the field**, so Spell Speed 1 from `FIELD_FACE_UP`;
##   * 相手フィールドの魔法・罠カード１枚を対象に取る効果です — it really does **TARGET**, despite
##     the "select" wording, so the choice is locked in at activation and re-checked at
##     resolution;
##   * この効果の発動時にコストとして、手札の魔法カード１枚を捨てます — the discard is a **COST**,
##     paid at activation and never refunded, not even when the activation is negated
##     [S1 p.53].
##
## The same SHAPE as `Divine Dragon Apocralyph` — "once per turn: discard, then target" — and
## deliberately not the same code, for the reason that card's own note gives: the two differ in
## exactly their cost qualification and their target predicate, and sharing an implementation
## would make those look like parameters of one mechanism rather than what each card says.
## What they share is the batch-10 primitives, which is the right level.
##
## The details this implementation accounts for:
##
##   1. **The discard is QUALIFIED — "1 Spell", not "1 card"**, so it goes through batch 10's
##      `qualified_hand_cards()` with `spell_card()`. A hand of monsters and Traps cannot pay
##      it, and the effect is then not offered at all [master prompt 16].
##   2. **"1 Spell/Trap your opponent controls"** — the opponent's side only, and asked by the
##      ZONE (a Spell & Trap Zone or the Field Zone) rather than by `is_spell()/is_trap()`.
##      A Trap Monster in a Monster Zone is on their field and is printed as a Trap, but it is
##      not a Spell/Trap **on the field** in the sense this clause means. RULES_SPEC.md 5.8,
##      and the same distinction `Straight Flush`'s supplement draws. Reading the zone also
##      makes a face-down Set card legal without asking it anything it does not present.
##   3. **The Field Zone counts.** A Field Spell the opponent controls is a Spell they control.
##      That is live: deck 2 holds `Hidden Springs of the Far East`.
##   4. **"Once per turn" with no card name printed is `opt_instance()`** — this copy, not the
##      name. RULES_SPEC.md 11.
##   5. **Control is re-checked at resolution**, like every "your opponent controls" clause in
##      this pool. `CARD_RULINGS.md` R29; `Enemy Controller` and the three Charmers can all
##      move control in response.
##
## This card can never reach its own controller's Spell/Traps, and it is a monster, so it can
## never be its own target.

const CARD_NAME := "Chiron the Mage"

const CLAUSE := "Once per turn: You can discard 1 Spell, then target 1 Spell/Trap your " \
	+ "opponent controls; destroy that target."


## "1 Spell/Trap your opponent controls" — a card in one of their Spell & Trap Zones or their
## Field Zone. See note 2 above for why this asks the zone rather than the printed category.
static func _their_spell_trap(ctx: EffectContext, card: CardInstance) -> bool:
	if card == null or card.definition == null:
		return false
	if card.controller_id != ctx.opponent_id():
		return false
	return card.zone == Enums.Zone.SPELL_TRAP_ZONE or card.zone == Enums.Zone.FIELD_ZONE


func effects() -> Array:
	var e := EffectDef.new("discard_spell_to_destroy_spell_trap", CLAUSE)
	e.of_type(Enums.EffectType.IGNITION)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	e.targeting(1)
	e.opt_instance()
	e.ruling("R41")

	var spell := EffectPrimitives.spell_card()

	# Scanned over the WHOLE field and filtered by the one predicate, rather than over the
	# opponent's side with the predicate re-stating the scope. Every word of "1 Spell/Trap
	# your opponent controls" then lives in exactly one place, and the same predicate answers
	# at activation and at resolution — so a change to either half cannot drift out of step
	# with the other, and neither half can go untested because the other made it redundant.
	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		for entry in EffectPrimitives.cards_on_field(ctx):
			var card: CardInstance = entry
			if _their_spell_trap(ctx, card):
				out.append(card)
		return out

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.qualified_hand_cards(ctx, spell).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.qualified_hand_cards(ctx, spell)
		var paid := EffectPrimitives.pay_discard_cost(ctx, candidates, 1, "Discard 1 Spell")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "discarded", paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_opponent_field_target(ctx)
		if target == null or not _their_spell_trap(ctx, target):
			ctx.log_note("the target is no longer a Spell/Trap the opponent controls")
			return
		var target_name := target.card_name()
		if ctx.state.destroy(target, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id):
			ctx.log_note("destroyed %s" % target_name)
		else:
			ctx.log_note("%s could not be destroyed" % target_name)

	return [e]
