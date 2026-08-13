extends RefCounted

## Silver's Cry — Quick-Play Spell.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Target 1 Dragon Normal Monster in your GY; Special Summon that target.
##    You can only activate 1 'Silver's Cry' per turn."
##
## Details this implementation accounts for:
##
##   1. Quick-Play, so **Spell Speed 2**: usable in a Fast Effect window. From the hand
##      it is your-turn-only; once Set it may be activated on either player's turn, but
##      never in the turn it was Set. Both are enforced by ActivationRules
##      (`card_activation_timing_ok` / `set_turn_ok`), which is why nothing here repeats
##      them. [S1 p.31]
##   2. "Dragon Normal Monster" is BOTH conditions: Dragon race AND a Normal Monster.
##      An Effect Monster that happens to be a Dragon is not a legal target.
##   3. "in your GY" — your own Graveyard only, unlike Monster Reborn.
##   4. It **targets**, so the monster is fixed at activation. RULES_SPEC.md 10.
##   5. "You can only activate 1 ... per turn" is a hard once-per-turn on the NAME,
##      per player: `once_per_turn_named_activation`. It is spent by the activation
##      itself, so a second copy cannot be activated even if the first is negated.
##      RULES_SPEC.md 11.
##   6. No position is named, so the summoning player chooses. RULES_SPEC.md 5.5.

const CARD_NAME := "Silver's Cry"

const CLAUSE := "Target 1 Dragon Normal Monster in your GY; Special Summon that " \
	+ "target. You can only activate 1 \"Silver's Cry\" per turn."


func effects() -> Array:
	var revive := EffectDef.new("revive_dragon_normal_monster", CLAUSE)
	revive.of_type(Enums.EffectType.CARD_ACTIVATION)
	revive.with_spell_speed(Enums.SpellSpeed.SS2)
	revive.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	revive.targeting(1)
	revive.opt_named_activation()

	var dragon_normal := EffectPrimitives.monster_filter("", -1, -1, "Dragon", true)

	revive.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.own_cards_in(ctx, Enums.Zone.GRAVEYARD, dragon_normal)

	revive.condition = func(ctx: EffectContext) -> bool:
		return ctx.me().has_free_monster_zone()

	revive.resolve = func(ctx: EffectContext) -> void:
		var summoned := EffectPrimitives.special_summon_target(ctx, Enums.Zone.GRAVEYARD)
		if summoned != null:
			ctx.log_note("Special Summoned %s" % summoned.card_name())

	return [revive]
