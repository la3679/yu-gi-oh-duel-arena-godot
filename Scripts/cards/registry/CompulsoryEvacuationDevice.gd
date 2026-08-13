extends RefCounted

## Compulsory Evacuation Device — Normal Trap.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Target 1 monster on the field; return that target to the hand."
##
## The pool's plainest bounce, and the card the movement gate was built for. One clause,
## and five details that are easy to get wrong:
##
##   1. It **targets**, so the monster is locked in at ACTIVATION and re-checked at
##      resolution. A target that left the Monster Zone is dropped, never chased.
##      RULES_SPEC.md 10, design decision 16.
##   2. "1 monster **on the field**" is either side's field. Your own monster is a legal
##      target and the card is frequently used that way.
##   3. A **face-down** monster is a legal target too. The text names no property a
##      face-down monster lacks — contrast the three Charmers, which name an Attribute.
##   4. "Return to the hand" is **not** a destruction and **not** a send to the Graveyard
##      [S1 p.52], so nothing keyed on either may fire. `MoveReason.RETURNED_TO_HAND`.
##   5. The card goes to its **OWNER's** hand, even when the opponent had taken control of
##      it. `GameState.move_card()` forces this; the card must not pass a `to_player`.

const CARD_NAME := "Compulsory Evacuation Device"

const CLAUSE := "Target 1 monster on the field; return that target to the hand."


func effects() -> Array:
	var bounce := EffectDef.new("return_target_monster_to_hand", CLAUSE)
	bounce.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]. `of_type()` derives Spell Speed from the
	# EFFECT category, which is Spell Speed 1 for everything but a Quick Effect, so the
	# CARD's Spell Speed has to be stated. Without it the card would never be offered in a
	# response window and could not be used on the opponent's turn at all.
	bounce.with_spell_speed(Enums.SpellSpeed.SS2)
	# A Normal Trap is activated from a Set position on the field, never from the hand.
	bounce.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	bounce.targeting(1)

	bounce.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.cards_on_field(ctx, true)

	bounce.resolve = func(ctx: EffectContext) -> void:
		var returned := EffectPrimitives.return_target_to_hand(ctx, Enums.Zone.MONSTER_ZONE)
		if returned != null:
			ctx.log_note("returned %s to its owner's hand" % returned.card_name())

	return [bounce]
