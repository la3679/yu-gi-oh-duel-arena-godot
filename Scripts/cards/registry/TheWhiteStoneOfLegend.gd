extends RefCounted

## The White Stone of Legend — LIGHT / Dragon / Tuner / Level 1 / 300 ATK / 250 DEF.
##
## Official text (verified against the Konami card database, cid 7850; see
## Data/generated/konami_cards.json):
##
##   "If this card is sent to the GY: Add 1 'Blue-Eyes White Dragon' from your Deck to your
##    hand."
##
## This card is the reason R40 exists, and the official supplement (cid 7850, dated
## 2024-03-23) settles all of it. It says three things, each of which is implemented and
## asserted directly:
##
##   1. **It is a Trigger Effect that activates IN THE GRAVEYARD.** By the time it activates
##      the card is already there, so `ActivationLocation.GRAVEYARD` is the whole of it.
##   2. **It MUST activate whenever its condition is met** — no "You can" is printed, so it
##      is `mandatory()` and is never offered as a consent question.
##   3. **It activates even when there is no 'Blue-Eyes White Dragon' in the Deck**, in
##      which case it resolves and adds nothing. **This is the load-bearing one**, and it is
##      the opposite of what the general rules alone would say: [S1 p.53] states that you
##      cannot activate an effect TO SEARCH your Deck when nothing qualifies, and reading
##      that as covering this card would have been silently wrong. Card-specific official
##      guidance outranks the general sentence. `EffectPrimitives.can_search_deck()` is
##      deliberately NOT consulted here, and the suite asserts the empty-Deck activation
##      directly so nobody "fixes" it later.
##   4. The same supplement adds that it activates even when the condition is met **during
##      the Damage Step** — so it declares `DamageStepPermission.MANDATORY_TRIGGER`, which
##      is the rules-mandated TIMING and not a statement about optionality.
##
## Further details:
##
##   5. **"sent to the GY" is every route, not just destruction.** The condition names no
##      cause, so it fires when the card is Tributed, discarded, sent as a cost, destroyed
##      by battle or destroyed by an effect. `GameEvent.Kind.CARD_SENT_TO_GY` is exactly
##      that event and the engine already emits it for each of those reasons — and NOT for a
##      banished card later moved to the GY [S1 p.53], which is correct and is asserted.
##   6. **Sent from ANYWHERE**, not only from the field: the text says "if this card is sent
##      to the GY", with no origin. Being DISCARDED from the hand by `Cards of Consonance`
##      is the deck's real line, and it is the interaction that exposed the engine defect
##      unit A fixed — cost-payment events never reached the trigger check, so before batch
##      10 this trigger could not have fired off a cost at all.
##   7. **The search is an "add to hand", so it reveals and it shuffles.** Both live in
##      `EffectPrimitives.search_deck_to_hand()`; this card supplies only the predicate.
##   8. **No once-per-turn is printed and none was added.** There is one copy in deck 1, so
##      the practical limit is the card itself.
##   9. It names one specific card, so it matches on the canonical NAME —
##      `EffectPrimitives.monster_named()` — never on text.

const CARD_NAME := "The White Stone of Legend"

const CLAUSE := "If this card is sent to the GY: Add 1 \"Blue-Eyes White Dragon\" from " \
	+ "your Deck to your hand."

const SEARCHES_FOR := "Blue-Eyes White Dragon"


func effects() -> Array:
	var e := EffectDef.new("gy_search_blue_eyes", CLAUSE)
	e.of_type(Enums.EffectType.TRIGGER)
	# No "You can" anywhere in the text, and cid 7850 says it must activate.
	e.mandatory()
	e.trigger_events = [GameEvent.Kind.CARD_SENT_TO_GY]
	e.activation_locations = [Enums.ActivationLocation.GRAVEYARD]
	# cid 7850: it activates even when the condition is met during the Damage Step.
	e.damage_step_permission = Enums.DamageStepPermission.MANDATORY_TRIGGER

	var blue_eyes := EffectPrimitives.monster_named(SEARCHES_FOR)

	# THIS card being sent to the GY, and nothing else. Deliberately NOT gated on whether
	# the Deck holds a Blue-Eyes White Dragon: cid 7850 says it activates regardless.
	e.condition = func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		return ev != null and int(ev.data.get("card_id", -1)) == ctx.source.id

	e.resolve = func(ctx: EffectContext) -> void:
		var found := EffectPrimitives.search_deck_to_hand(ctx, ctx.controller_id,
			blue_eyes, "Add 1 \"%s\" from your Deck to your hand" % SEARCHES_FOR)
		if found == null:
			# A legitimate resolution of nothing, and the supplement says so explicitly.
			ctx.log_note("no \"%s\" in the Deck to add" % SEARCHES_FOR)
			return
		ctx.log_note("added %s to the hand" % found.card_name())

	return [e]
