extends RefCounted

## Spiritual Fire Art - Kurenai — Normal Trap.
##
## Official text (verified against the Konami card database, cid 6441; see
## Data/cards/cards.json):
##
##   "Tribute 1 FIRE monster; inflict damage to your opponent equal to that monster's
##    original ATK."
##
## One printed clause, one EffectDef. It is the third of the pool's Spiritual Art cards and
## the sibling of `Spiritual Wind Art - Miyabi`, which it copies for the cost and departs
## from for everything after the semicolon: Miyabi targets and moves a card, this one
## targets nothing and inflicts damage.
##
## Research/CARD_RULINGS.md **R42 Part A** is the official supplemental information
## (cid 6441, dated 2020-07-04, fetched with `request_locale=ja` per R40's methodology
## note). Every fact below that it settles is marked.
##
##   1. **The Tribute is a COST.** R42 Part A: 「このカードを発動する際にコストとして…
##      リリースします」 — paid at ACTIVATION, in `pay_cost`, never in `resolve`. The
##      semicolon in the English text says the same thing [S1 p.52]. It is therefore **not
##      refunded** when the activation or the effect is negated, and both are asserted.
##   2. **A face-DOWN FIRE monster is a legal Tribute.** R42 Part A: 表示形式を問わず,
##      "regardless of display position". You know your own Set monster's Attribute, and
##      the cost asks no one else to read it — the same reasoning `Miyabi` already ships.
##   3. **The damage is the ATK PRINTED ON THE CARD.** R42 Part A:
##      「カードに記載されている攻撃力」. This is the one trap in the card:
##      `CardInstance.current_atk()` would be wrong, and batch 11's `Back-Up Rider` proves
##      the two really do differ — a monster boosted +1500 and then Tributed here deals its
##      PRINTED ATK, not the boosted figure. Asserted in both directions.
##   4. **The ATK is measured on the monster you RELEASED, so it is read AT COST TIME.**
##      `GameState.move_card()` calls `CardInstance.clear_monster_identity()` on every
##      departure from the field (R33), so a Trap Monster Tributed as this cost would have
##      no ATK left to read by the time the link resolves. Reading `original_atk()` during
##      `pay_cost` — while the monster is still the monster the text names — is the only
##      reading that answers correctly for every card, and it is what the Japanese
##      "リリースしたモンスターの" ("of the monster you released") says. The value rides
##      the existing `ctx.cost_payload`, the channel R31 and `cost_card_count()` already
##      use; no new mechanism.
##   5. **0 printed ATK is legal and inflicts 0 damage.** The text says "equal to", not
##      "if any", and nothing forbids a 0-ATK Tribute. `Flamvell Guard` is 100 and the
##      pool has no printed 0, so the branch is covered against a synthetic monster — but
##      it is covered, rather than papered over with a guard that would silently make the
##      whole clause a no-op.
##   6. **It does not target.** The word "target" does not appear; there is nothing on the
##      board for it to choose. `targets` stays false.
##   7. **It cannot be activated in the Damage Step.** R42 Part A:
##      ダメージステップには発動できません. That is `DamageStepPermission.NONE`, which is
##      the default — asserted rather than assumed, because `Damage Condenser` in this same
##      batch is the opposite and the contrast must not quietly collapse.
##   8. **The damage can end the Duel.** `check_life_point_loss()` follows it, which is the
##      shape `Chain Detonation`, `Five Brothers Explosion`, `Judge of the Ice Barrier` and
##      `Stamping Destruction` all already use. Measured honestly by mutation K8: this call
##      is **redundant** for this card, because `DuelEngine._resolve_current_chain()` calls
##      `check_life_point_loss()` after every Chain resolution and this damage is always
##      dealt inside one. It is kept for consistency with the four cards above rather than
##      because it is what ends the Duel — the engine is. The Duel-ending path is asserted
##      either way, and the redundancy is recorded in Reports/TEST_RESULTS.md rather than
##      left as an unexplained surviving mutation.
##
##   9. **The Attribute is read with `current_attribute()`, not from the printed CardDef.**
##      The Tribute candidates are on the FIELD, where a Trap Monster carries its Attribute
##      in its runtime identity and its printed `CardDef` carries none — `monster_filter()`
##      would answer "" for it and refuse a legal Tribute. `field_monster_of_attribute()`
##      names that choice; the three Charmers already read the field the same way.
##      RULES_SPEC.md 5.8, CARD_RULINGS.md R33. This is also why detail 4 matters: a Trap
##      Monster Tributed here has a granted ATK that only exists while it is on the field.
##
## Live in the V1 pool: this card is in `Fairy-Tail Tribute Guard`, whose one FIRE monster
## is `Inari Fire` (1500 printed ATK). The clause has a real Tribute and a real number, and
## the suite asserts it against that printed card and not only against fixtures.

const CARD_NAME := "Spiritual Fire Art - Kurenai"

const CLAUSE := "Tribute 1 FIRE monster; inflict damage to your opponent equal to that " \
	+ "monster's original ATK."

const FIRE := "FIRE"

## Key under which the cost records the PRINTED ATK of the monster it Tributed. Read at
## resolution, never recomputed: detail 4.
const TRIBUTED_ORIGINAL_ATK_KEY := "kurenai_tributed_original_atk"


func effects() -> Array:
	var e := EffectDef.new("tribute_fire_burn_its_original_atk", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]; `of_type()` cannot derive it.
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.ruling("R42")

	# Attribute only. No ATK, Level or Race condition, and deliberately no face-up filter:
	# detail 2. `field_monster_of_attribute()` rather than `monster_filter()` because the
	# candidates are on the FIELD — detail 9.
	var fire_monster := EffectPrimitives.field_monster_of_attribute(FIRE)

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_pay_tribute_cost(ctx,
			EffectPrimitives.tribute_cost_candidates(ctx, fire_monster, true), 1)

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.tribute_cost_candidates(ctx, fire_monster, true)
		# Detail 4: snapshot every candidate's ATK BEFORE the payment. `pay_tribute_cost()`
		# chooses and moves in one call, and the move is what clears a Trap Monster's
		# runtime identity — so by the time it returns the answer is already gone. Reading
		# the whole candidate list is what makes the snapshot independent of which one the
		# player picks.
		var atk_before_payment: Dictionary = {}
		for entry in candidates:
			var candidate: CardInstance = entry
			atk_before_payment[candidate.id] = candidate.original_atk()

		var paid := EffectPrimitives.pay_tribute_cost(ctx, candidates, 1,
			"Tribute 1 FIRE monster (cost)")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		# The fallback is correct for every ordinary monster — `original_atk()` reads the
		# printed CardDef and keeps answering in the Graveyard. It is only a Trap Monster,
		# whose ATK exists solely in the identity the departure cleared, that needs the
		# snapshot. Carried across on the existing cost channel; no new mechanism.
		var tributed: CardInstance = paid[0]
		ctx.cost_payload[TRIBUTED_ORIGINAL_ATK_KEY] = int(
			atk_before_payment.get(tributed.id, tributed.original_atk()))
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		# Never recomputed from the board: the Tributed card is in the Graveyard and, if it
		# was a Trap Monster, no longer carries the stats the clause asked about.
		var amount := int(ctx.cost_payload.get(TRIBUTED_ORIGINAL_ATK_KEY, 0))
		if amount > 0:
			ctx.state.change_life_points(ctx.opponent_id(), -amount, CARD_NAME,
				ctx.source.id)
			# Redundant with the engine's own post-Chain check (detail 8); kept for
			# consistency with the pool's four other damage-dealing cards.
			ctx.state.check_life_point_loss()
		# Logged either way, including the 0 case (detail 5), so a vacuous resolution is
		# visible in the duel log rather than indistinguishable from a normal one.
		ctx.log_note("inflicted %d damage (the Tributed monster's original ATK)" % amount)

	return [e]
