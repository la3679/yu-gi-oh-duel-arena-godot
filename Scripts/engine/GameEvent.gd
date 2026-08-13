class_name GameEvent
extends RefCounted

## Semantic engine events. Master prompt 63.
##
## The engine emits these; the presentation layer consumes them. Presentation NEVER
## changes a rules outcome — an event is a statement of something that already happened
## in the authoritative state.
##
## Trigger effects also subscribe to these, which is why every movement event carries an
## explicit MoveReason: a trigger must be able to distinguish "destroyed" from "Tributed"
## from "discarded" (RULES_SPEC.md 8).

enum Kind {
	DUEL_STARTED,
	TURN_STARTED,
	PHASE_CHANGED,
	BATTLE_STEP_CHANGED,
	DAMAGE_SUBSTEP_CHANGED,

	CARD_DRAWN,
	CARD_SET,
	CARD_MOVED,

	NORMAL_SUMMON_DECLARED,
	NORMAL_SUMMON_SUCCEEDED,
	SPECIAL_SUMMON_DECLARED,
	SPECIAL_SUMMON_SUCCEEDED,
	SUMMON_NEGATED,
	FLIP_SUMMON_DECLARED,
	FLIP_SUMMON_SUCCEEDED,
	CARD_FLIPPED_FACE_UP,
	TRIBUTE_SELECTED,
	CARD_TRIBUTED,

	EFFECT_ACTIVATED,
	COST_PAID,
	TARGET_SELECTED,
	CHAIN_LINK_ADDED,
	RESPONSE_PASSED,
	CHAIN_CLOSED,
	CHAIN_LINK_RESOLVING,
	EFFECT_NEGATED,
	ACTIVATION_NEGATED,
	CHAIN_LINK_RESOLVED,
	CHAIN_RESOLVED,

	ATTACK_DECLARED,
	ATTACK_TARGET_SELECTED,
	ATTACK_NEGATED,
	ATTACK_REPLAY,
	DAMAGE_CALCULATED,
	BATTLE_DAMAGE_INFLICTED,

	LP_CHANGED,
	CARD_DESTROYED,
	CARD_SENT_TO_GY,
	CARD_BANISHED,
	CARD_RETURNED_TO_HAND,
	CARD_RETURNED_TO_DECK,
	CONTROL_CHANGED,
	BATTLE_POSITION_CHANGED,
	COUNTER_PLACED,
	COUNTER_REMOVED,
	CARD_EQUIPPED,
	CARD_UNEQUIPPED,

	DECISION_REQUESTED,
	DECISION_SUBMITTED,

	PLAYER_DEFEATED,
	DUEL_ENDED,
}

var kind: Kind
## Arbitrary structured payload. Keys used per kind are documented at emit sites.
var data: Dictionary = {}
## Monotonic sequence number assigned by GameState when the event is emitted.
var sequence: int = -1
## Turn / phase context captured at emit time, so the log is self-describing.
var turn: int = 0
var phase: Enums.Phase = Enums.Phase.DRAW


func _init(p_kind: Kind = Kind.DUEL_STARTED, p_data: Dictionary = {}) -> void:
	kind = p_kind
	data = p_data


## Players who may see this event without leaking hidden information.
## An empty array means public. Master prompt 40.
func private_to() -> Array:
	return data.get("private_to", [])


func is_public() -> bool:
	return private_to().is_empty()


static func kind_name(k: Kind) -> String:
	return Kind.keys()[k]


func _to_string() -> String:
	return "[%d] %s %s" % [sequence, kind_name(kind), data]
