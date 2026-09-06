class_name Enums
extends RefCounted

## Central enumerations for the duel engine.
##
## Every value here maps to a rule documented in Research/RULES_SPEC.md.
## The engine never uses bare strings for these concepts.


## Card zones. Extra Deck and Extra Monster Zone exist in the model even though the
## V1 card pool never uses them (RULES_SPEC.md 14) so they can be enabled later.
enum Zone {
	DECK,
	HAND,
	MONSTER_ZONE,
	SPELL_TRAP_ZONE,
	FIELD_ZONE,
	GRAVEYARD,
	BANISHED,
	EXTRA_DECK,
	EXTRA_MONSTER_ZONE,
	## Transient holding area while a card is mid-Summon or mid-activation.
	IN_TRANSIT,
	## Cards taken off the top of the Deck by an EXCAVATE and not yet placed anywhere.
	##
	## Deliberately NOT `IN_TRANSIT`: that zone means "mid-Summon / mid-activation" and is
	## what `GameState._is_destroyable_zone()` lets a Summon-negation destroy. An excavated
	## card is not being Summoned, is not on the field, and cannot be destroyed — conflating
	## the two would make a negation card able to reach into an excavation.
	## RULES_SPEC.md 8.2.
	EXCAVATED,
}

## Turn phases. RULES_SPEC.md 2.
enum Phase {
	DRAW,
	STANDBY,
	MAIN_1,
	BATTLE,
	MAIN_2,
	END,
}

## Battle Phase steps. RULES_SPEC.md 6.1.
enum BattleStep {
	NONE,
	START,
	BATTLE,
	DAMAGE,
	END,
}

## Damage Step sub-steps. RULES_SPEC.md 7.1 [S3].
enum DamageSubStep {
	NONE,
	START_OF_DAMAGE_STEP,
	BEFORE_DAMAGE_CALCULATION,
	DURING_DAMAGE_CALCULATION,
	AFTER_DAMAGE_CALCULATION,
	END_OF_DAMAGE_STEP,
}

## Battle position. RULES_SPEC.md 5.
enum Position {
	FACE_UP_ATTACK,
	FACE_UP_DEFENSE,
	FACE_DOWN_DEFENSE,
	## Set Spell/Trap cards.
	FACE_DOWN,
	## Face-up Spell/Trap on the field (activated Continuous/Field/Equip, or a
	## Normal Spell/Trap while it is resolving).
	FACE_UP,
}

## Card category. Derived from the official database Icon / species fields.
enum Category {
	MONSTER,
	SPELL,
	TRAP,
}

## Spell/Trap subtype. RULES_SPEC.md 4.2.
enum STKind {
	NONE,
	NORMAL_SPELL,
	QUICK_PLAY_SPELL,
	CONTINUOUS_SPELL,
	EQUIP_SPELL,
	FIELD_SPELL,
	RITUAL_SPELL,
	NORMAL_TRAP,
	CONTINUOUS_TRAP,
	COUNTER_TRAP,
}

## Spell Speed. RULES_SPEC.md 4.2 [S1 p.44-45].
enum SpellSpeed {
	SS1 = 1,
	SS2 = 2,
	SS3 = 3,
}

## Effect categories. RULES_SPEC.md 4.2, master prompt 26/27.
enum EffectType {
	## Spell Speed 1, activated by the turn player during an open game state in a Main Phase.
	IGNITION,
	## Spell Speed 2 monster effect, usable during a legal Fast Effect window.
	QUICK,
	## Spell Speed 1, activated automatically at a specific timing.
	TRIGGER,
	## Trigger effect activated by the card being flipped face-up.
	FLIP,
	## Not activated, does not start a Chain; applied as a state-derived modifier.
	CONTINUOUS,
	## Activation of the Spell/Trap card itself.
	CARD_ACTIVATION,
	## A rule-based summoning procedure that does not start a Chain
	## (e.g. "you can Special Summon this card (from your hand)").
	SUMMON_PROCEDURE,
}

## Whether an activatable effect must be used when its condition is met.
enum Optionality {
	OPTIONAL,
	MANDATORY,
}

## Where an effect may be activated from.
enum ActivationLocation {
	HAND,
	FIELD_FACE_UP,
	FIELD_FACE_DOWN,
	GRAVEYARD,
	BANISHED,
	DECK,
}

## Semantic reason a card changed zone. RULES_SPEC.md 8, master prompt 19.
## Triggers must react to the reason, never to a generic move.
enum MoveReason {
	## Rules-driven, no special semantics.
	RULE,
	DRAW,
	## Destroyed by monster battle.
	DESTROYED_BY_BATTLE,
	## Destroyed by a card effect.
	DESTROYED_BY_EFFECT,
	## Sent to the GY by an effect without being destroyed.
	SENT_TO_GY_BY_EFFECT,
	## Sent to the GY to pay a cost.
	SENT_AS_COST,
	## Tributed. NOT "destroyed". [S1 p.53]
	TRIBUTED,
	## Hand to GY. NOT "destroyed". [S1 p.52]
	DISCARDED,
	## Separated from the field. NOT "sent to the GY". [S1 p.53]
	BANISHED,
	RETURNED_TO_HAND,
	RETURNED_TO_DECK_TOP,
	RETURNED_TO_DECK_BOTTOM,
	SHUFFLED_INTO_DECK,
	## Placed on the field by a Summon.
	SUMMONED,
	SET,
	## Spell/Trap leaving the field after resolving.
	RESOLVED_TO_GY,
	## End Phase hand-size discard. [S1 p.40]
	HAND_SIZE_DISCARD,
	## Destroyed by the game RULES rather than by battle or by a card effect. The only
	## case in the V1 pool is an Equip Card losing its equipped monster: "If the equipped
	## monster is destroyed, flipped face-down, or removed from the field, its Equip Cards
	## are destroyed" [S1 p.29, p.55]. It IS a destruction and it IS "sent to the GY", but
	## it is deliberately distinct from DESTROYED_BY_EFFECT so that a clause worded
	## "destroyed by battle or card effect" (`Ranryu`, `Inari Fire`) does not see it.
	DESTROYED_BY_RULE,
	## "**Add** 1 of them to your hand" — a card reaching the hand from the Deck, the
	## Graveyard or an excavation. Deliberately distinct from `RETURNED_TO_HAND`: PSCT
	## separates "add to your hand" from "return to the hand", and a card that was never on
	## the field was not *returned* anywhere. `Crystal Seer` needs the first, every bounce
	## card in the pool needs the second. RULES_SPEC.md 8.
	ADDED_TO_HAND,
	## Taken off the top of the Deck by an EXCAVATE, pending placement. RULES_SPEC.md 8.2.
	EXCAVATED,
	## A TEMPORARILY banished card coming back at its stated return timing
	## (`Interdimensional Matter Transporter`: "banish that target until the End Phase").
	##
	## Deliberately its own reason and deliberately NOT `SUMMONED`: the monster returns to
	## the field but it is **not Summoned** — no Normal, Flip or Special Summon happens, so
	## nothing that keys on a successful Summon may see it, and a Summon-negating card has
	## nothing to answer. RULES_SPEC.md 8.3, CARD_RULINGS.md R30.
	RETURNED_FROM_BANISHMENT,
}

## Summon kinds. RULES_SPEC.md 5.
enum SummonKind {
	NORMAL,
	NORMAL_SET,
	TRIBUTE,
	TRIBUTE_SET,
	FLIP,
	SPECIAL,
}

## How long a change of CONTROL lasts. RULES_SPEC.md 5.6.
##
## Control is always a LEASE with an explicit end condition, never an unconditional rewrite
## of who controls a card: every control-changing card in the V1 pool states a duration, and
## the two it states are these. OWNERSHIP is never affected by any of them.
enum ControlDuration {
	## "…while this card is face-up on the field" — the three Charmers. Ends the moment the
	## SOURCE stops being face-up on the field, for any reason.
	WHILE_SOURCE_FACE_UP,
	## "…until the End Phase" — `Enemy Controller`. Ends when the End Phase is entered.
	UNTIL_END_PHASE,
	## No stated end condition. Nothing in the V1 pool uses it; it exists so that a card that
	## genuinely says "take control" with no duration is not silently given one.
	PERMANENT,
}

## How long a BANISHMENT lasts. RULES_SPEC.md 8.3.
##
## Deliberately the same shape as `ControlDuration`: a temporary banishment is a LEASE with
## an explicit end condition, held by `GameState.banish_leases` and expired through
## `GameState.expire_banish_leases()`, exactly as a control change is. Most banishing in the
## pool is permanent and never creates a lease at all — only a card whose own text states a
## return timing does.
enum BanishDuration {
	## "…banish that target until the End Phase" — `Interdimensional Matter Transporter`.
	## Returns when the End Phase is ENTERED, at the same moment an UNTIL_END_PHASE control
	## lease ends. CARD_RULINGS.md R25 fixes that moment.
	UNTIL_END_PHASE,
	## No stated return timing: the card stays banished. This is what
	## `pay_banish_cost()` and `banish_target()` do, and it creates no lease.
	PERMANENT,
}

## Damage Step activation permission. RULES_SPEC.md 7.2 [S1 p.41].
enum DamageStepPermission {
	## Never activatable in the Damage Step. Default.
	NONE,
	## Counter Trap, or an effect that directly changes ATK/DEF.
	## Legal only up until the start of damage calculation.
	UNTIL_DAMAGE_CALC,
	## A mandatory trigger the rules require to occur inside the Damage Step.
	## Collected by the trigger system, never offered as a fast-effect choice.
	MANDATORY_TRIGGER,
	## An effect whose rules-mandated window is sub-step 4, AFTER damage calculation —
	## "when this card battles", "when you take battle damage". RULES_SPEC.md 7.1.
	##
	## Distinct from MANDATORY_TRIGGER, which is gated on the effect being collected by the
	## trigger system and so cannot describe a Trap CARD activation. `Damage Condenser`
	## (cid 6582) is activated from a Set position in exactly this window and is the reason
	## this value exists. RULES_SPEC.md 7.2, CARD_RULINGS.md R42 Part C.
	AFTER_DAMAGE_CALC,
}

## Kinds of decision the engine can ask a controller for. Master prompt 42.
enum DecisionKind {
	YES_NO,
	SELECT_EXACTLY,
	SELECT_UP_TO,
	SELECT_AT_LEAST,
	CHOOSE_EFFECT,
	CHOOSE_TARGETS,
	CHOOSE_COST,
	CHOOSE_TRIBUTES,
	CHOOSE_DISCARD,
	CHOOSE_POSITION,
	CHOOSE_ZONE,
	CHOOSE_ATTACK_TARGET,
	ORDER_TRIGGERS,
	CONFIRM_OR_PASS,
	CHOOSE_ACTION,
}

## Player-visible action kinds. Master prompt 68.
enum ActionKind {
	NORMAL_SUMMON,
	NORMAL_SET,
	TRIBUTE_SUMMON,
	TRIBUTE_SET,
	FLIP_SUMMON,
	CHANGE_POSITION,
	ACTIVATE_CARD,
	ACTIVATE_EFFECT,
	SET_SPELL_TRAP,
	SPECIAL_SUMMON_PROCEDURE,
	DECLARE_ATTACK,
	ENTER_BATTLE_PHASE,
	END_BATTLE_PHASE,
	GO_TO_MAIN_2,
	END_PHASE,
	END_TURN,
	PASS,
	SURRENDER,
}

## Duel outcome.
enum DuelResult {
	ONGOING,
	PLAYER_0_WINS,
	PLAYER_1_WINS,
	DRAW,
}

## Why a duel ended.
enum EndReason {
	NONE,
	LP_ZERO,
	DECK_OUT,
	EFFECT_VICTORY,
	SURRENDER,
	SIMULTANEOUS_LP_ZERO,
}


# ---------------------------------------------------------------------------
# Classification helpers
# ---------------------------------------------------------------------------

## Card-level Spell Speed for a Spell/Trap. RULES_SPEC.md 4.2.
static func spell_speed_for_st(kind: STKind) -> int:
	match kind:
		STKind.NORMAL_SPELL, STKind.CONTINUOUS_SPELL, STKind.EQUIP_SPELL, \
		STKind.FIELD_SPELL, STKind.RITUAL_SPELL:
			return SpellSpeed.SS1
		STKind.QUICK_PLAY_SPELL, STKind.NORMAL_TRAP, STKind.CONTINUOUS_TRAP:
			return SpellSpeed.SS2
		STKind.COUNTER_TRAP:
			return SpellSpeed.SS3
		_:
			return SpellSpeed.SS1


## Default Spell Speed for a monster effect category. RULES_SPEC.md 4.2 [S1 p.10].
## Quick Effects are Spell Speed 2; every other monster effect is Spell Speed 1.
static func spell_speed_for_effect(effect_type: EffectType) -> int:
	if effect_type == EffectType.QUICK:
		return SpellSpeed.SS2
	return SpellSpeed.SS1


## A card is "destroyed" only for these reasons. [S1 p.52]
static func is_destruction(reason: MoveReason) -> bool:
	return reason == MoveReason.DESTROYED_BY_BATTLE \
		or reason == MoveReason.DESTROYED_BY_EFFECT \
		or reason == MoveReason.DESTROYED_BY_RULE


## Destroy, discard and Tribute all count as "sent to the Graveyard". [S1 p.53]
## A banished card later moved to the GY does NOT.
static func is_sent_to_gy(reason: MoveReason) -> bool:
	return reason == MoveReason.DESTROYED_BY_BATTLE \
		or reason == MoveReason.DESTROYED_BY_EFFECT \
		or reason == MoveReason.DESTROYED_BY_RULE \
		or reason == MoveReason.SENT_TO_GY_BY_EFFECT \
		or reason == MoveReason.SENT_AS_COST \
		or reason == MoveReason.TRIBUTED \
		or reason == MoveReason.DISCARDED \
		or reason == MoveReason.HAND_SIZE_DISCARD \
		or reason == MoveReason.RESOLVED_TO_GY


## The three ways a card reaches the Deck. They are three different rules, not one
## "return to Deck" with a flag: only the third shuffles, and only the third ends what the
## players legally know about where the card is. RULES_SPEC.md 8.2, 12.1.
static func is_return_to_deck(reason: MoveReason) -> bool:
	return reason == MoveReason.RETURNED_TO_DECK_TOP \
		or reason == MoveReason.RETURNED_TO_DECK_BOTTOM \
		or reason == MoveReason.SHUFFLED_INTO_DECK


## Which end of the Deck a return-to-Deck reason places the card at.
##
## Derived from the REASON rather than passed alongside it, so the two can never disagree.
## Before this existed, `move_card(card, DECK, RETURNED_TO_DECK_BOTTOM)` silently placed the
## card on TOP unless the caller also remembered an unrelated `deck_position` option.
static func deck_position_for(reason: MoveReason) -> String:
	return "bottom" if reason == MoveReason.RETURNED_TO_DECK_BOTTOM else "top"


static func is_face_up(pos: Position) -> bool:
	return pos == Position.FACE_UP_ATTACK \
		or pos == Position.FACE_UP_DEFENSE \
		or pos == Position.FACE_UP


static func is_defense(pos: Position) -> bool:
	return pos == Position.FACE_UP_DEFENSE or pos == Position.FACE_DOWN_DEFENSE


static func is_on_field_zone(zone: Zone) -> bool:
	return zone == Zone.MONSTER_ZONE \
		or zone == Zone.SPELL_TRAP_ZONE \
		or zone == Zone.FIELD_ZONE \
		or zone == Zone.EXTRA_MONSTER_ZONE


static func is_spell(kind: STKind) -> bool:
	return kind in [STKind.NORMAL_SPELL, STKind.QUICK_PLAY_SPELL, STKind.CONTINUOUS_SPELL,
		STKind.EQUIP_SPELL, STKind.FIELD_SPELL, STKind.RITUAL_SPELL]


static func is_trap(kind: STKind) -> bool:
	return kind in [STKind.NORMAL_TRAP, STKind.CONTINUOUS_TRAP, STKind.COUNTER_TRAP]


## Spell/Trap kinds that stay on the field after resolving. [S1 p.28-30]
static func stays_on_field(kind: STKind) -> bool:
	return kind in [STKind.CONTINUOUS_SPELL, STKind.EQUIP_SPELL, STKind.FIELD_SPELL,
		STKind.CONTINUOUS_TRAP]


## Parse the official database Icon string into an STKind.
static func st_kind_from_icon(icon: String) -> STKind:
	match icon:
		"Normal Spell": return STKind.NORMAL_SPELL
		"Quick-Play Spell": return STKind.QUICK_PLAY_SPELL
		"Continuous Spell": return STKind.CONTINUOUS_SPELL
		"Equip Spell": return STKind.EQUIP_SPELL
		"Field Spell": return STKind.FIELD_SPELL
		"Ritual Spell": return STKind.RITUAL_SPELL
		"Normal Trap": return STKind.NORMAL_TRAP
		"Continuous Trap": return STKind.CONTINUOUS_TRAP
		"Counter Trap": return STKind.COUNTER_TRAP
		_: return STKind.NONE


static func phase_name(p: Phase) -> String:
	match p:
		Phase.DRAW: return "Draw Phase"
		Phase.STANDBY: return "Standby Phase"
		Phase.MAIN_1: return "Main Phase 1"
		Phase.BATTLE: return "Battle Phase"
		Phase.MAIN_2: return "Main Phase 2"
		Phase.END: return "End Phase"
		_: return "Unknown Phase"
