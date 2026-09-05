extends RefCounted

## Kaiser Sea Horse — LIGHT / Sea Serpent / Level 4, 1700 ATK / 1650 DEF.
## One copy, deck 2 ("Fairy-Tail Tribute Guard").
##
## Official text (verified against the Konami card database, `Data/cards/cards.json`,
## cid 5409):
##
##   "This card can be treated as 2 Tributes for the Tribute Summon of a LIGHT monster."
##
## **One clause, and it is a rules QUERY rather than an effect that does anything.**
## `Research/CARD_RULINGS.md` **R8**.
##
## It declares a CONTINUOUS `EffectDef` carrying `SummonRules.TRIBUTE_VALUE_EFFECT_ID`, whose
## `condition` is a pure function called with `ctx.params["summoning_card"]` set to the
## monster about to be Tribute Summoned. `SummonRules.tribute_value()` asks it; nothing here
## applies a modifier to the board, which is why the clause legitimately has no
## `apply_continuous` and is listed in `CardRegistry.RULES_QUERY_EFFECT_IDS`.
##
## Five things this card is careful about, each of which has a test:
##
##   1. **It is not worth 2 Tributes in general.** "For the Tribute Summon of a LIGHT
##      monster" is a condition on the SUMMONED monster, so the answer depends on what is
##      being Summoned and is recomputed for each question. Setting a flat numeric
##      `tribute_value = 2` on the card would be wrong for every non-LIGHT Summon.
##   2. **It says "CAN be treated as".** It never forces anything: Tributing it for a
##      1-Tribute LIGHT Summon is still legal, and `SummonRules.tributes_satisfy()` already
##      permits a card worth 2 to overshoot a requirement of 1.
##   3. **The Attribute question is about the monster being SUMMONED, not about this card.**
##      Kaiser Sea Horse happens to be LIGHT itself, which is exactly the coincidence that
##      would let a wrong implementation pass — so the tests Summon a non-LIGHT monster and
##      assert it is worth only 1.
##   4. **It is a Tribute SUMMON clause.** `tribute_value()` is consulted only on the Tribute
##      Summon path; a Tribute paid as a COST (`Kaibaman`, `Dragonic Tactics`) goes through
##      `EffectPrimitives.pay_tribute_cost()` and never asks this question. Both are asserted.
##   5. **A negated Kaiser Sea Horse is worth 1.** `tribute_value()` checks
##      `effects_are_negated()` before consulting any clause, and a face-down monster may
##      still be Tributed [S1 p.53] but applies no effects — so a face-down copy is worth 1
##      too.
##
## It is genuinely live in its own deck: `Metaphys Armed Dragon` (Level 7 LIGHT, two copies)
## and `Witchcrafter Golem Aruru` (Level 8 LIGHT) both need two Tributes, and Kaiser Sea
## Horse alone supplies them.

const CARD_NAME := "Kaiser Sea Horse"

const REQUIRED_ATTRIBUTE := "LIGHT"

const CLAUSE := "This card can be treated as 2 Tributes for the Tribute Summon of a " \
	+ "LIGHT monster."


func effects() -> Array:
	var e := EffectDef.new(SummonRules.TRIBUTE_VALUE_EFFECT_ID, CLAUSE)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.ruling("R8")

	# A PURE query. It reads only its argument, never the board, so it gives the same answer
	# whenever it is asked and can be asked as often as the rules layer likes.
	e.condition = func(ctx: EffectContext) -> bool:
		var summoning = ctx.params.get("summoning_card", null)
		if summoning == null:
			return false
		var card: CardInstance = summoning
		if card.definition == null or not card.is_monster():
			return false
		return card.definition.attribute == REQUIRED_ATTRIBUTE

	return [e]
