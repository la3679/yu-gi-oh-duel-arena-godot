extends RefCounted

## Monster Reborn — Normal Spell.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Target 1 monster in either GY; Special Summon it."
##
## One clause, and four details that are easy to get wrong:
##
##   1. It **targets**. PSCT reserves the word "target" for a choice locked in at
##      ACTIVATION, so the monster is chosen when the Chain Link is created and NOT at
##      resolution. RULES_SPEC.md 10.
##   2. "either GY" means the opponent's Graveyard too. The monster is Special Summoned
##      to YOUR side of the field, so you become its controller while its OWNER is
##      unchanged — it goes back to the opponent's Graveyard when it later leaves the
##      field. [S1 p.52]
##   3. No position is named, so the summoning player chooses face-up Attack or face-up
##      Defense Position. RULES_SPEC.md 5.5.
##   4. If the target has left the Graveyard by the time the link resolves, the effect
##      does nothing. It never chases the card into another zone. Master prompt 44.

const CARD_NAME := "Monster Reborn"

const CLAUSE := "Target 1 monster in either GY; Special Summon it."


func effects() -> Array:
	var revive := EffectDef.new("revive_target_in_either_gy", CLAUSE)
	revive.of_type(Enums.EffectType.CARD_ACTIVATION)
	# From the hand, or from a Set copy. A Normal Spell is never activated from a
	# face-up field position — being face-up on the field is what activating it does.
	revive.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	revive.targeting(1)

	var revivable := EffectPrimitives.revivable_monster()

	revive.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.cards_in_either_graveyard(ctx, revivable)

	# Nowhere to put the monster means no part of the effect can be performed, so the
	# card cannot be activated at all. Unlike Kaibaman, nothing here frees a zone.
	revive.condition = func(ctx: EffectContext) -> bool:
		return ctx.me().has_free_monster_zone()

	revive.resolve = func(ctx: EffectContext) -> void:
		var summoned := EffectPrimitives.special_summon_target(ctx, Enums.Zone.GRAVEYARD)
		if summoned != null:
			ctx.log_note("Special Summoned %s" % summoned.card_name())

	return [revive]
