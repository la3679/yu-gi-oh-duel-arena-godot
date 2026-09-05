extends RefCounted

## Cards of Consonance — Normal Spell.
##
## Official text (verified against the Konami card database, cid 8656; see
## Data/generated/konami_cards.json):
##
##   "Discard 1 Dragon Tuner with 1000 or less ATK; draw 2 cards."
##
## The same shape as `Trade-In`, with a different qualification, and it shares no code with
## it beyond the batch-10 primitives — the two cards differ in exactly the predicate.
##
## Details this implementation accounts for:
##
##   1. **The discard is a COST.** The official supplement (cid 8656, 2020-08-29) says so
##      explicitly, and adds that the card **does not target**. So the qualification lives
##      in the cost's candidate list and nowhere else — there is no `legal_targets`.
##      RULES_SPEC.md 10, [S1 p.53] "Pay a Cost".
##   2. **It cannot be activated when the Deck holds 1 or fewer cards** — the same
##      supplement, in as many words. R40 part D; `EffectPrimitives.can_draw()`.
##   3. **Three separate qualifications, all required:** Dragon, Tuner, and 1000 or less
##      ATK. `EffectPrimitives.tuner_monster("Dragon", 1000)` is all three, and reads the
##      **printed** ATK, because a card in the hand carries no continuous modifiers
##      (master prompt 35).
##   4. **A DISCARD, not a send** — `MoveReason.DISCARDED` [S1 p.52-53].
##   5. **This is the card that pays `The White Stone of Legend`.** White Stone is a Level 1
##      LIGHT Dragon **Tuner** with 300 ATK, so it qualifies, and discarding it as a cost
##      fires its "If this card is sent to the GY" trigger. That interaction is the reason
##      both cards are in deck 1 and it is tested directly, in both suites. It is also what
##      exposed the engine defect fixed in unit A: cost-payment events never reached the
##      trigger check.
##   6. In deck 1 the live payments are `Flamvell Guard` (100 ATK), `Rider of the Storm
##      Winds` (500 ATK) and `The White Stone of Legend` (300 ATK). `Maiden with Eyes of
##      Blue` is a Tuner with 0 ATK but is a **Spellcaster**, so it does not qualify — the
##      negative case the suite asserts, because a filter that forgot the race would
##      otherwise pass every test.
##   7. **No once-per-turn is printed and none was added.**

const CARD_NAME := "Cards of Consonance"

const CLAUSE := "Discard 1 Dragon Tuner with 1000 or less ATK; draw 2 cards."

const DRAW_COUNT := 2
const REQUIRED_RACE := "Dragon"
const MAX_ATK := 1000


func effects() -> Array:
	var e := EffectDef.new("discard_dragon_tuner_draw_2", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]

	var dragon_tuner := EffectPrimitives.tuner_monster(REQUIRED_RACE, MAX_ATK)

	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_draw(ctx, ctx.controller_id, DRAW_COUNT)

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.qualified_hand_cards(ctx, dragon_tuner).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.qualified_hand_cards(ctx, dragon_tuner)
		var paid := EffectPrimitives.pay_discard_cost(ctx, candidates, 1,
			"Discard 1 Dragon Tuner with 1000 or less ATK")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "discarded", paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var drawn := EffectPrimitives.draw_cards(ctx, ctx.controller_id, DRAW_COUNT)
		ctx.log_note("drew %d card(s)" % drawn.size())

	return [e]
