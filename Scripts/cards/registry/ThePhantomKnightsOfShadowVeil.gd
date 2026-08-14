extends RefCounted

## The Phantom Knights of Shadow Veil — Normal Trap, Spell Speed 2.
##
## Official text (verified against the Konami card database, cid 11404):
##
##   "Target 1 face-up monster you control; it gains 300 ATK/DEF. When an opponent's monster
##    declares a direct attack while this card is in your GY: Special Summon this card in
##    Defense Position as a Normal Monster (Warrior/DARK/Level 4/ATK 0/DEF 300). (This card
##    is NOT treated as a Trap.) If Summoned this way, banish this card when it leaves the
##    field."
##
## **THREE clauses, and the banish is only one of them — all three are implemented.**
##
## Details this implementation accounts for:
##
##   1. **Clause 1 gains ATK *and* DEF, with NO printed duration.** That absence is the
##      specification: it is not "until the end of this turn", so
##      `gain_atk_until_end_of_turn()` is the wrong primitive, and it is not tied to the
##      source either — a Normal Trap is in the Graveyard moments later, which would delete
##      the gain almost immediately. `gain_atk_and_def_permanently()` puts the modifier on the
##      TARGET, where `on_leave_field()` clears it when that monster leaves or is flipped
##      face-down. RULES_SPEC.md 8.
##   2. **Clause 2 is a Trigger Effect activated from the GRAVEYARD**, keyed on
##      `ATTACK_DECLARED` with `direct` true and the attacking player being the OPPONENT. It
##      has no "You can", so it is **MANDATORY**.
##   3. **Clause 2 makes the card a Trap Monster**, which is the generic subsystem built
##      before this card and gated by `TrapMonsterTests`. RULES_SPEC.md 5.8. The runtime type
##      line lives on the `CardInstance`; the shared, immutable `CardDef` is never written to.
##      "(This card is NOT treated as a Trap.)" is carried by
##      `treated_as_original_type = false`.
##   4. **The Summon goes through the ordinary Special Summon route**, so it emits real
##      summon events, respects the free-Monster-Zone and control-limit checks, and is
##      negatable. It is not a bespoke placement.
##   5. **Clause 3 is conditional on clause 2 having succeeded** — "If Summoned **this way**".
##      It is marked only after the Summon actually happened, through the `card_memory`
##      channel `GameState.move_card()` reads, never a new flag. A copy that reached a Monster
##      Zone by some other route would not carry it.
##   6. This card is in the **Fairy-Tail Tribute Guard** deck, 1 copy.

const CARD_NAME := "The Phantom Knights of Shadow Veil"

const ATK_DEF_GAIN := 300

# The type line clause 2 grants. Quoted from the card, not invented.
const SUMMON_RACE := "Warrior"
const SUMMON_ATTRIBUTE := "DARK"
const SUMMON_LEVEL := 4
const SUMMON_ATK := 0
const SUMMON_DEF := 300

const SUMMON_EFFECT_ID := "gy_summon_self_as_trap_monster"

const CLAUSE_BOOST := "Target 1 face-up monster you control; it gains 300 ATK/DEF."
const CLAUSE_SUMMON := "When an opponent's monster declares a direct attack while this " \
	+ "card is in your GY: Special Summon this card in Defense Position as a Normal " \
	+ "Monster (Warrior/DARK/Level 4/ATK 0/DEF 300). (This card is NOT treated as a Trap.)"
const CLAUSE_BANISH := "If Summoned this way, banish this card when it leaves the field."


func effects() -> Array:
	return [_atk_def_boost(), _graveyard_trap_monster_summon()]


# ---------------------------------------------------------------------------
# Clause 1 — the Trap activation. "Target 1 face-up monster you control;
#            it gains 300 ATK/DEF."
# ---------------------------------------------------------------------------

func _atk_def_boost() -> EffectDef:
	var e := EffectDef.new("boost_own_monster", CLAUSE_BOOST)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap's CARD-level Spell Speed must be stated: `of_type()` derives Spell Speed
	# from the effect category, which is SS1 for everything but a Quick Effect, and a Trap
	# left at SS1 would never be offered in a response window. [S1 p.44-45]
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_DOWN])
	e.targeting(1, 1)

	e.condition = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.own_monsters(ctx).is_empty()

	e.legal_targets = func(ctx: EffectContext) -> Array:
		# "1 face-up monster YOU control" — face-up only, and never the opponent's.
		return EffectPrimitives.own_monsters(ctx)

	e.resolve = func(ctx: EffectContext) -> void:
		# Every word that made it a legal target is re-checked at resolution: still in a
		# Monster Zone, still yours, still face-up. CARD_RULINGS.md R29.
		var target := EffectPrimitives.surviving_own_monster_target(ctx)
		if target == null:
			ctx.log_note("the target is no longer a face-up monster you control")
			return
		EffectPrimitives.gain_atk_and_def_permanently(ctx, target, ATK_DEF_GAIN)
		ctx.log_note("%s gains %d ATK/DEF" % [target.card_name(), ATK_DEF_GAIN])

	return e


# ---------------------------------------------------------------------------
# Clauses 2 and 3 — the Graveyard trigger that makes it a Trap Monster, and the
#                   departure replacement that is conditional on it.
# ---------------------------------------------------------------------------

func _graveyard_trap_monster_summon() -> EffectDef:
	var e := EffectDef.new(SUMMON_EFFECT_ID, CLAUSE_SUMMON + " " + CLAUSE_BANISH)
	e.of_type(Enums.EffectType.TRIGGER)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.on_events([GameEvent.Kind.ATTACK_DECLARED])
	e.from_locations([Enums.ActivationLocation.GRAVEYARD])
	# No "You can" anywhere in the sentence, so it is MANDATORY. Master prompt 24.
	e.mandatory()

	e.condition = func(ctx: EffectContext) -> bool:
		# "while this card is in your GY" — the clause names where it must be.
		if ctx.source.zone != Enums.Zone.GRAVEYARD:
			return false
		var event := ctx.trigger_event
		if event == null or event.kind != GameEvent.Kind.ATTACK_DECLARED:
			return false
		# "When an OPPONENT'S monster declares a DIRECT attack". Both halves are required:
		# an attack on a monster does not qualify, and neither does your own attack.
		if not bool(event.data.get("direct", false)):
			return false
		if int(event.data.get("player", -1)) != ctx.opponent_id():
			return false
		# A Special Summon with nowhere to go does not happen, so the trigger has no reason
		# to be collected. Checked here as well as inside the primitive because a MANDATORY
		# effect is not offered as a choice — it simply fires.
		return ctx.me().has_free_monster_zone()

	e.resolve = func(ctx: EffectContext) -> void:
		# The runtime type line the card prints. RULES_SPEC.md 5.8.
		# `false` for `treated_as_original_type` is "(This card is NOT treated as a Trap.)".
		var identity := EffectPrimitives.trap_monster_identity(
			SUMMON_RACE, SUMMON_ATTRIBUTE, SUMMON_LEVEL, SUMMON_ATK, SUMMON_DEF,
			true, SUMMON_EFFECT_ID, false)
		if not EffectPrimitives.special_summon_self_as_trap_monster(ctx,
				Enums.Zone.GRAVEYARD, identity, Enums.Position.FACE_UP_DEFENSE):
			ctx.log_note("the Special Summon did not happen")
			return
		# Clause 3 — "If Summoned THIS WAY, banish this card when it leaves the field."
		# Marked only now, because the condition is that this Summon succeeded. A copy that
		# reached a Monster Zone any other way carries no such obligation.
		EffectPrimitives.banish_when_it_leaves_the_field(ctx, ctx.source)
		ctx.log_note("Special Summoned itself as a Level 4 DARK Warrior in Defense Position")

	return e
