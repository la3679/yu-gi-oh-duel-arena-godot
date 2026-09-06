extends RefCounted

## Spiritual Water Art - Aoi — Normal Trap.
##
## Official text (verified against the Konami card database, cid 6440; see
## Data/cards/cards.json):
##
##   "Tribute 1 WATER monster; look at your opponent's hand, then send 1 card from their
##    hand to the GY."
##
## One printed clause, one EffectDef. The second of the pool's three Spiritual Art cards to
## be implemented in batch 12 and the closest sibling of `Spiritual Fire Art - Kurenai`:
## the cost is the same mechanism with a different Attribute, and everything after the
## semicolon is different.
##
## Research/CARD_RULINGS.md **R42 Part B** is the official supplemental information
## (cid 6440, dated 2020-07-04, fetched with `request_locale=ja` per R40's methodology
## note) plus what the general rules have to carry where that page is silent. Which is
## which is marked, because it is the difference between a ruling and a reasoned decision.
##
##   1. **The Tribute is a COST** (official). Paid at ACTIVATION, in `pay_cost`. Not
##      refunded when the activation or the effect is negated; both are asserted.
##   2. **A face-DOWN WATER monster is a legal Tribute** (official): 表示形式を問わず.
##   3. **It cannot be activated in the Damage Step** (official):
##      ダメージステップ中には発動できません — `DamageStepPermission.NONE`.
##   4. **The Attribute is read on the FIELD**, so `field_monster_of_attribute()` and not
##      `monster_filter()`. Identical reasoning to `Kurenai` detail 9: a Trap Monster's
##      Attribute lives in its runtime identity and its printed `CardDef` has none.
##   5. **"Look at" is a reveal to ONE player** (general rules, R42 Part B). [S1 p.50]
##      makes a hand private and RULES_SPEC §12.1 already models legal knowledge as
##      `CardInstance.revealed_to`. `EffectPrimitives.look_at_hand()` is that operation:
##      nothing is turned face-up, nothing moves, and the opponent learns nothing. The
##      knowledge then **survives**, because §12.1 ends `revealed_to` only at a shuffle
##      and a hand is never shuffled — which is also what the physical game gives you.
##   6. **The activating player chooses which card is sent** (reasoned, MEDIUM-HIGH). Every
##      verb in the sentence has "you" as its subject, and the contrast is `A Hero Emerges`
##      (R15), whose text says "at random" precisely because that is the exception. The
##      choice goes through `choose_one()`, so it is a logged duel input and the duel stays
##      replayable.
##   7. **The send is an EFFECT and is NOT a discard.** "Discard" is a player's own hand
##      [S1 p.52-53]; this is your opponent's card leaving their hand because of your card.
##      `send_from_hand_to_gy()` uses `MoveReason.SENT_TO_GY_BY_EFFECT`, so a future card
##      that triggers on a DISCARD must not see it. R40 made that separation load-bearing.
##   8. **It does not target.** The word never appears, and it could not: the candidates are
##      in a hidden zone, so the choice is necessarily made at RESOLUTION.
##   9. **An EMPTY opponent hand does not stop the activation** (reasoned, MEDIUM-HIGH).
##      The supplement is silent. Nothing in the card is phrased as an activation
##      requirement — contrast `Damage Condenser`, whose supplement states its Deck
##      requirement explicitly precisely because such a restriction is not the default. So
##      the card is activated, the cost is paid, the hand is looked at (and is empty), and
##      nothing is sent. That vacuous path is **asserted in both directions** rather than
##      guarded away, so it can never be mistaken for a passing test.
##  10. **The hand is re-read at RESOLUTION.** The look and the send both happen then, so a
##      hand emptied between activation and resolution sends nothing, and a hand refilled
##      in that window is looked at in full. Nothing is carried forward from activation
##      because nothing was chosen there.
##
## Live in the V1 pool: this card is in `Fairy-Tail Tribute Guard`, whose WATER monsters are
## `Crystal Seer` (100 ATK) and `Eria the Water Charmer` (500 ATK). The suite asserts the
## cost against a real printed one and not only against fixtures.

const CARD_NAME := "Spiritual Water Art - Aoi"

const CLAUSE := "Tribute 1 WATER monster; look at your opponent's hand, then send 1 card " \
	+ "from their hand to the GY."

const WATER := "WATER"


func effects() -> Array:
	var e := EffectDef.new("tribute_water_look_at_hand_send_one", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]; `of_type()` cannot derive it.
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.ruling("R42")

	# Attribute only, and deliberately no face-up filter: detail 2. On the FIELD, so the
	# runtime reader rather than the printed one: detail 4.
	var water_monster := EffectPrimitives.field_monster_of_attribute(WATER)

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_pay_tribute_cost(ctx,
			EffectPrimitives.tribute_cost_candidates(ctx, water_monster, true), 1)

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.tribute_cost_candidates(ctx, water_monster, true)
		var paid := EffectPrimitives.pay_tribute_cost(ctx, candidates, 1,
			"Tribute 1 WATER monster (cost)")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		# Sentence one. Read at RESOLUTION (detail 10), and to this player only (detail 5).
		var seen := EffectPrimitives.look_at_hand(ctx, ctx.opponent_id())
		if seen.is_empty():
			# Detail 9: a legal, fully-resolved, entirely vacuous outcome. Logged so it is
			# distinguishable from an effect that did not resolve at all.
			ctx.log_note("looked at the opponent's hand and found it empty; nothing sent")
			return
		# Sentence two. The looking player chooses (detail 6), through the logged channel.
		var chosen := EffectPrimitives.choose_one(ctx, seen,
			"Send 1 card from your opponent's hand to the GY")
		if chosen == null:
			ctx.log_note("no card could be chosen to send")
			return
		# A send, never a discard (detail 7).
		if EffectPrimitives.send_from_hand_to_gy(ctx, chosen):
			ctx.log_note("looked at %d card(s) and sent %s to the Graveyard"
				% [seen.size(), chosen.card_name()])

	return [e]
