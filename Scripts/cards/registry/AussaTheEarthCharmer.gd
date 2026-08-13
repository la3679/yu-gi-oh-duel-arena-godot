extends RefCounted

## Aussa the Earth Charmer — Level 3 EARTH Spellcaster Flip Effect Monster, 500 / 1500.
##
## Official text (verified against the Konami card database, cid 6335; see
## Data/generated/konami_cards.json):
##
##   "FLIP: Target 1 EARTH monster your opponent controls; take control of that monster
##    while this card is face-up on the field."
##
## One printed clause, one EffectDef. Things this card pins down:
##
##   1. **It TARGETS.** The current wording says "Target", which the older printing did not.
##      Research/CARD_RULINGS.md §2.1 records the discrepancy and resolves it in favour of
##      the official text. Targeting means it interacts with `cannot_be_targeted`
##      (`Fairy Tail - Rella`) and that the target is fixed at activation and re-checked at
##      resolution.
##   2. **It is a FLIP effect, not a Flip-Summon effect.** It triggers whenever the card is
##      turned face-up — Flip Summoned, flipped by an attacking monster, or flipped by a card
##      effect. Keying it on `FLIP_SUMMON_SUCCEEDED` would silently lose two of the three.
##   3. **"while this card is face-up on the field"** is a DURATION on the control change,
##      not a condition on the target. Flip Aussa face-down or remove it from the field and
##      control returns immediately; nothing about the borrowed monster ends it.
##   4. **Control, never ownership.** The borrowed monster still goes to ITS OWNER's Graveyard
##      when it dies under the other player's control [S1 p.52]. `GameState.change_control()`
##      is the only channel, and it never touches `owner_id`. RULES_SPEC.md §5.6.
##   5. **It is MANDATORY.** There is no "you can". With no legal target it does not activate
##      at all, which is a different thing from being declined.
##
## The mechanics are shared with `Eria the Water Charmer` and `Wynn the Wind Charmer` through
## `EffectPrimitives.charmer_take_control()` because the three official texts are word for
## word identical apart from the Attribute. Each card still declares its own text and has its
## own suite.

const CARD_NAME := "Aussa the Earth Charmer"

const ATTRIBUTE := "EARTH"

const CLAUSE := "FLIP: Target 1 EARTH monster your opponent controls; take control of " \
	+ "that monster while this card is face-up on the field."


func effects() -> Array:
	return [EffectPrimitives.charmer_take_control(ATTRIBUTE, CLAUSE)]
