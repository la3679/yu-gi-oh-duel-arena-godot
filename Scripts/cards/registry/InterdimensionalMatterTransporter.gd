extends RefCounted

## Interdimensional Matter Transporter — Normal Trap.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Target 1 face-up monster you control; banish that target until the End Phase."
##
## One clause, and it is the card the whole temporary-banish subsystem was built for — the
## V1 pool's only card that states a return timing. The details that are easy to get wrong:
##
##   1. It **targets**, so the monster is locked in at ACTIVATION (RULES_SPEC.md 10) and
##      re-checked at resolution. Three words of the text are re-checked, not one: "face-up",
##      "monster", and "you control". `surviving_own_monster_target()` asks all three, for
##      the reason CARD_RULINGS.md R29 gives — a monster the opponent took control of in
##      response, or one flipped face-down in response, is no longer what was targeted.
##   2. "**you control**" — the opponent's monsters are not legal targets at all. This card
##      is protection, not removal.
##   3. A **face-down** monster is NOT a legal target: the text says "face-up".
##   4. Banishing is **not** a destruction and **not** a send to the Graveyard [S1 p.53], so
##      nothing keyed on either may fire — which is the entire point of the card, since it
##      rescues a monster from an effect that would destroy it.
##   5. The return is scheduled by **GameState**, not by this script. The card asks for a
##      `BanishDuration.UNTIL_END_PHASE` lease and is then finished; `banish_leases` knows
##      what is away and `expire_banish_leases()` brings it back. Putting the return in this
##      file would mean a replay could not reproduce it without re-running the card, and
##      would leave the card holding state the authoritative GameState should own.
##      RULES_SPEC.md 8.3.
##   6. The monster that comes back is **not Summoned** — no Summon of any kind, so no
##      successful-Summon trigger sees it and `Champion's Vigilance` has nothing to answer.
##      It returns in the battle position it left in, under its OWNER's control, and with its
##      Equip Cards, counters and modifiers gone, because it genuinely left the field.
##      All four are CARD_RULINGS.md R30 and are asserted both generically in `BanishTests`
##      and on this printed card.

const CARD_NAME := "Interdimensional Matter Transporter"

const CLAUSE := "Target 1 face-up monster you control; banish that target until the End Phase."


func effects() -> Array:
	var transport := EffectDef.new("banish_own_monster_until_end_phase", CLAUSE)
	transport.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]. `of_type()` derives Spell Speed from the
	# EFFECT category, which is Spell Speed 1 for everything but a Quick Effect, so the
	# CARD's Spell Speed has to be stated — without it this card could never be activated in
	# response to the removal effect it exists to dodge.
	transport.with_spell_speed(Enums.SpellSpeed.SS2)
	# A Normal Trap is activated from a Set position on the field, never from the hand.
	transport.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	transport.targeting(1)

	transport.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.own_monsters(ctx, true)

	transport.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_own_monster_target(ctx, true)
		var banished := EffectPrimitives.banish_target_temporarily(
			ctx, target, Enums.BanishDuration.UNTIL_END_PHASE)
		if banished != null:
			ctx.log_note("banished %s until the End Phase" % banished.card_name())

	return [transport]
