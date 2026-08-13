class_name EffectDef
extends RefCounted

## Declarative definition of one effect clause of one card. Master prompt 43.
##
## One EffectDef per official effect clause. `Tools/build_matrix.py` counts
## `EffectDef.new(` occurrences per registry file to compute "Effect Clauses Count",
## so the implementation matrix can never over-report.
##
## Behaviour is supplied as Callables, not interpreted from card text. There is no
## runtime natural-language parsing and no runtime LLM (master prompt 43).

## Stable identifier, unique within the card, e.g. "flip_take_control".
var effect_id: String = ""
## Card name this effect belongs to. Set by the registry loader.
var card_name: String = ""
## Human-readable clause text, quoted from the verified official card text.
## Shown in the Chain UI and used in the duel log.
var clause_text: String = ""

var effect_type: Enums.EffectType = Enums.EffectType.IGNITION
var optionality: Enums.Optionality = Enums.Optionality.OPTIONAL

## Spell Speed for THIS effect. RULES_SPEC.md 4.2 — a monster's Quick Effect is
## Spell Speed 2 while its other effects are Spell Speed 1, so this is per-effect
## and is never inferred from the card's category.
var spell_speed: int = Enums.SpellSpeed.SS1

## Zones the effect may be activated from.
var activation_locations: Array = [Enums.ActivationLocation.FIELD_FACE_UP]

## Event kinds that make this effect eligible, for TRIGGER / FLIP / QUICK effects.
## Empty for IGNITION and CONTINUOUS.
var trigger_events: Array = []

## Phases in which activation is legal. Empty means "any phase where timing allows".
var legal_phases: Array = []

## Damage Step legality. RULES_SPEC.md 7.2 [S1 p.41]. Default: not legal.
var damage_step_permission: Enums.DamageStepPermission = Enums.DamageStepPermission.NONE

## Does this effect start a Chain? Continuous effects and summon procedures do not.
var starts_chain: bool = true

## Does this CONTINUOUS clause negate another card's effects? `ContinuousEffects.recompute()`
## applies these before every other continuous clause, because "is this source negated?"
## has no stable answer until they have run. Declared rather than inferred so the ordering
## never depends on which cards happen to be on the field. `Fiendish Chain` is the only
## card in the V1 pool that sets it.
var negates_effects: bool = false

## Does this effect target? RULES_SPEC.md 10, master prompt 17.
var targets: bool = false
var target_count_min: int = 0
var target_count_max: int = 0

# --- Once-per-turn restrictions. RULES_SPEC.md 11, master prompt 47. ---
## "Once per turn" on this specific card instance.
var once_per_turn_instance: bool = false
## "You can only use this effect of [name] once per turn" — per player + name + effect id.
var once_per_turn_named_effect: bool = false
## "You can only activate 1 [name] per turn" — per player + name.
var once_per_turn_named_activation: bool = false
## Shared restriction group: effects with the same non-empty key on the same card share
## one per-turn use. Maiden with Eyes of Blue uses this ("only 1 effect per turn").
var restriction_group: String = ""
## "TWICE per turn, it cannot be destroyed …" — a clause that may apply more than once in
## a turn but not without limit. 0 means unlimited. Counted on the source instance by the
## rules layer (`CardInstance.uses_this_turn`), never by the card's own callables, so a
## query clause can stay a pure function. RULES_SPEC.md 11, 17.
var uses_per_turn: int = 0

# --- Behaviour callables ---
## func(ctx: EffectContext) -> bool — is the activation condition satisfied?
var condition: Callable = Callable()
## func(ctx: EffectContext) -> bool — can the cost be paid right now? (checked before
## the activation is offered; master prompt 16)
var can_pay_cost: Callable = Callable()
## func(ctx: EffectContext) -> bool — pay the cost NOW, at activation. Returns success.
var pay_cost: Callable = Callable()
## func(ctx: EffectContext) -> Array — legal targets, evaluated at activation.
var legal_targets: Callable = Callable()
## func(ctx: EffectContext) -> void — resolve the effect.
var resolve: Callable = Callable()
## func(ctx: EffectContext) -> void — apply/refresh a continuous effect.
var apply_continuous: Callable = Callable()
## func(ctx: EffectContext) -> CardInstance — a destruction REPLACEMENT query:
## "If a monster equipped with this card would be destroyed, destroy this card instead."
## `ctx.params` carries {"card": the card that would be destroyed, "reason": MoveReason}.
## Returns the card to destroy in its place, or null when this clause does not apply.
## RULES_SPEC.md 17; recognised by `GameState.DESTRUCTION_REPLACEMENT_EFFECT_ID`.
var destruction_substitute: Callable = Callable()

## Reference back to the researched ruling note, e.g. "R3" in Research/CARD_RULINGS.md.
var ruling_ref: String = ""


func _init(p_effect_id: String = "", p_clause_text: String = "") -> void:
	effect_id = p_effect_id
	clause_text = p_clause_text


## Fluent configuration so registry files stay readable.
func of_type(t: Enums.EffectType) -> EffectDef:
	effect_type = t
	spell_speed = Enums.spell_speed_for_effect(t)
	if t == Enums.EffectType.CONTINUOUS or t == Enums.EffectType.SUMMON_PROCEDURE:
		starts_chain = false
	return self


func with_spell_speed(s: int) -> EffectDef:
	spell_speed = s
	return self


## Mark a CONTINUOUS clause as one that negates another card's effects. See `negates_effects`.
func negating() -> EffectDef:
	negates_effects = true
	return self


func mandatory() -> EffectDef:
	optionality = Enums.Optionality.MANDATORY
	return self


func from_locations(locs: Array) -> EffectDef:
	activation_locations = locs
	return self


func on_events(evs: Array) -> EffectDef:
	trigger_events = evs
	return self


func in_phases(ps: Array) -> EffectDef:
	legal_phases = ps
	return self


func damage_step(perm: Enums.DamageStepPermission) -> EffectDef:
	damage_step_permission = perm
	return self


func targeting(min_n: int, max_n: int = -1) -> EffectDef:
	targets = true
	target_count_min = min_n
	target_count_max = max_n if max_n >= 0 else min_n
	return self


func opt_instance() -> EffectDef:
	once_per_turn_instance = true
	return self


func opt_named_effect() -> EffectDef:
	once_per_turn_named_effect = true
	return self


func opt_named_activation() -> EffectDef:
	once_per_turn_named_activation = true
	return self


func in_group(key: String) -> EffectDef:
	restriction_group = key
	return self


func ruling(ref: String) -> EffectDef:
	ruling_ref = ref
	return self


func is_continuous() -> bool:
	return effect_type == Enums.EffectType.CONTINUOUS


## Fully-qualified key used for named once-per-turn bookkeeping.
func named_key() -> String:
	if restriction_group != "":
		return restriction_group
	return effect_id


func _to_string() -> String:
	return "EffectDef(%s::%s)" % [card_name, effect_id]
