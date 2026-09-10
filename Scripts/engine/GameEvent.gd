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
	## "…but skip your next Battle Phase after activation" [`Runick Flashing Fire`]:
	## the obligation being taken on, and the Battle Phase it later costs. Two events, not
	## one, because they happen on different turns. RULES_SPEC.md 2.4.
	BATTLE_PHASE_SKIP_IMPOSED,
	BATTLE_PHASE_SKIPPED,

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
	## "The activated effect BECOMES …" — a link's resolution text was replaced while it
	## sat on the Chain. This is NEITHER negation: the card still activated, still occupies
	## its link, and still resolves. RULES_SPEC.md 10.11, CARD_RULINGS.md R5.
	CHAIN_LINK_EFFECT_SUBSTITUTED,
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
	## A TEMPORARILY banished card came back at its stated return timing. Distinct from every
	## Summon event on purpose: the monster returns but is NOT Summoned. RULES_SPEC.md 8.3.
	CARD_RETURNED_FROM_BANISHMENT,
	CARD_RETURNED_TO_HAND,
	## "Add … to your hand" — distinct from CARD_RETURNED_TO_HAND. See MoveReason.ADDED_TO_HAND.
	CARD_ADDED_TO_HAND,
	CARD_RETURNED_TO_DECK,
	## A hidden card was shown to one or both players. Carries `to` (the viewers) and the
	## card's identity, and is PUBLIC only when both players were shown it.
	CARD_REVEALED,
	## Cards were taken off the top of a Deck by an excavate. Distinct from CARD_DRAWN.
	CARD_EXCAVATED,
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

## A `private_to` naming no real player. An EMPTY `private_to` means public, so an event about
## a card NO player may see — one moved within a Deck — is marked `[NOBODY]` instead: it stays
## in `GameState.events` and the replay log, where triggers and replays read it, and out of
## both players' logs. RULES_SPEC.md 12.5.
const NOBODY := -1

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
