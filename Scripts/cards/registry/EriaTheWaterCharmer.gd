extends RefCounted

## Eria the Water Charmer — Level 3 WATER Spellcaster Flip Effect Monster, 500 / 1500.
##
## Official text (verified against the Konami card database, cid 6336; see
## Data/generated/konami_cards.json):
##
##   "FLIP: Target 1 WATER monster your opponent controls; take control of that monster
##    while this card is face-up on the field."
##
## **The saved text this project started from was wrong for this card specifically.** The
## older wording said "1 face-up WATER monster"; the current official text has no "face-up"
## and does say "Target". Research/CARD_RULINGS.md §2.1 records the discrepancy; the official
## text wins and is what is implemented here.
##
## That does NOT make the effect able to steal a face-down monster. A face-down monster's
## Attribute is not a property either player may act on, so "1 WATER monster your opponent
## controls" cannot select one — the restriction now comes from the Attribute requirement
## rather than from the printed word "face-up", and `EffectPrimitives.opponent_monsters()`
## is where that single reading lives for all three Charmers. The consequence is only that
## the wording no longer says it twice.
##
## Everything else is identical to `Aussa the Earth Charmer`, whose file carries the full
## design notes. The mechanics are shared through
## `EffectPrimitives.charmer_take_control()`; this card has its own suite.

const CARD_NAME := "Eria the Water Charmer"

const ATTRIBUTE := "WATER"

const CLAUSE := "FLIP: Target 1 WATER monster your opponent controls; take control of " \
	+ "that monster while this card is face-up on the field."


func effects() -> Array:
	return [EffectPrimitives.charmer_take_control(ATTRIBUTE, CLAUSE)]
