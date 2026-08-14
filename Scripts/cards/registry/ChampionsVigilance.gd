extends RefCounted

## Champion's Vigilance — Counter Trap.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "If you control a Level 7 or higher Normal Monster, when a monster(s) would be
##    Summoned OR a Spell/Trap Card is activated: Negate the Summon or activation, and if
##    you do, destroy that card."
##
## One printed clause with TWO disjoint activation timings and two different resolutions,
## so it is two EffectDefs. That split is deliberate and must not be collapsed:
##
##   * **Negating a Summon** answers something that is not on the Chain at all. The monster
##     has been DECLARED and is waiting for its window to close; the negation goes through
##     `DuelEngine.negate_pending_summon()` and the monster never reaches a Monster Zone,
##     so no successful-summon event is emitted and no successful-summon Trigger Effect is
##     ever collected. PROJECT_STATE.md design decision 4. For a Normal or Special Summon
##     the monster waits in `Zone.IN_TRANSIT`; for a **Flip Summon** it waits face-down in
##     the Monster Zone it already occupies, and negating it leaves it face-down.
##   * **Negating a Spell/Trap activation** answers a real Chain Link, through
##     `ChainManager.negate_activation()`.
##
## An activated effect that WOULD Special Summon is the SECOND case, never the first: at the
## moment the negation is activated that effect has not resolved and no Summon has been
## declared. Merging the two paths would either invent a Summon that has not happened or
## lose Summon negation entirely. PROJECT_STATE.md design decision 9.
##
## Details that are easy to get wrong:
##
##   1. **"a Spell/Trap CARD is activated"** is narrower than "an effect is activated". A
##      monster's Ignition or Quick Effect is not a Spell/Trap card activation and this card
##      cannot answer it, which is what `EffectPrimitives.spell_trap_activation_below()`
##      enforces by checking the link's effect type and its source card.
##   2. **"negate the ACTIVATION"**, not the effect. The card is treated as not having been
##      successfully activated. What that does NOT undo is the COST — costs are paid at
##      activation and are never refunded (RULES_SPEC.md 10).
##   3. **"If you control a Level 7 or higher Normal Monster"** is a PSCT activation
##      CONDITION, checked when the card is activated. It requires a face-up monster: a
##      face-down monster's Level and its being a Normal Monster are not properties either
##      player may act on — the same reading `controls_face_up_monster_of_race()` uses.
##   4. **"monster(s)"** — the plural is in the current text because a single Summon can
##      place several monsters at once. Nothing in the V1 pool Summons more than one monster
##      in a single Summon, so there is one pending Summon record to negate and negating it
##      negates the whole Summon. Research/CARD_RULINGS.md R24.
##   5. **Spell Speed 3.** Only another Spell Speed 3 effect may respond to it [S1 p.45];
##      `ChainManager.can_respond_with_spell_speed()` already enforces that generically.
##
## CLOSED GAP (batch 6): a **Flip Summon** used to be applied immediately, with no
## declaration window, so this card could not answer one even though a Flip Summon is a
## Summon [S1 p.24]. `SummonRules` now has the same begin/complete split for it as for the
## other two routes, and `ChampionsVigilanceTests :: it negates a Flip Summon` proves the
## negation end to end: the monster stays FACE-DOWN, is destroyed face-down, and no
## `FLIP_SUMMON_SUCCEEDED` event and no Flip effect ever occur.

const CARD_NAME := "Champion's Vigilance"

const REQUIRED_LEVEL := 7

const CLAUSE_SUMMON := "If you control a Level 7 or higher Normal Monster, when a " \
	+ "monster(s) would be Summoned: Negate the Summon, and if you do, destroy that card."
const CLAUSE_ACTIVATION := "If you control a Level 7 or higher Normal Monster, when a " \
	+ "Spell/Trap Card is activated: Negate the activation, and if you do, destroy that card."


func effects() -> Array:
	## "If you control a Level 7 or higher Normal Monster" — a face-up one. See note 3.
	var field_condition := func(ctx: EffectContext) -> bool:
		for entry in ctx.me().face_up_monsters():
			var card: CardInstance = entry
			if card.definition == null:
				continue
			if not card.is_normal_monster():
				continue
			if card.current_level() >= REQUIRED_LEVEL:
				return true
		return false

	return [_negate_summon(field_condition), _negate_activation(field_condition)]


## Common activation shape: a Set Counter Trap, Spell Speed 3.
func _as_counter_trap(e: EffectDef) -> EffectDef:
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS3)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	# A Counter Trap is one of the two things RULES_SPEC.md 7.2 [S1 p.41] permits inside the
	# Damage Step, up to the start of damage calculation.
	e.damage_step(Enums.DamageStepPermission.UNTIL_DAMAGE_CALC)
	e.ruling("R24")
	return e


# ---------------------------------------------------------------------------
# "when a monster(s) would be Summoned"
# ---------------------------------------------------------------------------

func _negate_summon(field_condition: Callable) -> EffectDef:
	var e := _as_counter_trap(EffectDef.new("negate_summon", CLAUSE_SUMMON))
	# All THREE Summon routes. Each one opens a real declaration window. A Normal Set is not
	# a Summon [S1 p.24], emits no declaration, and is correctly absent.
	e.trigger_events = [
		GameEvent.Kind.NORMAL_SUMMON_DECLARED,
		GameEvent.Kind.SPECIAL_SUMMON_DECLARED,
		GameEvent.Kind.FLIP_SUMMON_DECLARED,
	]

	e.condition = func(ctx: EffectContext) -> bool:
		if not bool(field_condition.call(ctx)):
			return false
		# "WOULD BE Summoned" — a Summon that has been declared and has not completed.
		return EffectPrimitives.summon_is_pending(ctx) != null

	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.negate_summon_and_destroy(ctx)

	return e


# ---------------------------------------------------------------------------
# "OR a Spell/Trap Card is activated"
# ---------------------------------------------------------------------------

func _negate_activation(field_condition: Callable) -> EffectDef:
	var e := _as_counter_trap(EffectDef.new("negate_spell_trap_activation",
		CLAUSE_ACTIVATION))
	e.trigger_events = [GameEvent.Kind.EFFECT_ACTIVATED]

	e.condition = func(ctx: EffectContext) -> bool:
		if not bool(field_condition.call(ctx)):
			return false
		# The link this card would be answering is the current top of the Chain, because
		# this card is not on the Chain yet while its legality is being tested.
		return EffectPrimitives.spell_trap_activation_below(ctx) != null

	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.negate_activation_and_destroy(ctx)

	return e
