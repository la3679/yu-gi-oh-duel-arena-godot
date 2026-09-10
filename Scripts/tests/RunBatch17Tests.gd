extends SceneTree

## Targeted runner for Phase 5 batch 17 — the twin of `RunBatch16Tests.gd`.
##
##   ./Tools/run_tests.sh RunBatch17Tests
##
## Runs the new gate and the new card next to the suites they are most likely to disturb.
## Batch 17 reached further into shared code than batch 16 did, so the neighbours are chosen
## by what it touched rather than by subject:
##
##   * `HiddenInfoTests` — the opponent-decision gate itself, and the two earlier gates
##     (`look_at_hand`, the random choice) that live beside it in the same subsystem;
##   * `DeckAccessTests` — `deck_search_candidates()` gained an Extra Deck parameter and
##     `send_from_deck_to_gy()` now asks the player whose Deck it is;
##   * `ReplayTests` — every mid-resolution decision now goes through `ask_player()`, which
##     is what writes the replay payload;
##   * `ChainTests` and `TimingTests` — `ChainManager._resolve_link()` and the two
##     `DuelEngine` activation paths now hand the controller TABLE down beside `decider`;
##   * `ImmunityTests` — `Fairy Tail - Luna`'s unaffected-target branch is batch 16's gate
##     read by a second card;
##   * `SummonTests` — clause 1 keys on `NORMAL_SUMMON_SUCCEEDED` and depends on a Tribute
##     Summon emitting it;
##   * `MovementTests` — the return-to-hand half, and the owner-bound destination;
##   * `ControlTests` — the resolution-time control question this card answers differently
##     from R29;
##   * four neighbouring cards that between them exercise every primitive whose signature or
##     internals changed: `Crystal Seer` and `Dragon Shrine` (Deck access), `Fairy Tail -
##     Rella` (the same archetype and a `choose_one()` caller), and `The Monarchs Awaken`
##     (the immunity gate's own card).
##
## The FULL run stays the authority for every number.

func _initialize() -> void:
	var suites: Array[TestCase] = []
	suites.append(HiddenInfoTests.run())
	suites.append(DeckAccessTests.run())
	suites.append(ReplayTests.run())
	suites.append(ChainTests.run())
	suites.append(TimingTests.run())
	suites.append(ImmunityTests.run())
	suites.append(SummonTests.run())
	suites.append(MovementTests.run())
	suites.append(ControlTests.run())
	suites.append(CrystalSeerTests.run())
	suites.append(DragonShrineTests.run())
	suites.append(FairyTailRellaTests.run())
	suites.append(MonarchsAwakenTests.run())
	suites.append(FairyTailLunaTests.run())

	var total_passed := 0
	var total_failed := 0
	var empty_suites: Array[String] = []
	print("")
	for s in suites:
		print(s.report())
		total_passed += s.passed
		total_failed += s.failed
		if s.total() == 0:
			empty_suites.append(s.suite_name)
	print("")
	print("TOTAL: %d passed, %d failed (%d assertions across %d suite(s))"
		% [total_passed, total_failed, total_passed + total_failed, suites.size()])
	for name in empty_suites:
		print("EMPTY SUITE: %s ran no assertions — treated as a failure" % name)
	if total_failed > 0 or not empty_suites.is_empty():
		print("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
