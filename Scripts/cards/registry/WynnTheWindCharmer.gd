extends RefCounted

## Wynn the Wind Charmer — Level 3 WIND Spellcaster Flip Effect Monster, 500 / 1500.
##
## Official text (verified against the Konami card database, cid 6338; see
## Data/generated/konami_cards.json):
##
##   "FLIP: Target 1 WIND monster your opponent controls; take control of that monster
##    while this card is face-up on the field."
##
## Word for word `Aussa the Earth Charmer` with WIND in place of EARTH, so the mechanics are
## shared through `EffectPrimitives.charmer_take_control()`. `AussaTheEarthCharmer.gd` carries
## the full design notes; this card has its own suite.
##
## Like Aussa, the current official wording **targets** where the older printing did not —
## Research/CARD_RULINGS.md §2.1.

const CARD_NAME := "Wynn the Wind Charmer"

const ATTRIBUTE := "WIND"

const CLAUSE := "FLIP: Target 1 WIND monster your opponent controls; take control of " \
	+ "that monster while this card is face-up on the field."


func effects() -> Array:
	return [EffectPrimitives.charmer_take_control(ATTRIBUTE, CLAUSE)]
