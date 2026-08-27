# Six by Eleven

A merge autobattler on a 6×11 board with a neutral centre row. Built for **Godot 4.7.2**.

Open `project.godot` in Godot and press F5. You get a playable prep→battle→round loop
against a stand-in opponent, with placeholder coloured blocks instead of art.

---

## Where your three jobs plug in

### Sprites

Open any unit in `data/units/` and drop a `Texture2D` into **Presentation → sprite**.
That's it — `UnitView` picks it up, scales it to the tile, and stops drawing the
coloured fallback block. Nothing else needs touching.

For anything fancier than a static image (animation, particles, a shader), set
**view_scene** instead and build a scene per unit. `UnitView` is 120 lines and
deliberately easy to replace.

The health bar, team ring and tier pips are drawn in `scripts/view/unit_view.gd`
in `_draw()`. Change colours and sizes there.

### Numbers

Two options, and they don't mix well — pick one.

**Edit `.tres` files directly** in the Godot inspector. `data/units/*.tres` are the
stat blocks, `data/buffs/*.tres` the buff pool. This is the normal workflow once
you're happy in the editor.

**Or edit the tables** at the top of `tools/generate_data.gd` and regenerate:

```
godot --headless --script res://tools/generate_data.gd
```

This is faster for sweeping changes, but **it overwrites everything in `data/`** —
any hand-tweak in the inspector is lost. Once you start tuning by hand, stop
running it.

Board-level knobs live in `scripts/runtime/board_model.gd`:

| Constant | What it does |
|---|---|
| `HEIGHT` / `NEUTRAL_ROW` | Board size. Flip to 12 and 6 to try the even board again. |
| `DIAGONAL_MOVEMENT` | Chebyshev (8-way) vs Manhattan (4-way, strict lanes). |
| `MERGE_INHERITS_BUFFS` | Whether a merged unit keeps its inputs' buffs. Currently `false`. |
| `merge_pool` | Set via `configure_merges()`. Non-empty turns merging into a lottery. |

And in `scripts/combat/combat_sim.gd`: `TICK` (simulation resolution) and
`DEFAULT_TIMEOUT` (how long before a stalled battle is decided on health).

### Sound

Nothing is wired yet — deliberately, so you can put it where you want it.
The natural hook is `autoload/event_bus.gd`, which already emits everything
worth hearing (`unit_placed`, `unit_merged`, `battle_started`, `battle_finished`,
`round_ended`, `match_ended`).

For combat sounds, `scripts/view/battle_player.gd::_apply()` is the one place
where every `attack`, `damage`, `cast_resolve` and `death` event passes through
during playback. Add an `AudioStreamPlayer` there and switch on `e.kind`.

Do **not** put audio in `scripts/combat/` — that layer runs thousands of times a
second during headless balance runs.

---

## Running things

```
godot --headless --script res://tools/run_tests.gd     # 62 model + sim tests
godot --headless res://tools/smoke_test.tscn           # boots the real scene, plays 6 rounds
godot --headless --script res://tools/generate_data.gd # regenerate data/ from the tables
```

The test suite runs in a couple of seconds and needs no window. Keep it green.
`run_tests.gd` is where the important invariants live — especially:

- **Mirror matchup fairness.** Identical boards should win ~50%. A consistent
  lean means a bug (a leaked team index, an ordering bias), not a balance problem.
- **Movement lockout.** The same fight, twice, with `move_time` as the only
  variable, must produce opposite winners. That's the proof your core mechanic
  actually bites.

In game, **F1** dumps the board to the Output panel as ASCII. When the screen and
the dump disagree, the screen is wrong.

---

## How it's put together

Six layers. Each may call *down*, never *up* — anything that needs to reach
upward emits on `EventBus`.

| Layer | Files | Notes |
|---|---|---|
| Data | `scripts/data/` | Resources. Read-only at runtime, always. |
| Runtime | `scripts/runtime/unit_instance.gd` | Per-unit mutable state, buffs, computed stats. |
| Board | `scripts/runtime/board_model.gd` | The 6×11 grid, deploy zones, merge rules. |
| Combat | `scripts/combat/combat_sim.gd` | Fixed-tick sim. No nodes. Emits an event log. |
| View | `scripts/view/` | Draws things. Holds zero rules. |
| Flow | `autoload/match_state.gd` | Phases, rounds, lives. |

**The load-bearing decision:** `CombatSim` never touches the scene tree. The battle
is fully resolved before a single frame animates — `BattlePlayer` just replays the
log. That's what makes fog of war a filter rather than a hack, lets you run
thousands of battles headless to balance, and keeps the door open for PvP.

The corollary: **never mutate a `UnitData`.** Two units of the same type share one
object, so writing to it changes every unit of that type at once, and in the editor
it edits the file on disk. All mutable state lives on `UnitInstance`.

---

## What's built, and what isn't

Milestones 1–13 of the build plan are done:

- Data-driven units with a 3-tier merge chain
- Board model with deploy zones, the neutral row, merging, mirror symmetry
- Tile-based combat: melee, ranged, spells with AoE shapes, A* pathing
- The movement lockout — a committed unit can't attack, and dies for it
- Deterministic seeded simulation with a full event log
- Grid rendering, click-to-place, drag-to-move, drag-to-merge, battle playback
- Round loop with full roster restoration, lives, and a first-to-4 win condition
- Prep-phase fog of war, lifting at the moment the battle starts
- The merge lottery, floating damage numbers, projectiles, and readable health
- Mana, and one ability per unit: shield, haste, damage-over-time, burst, pierce

Not built yet:

- **Buff picking (milestone 15).** The phase exists and fires on the right rounds;
  it currently prints a message and passes through. The buff *data* and
  `UnitInstance.apply_modifiers()` are both done and tested — you need the picker UI
  and a weighted draw from `data/buffs/`.
- **Batch balance runner (milestone 17).** `tools/run_tests.gd` already runs 120
  battles for the mirror check; generalise that into loadout-vs-loadout win rates.

---

## Fog of war

The fog is up for the **prep phase only**. You arrange without seeing the
opponent's half; the moment you press Fight it lifts and the whole battle is
visible. There is no vision to compute during combat.

It works by **not creating** `UnitView`s for concealed units, rather than drawing
something opaque over them. A black rectangle would pass a screenshot and still
leave every enemy position sitting in the scene tree — worthless as soon as this
is PvP. `tools/smoke_test.gd` asserts the tree is genuinely empty of enemy units
while the fog is up; keep that test if you change any of this.

Two things worth knowing about how it plays:

- **The intel decays on its own.** At the end of every round you saw their entire
  board. So from round 2 onward the fog only conceals what they *changed* — their
  new draw and any merges. That's a better pressure than a blackout, and it means
  the fog gets weaker as boards stabilise.
- **`FOG_SHOWS_COUNT`** in `board_view.gd` decides whether you're told how many
  units they're fielding. Currently `false` — a total blackout. Flip it to `true`
  if prep starts feeling like a coin-flip.

`sight_range` on `UnitData` is now unused. It's kept as the hook for a scout unit
that reveals part of the enemy half during prep; delete it if you rule that out.

## Playback is event-driven, and why that matters

`BattlePlayer` owns the replayed position and health of every unit, in `_pos`
and `_hp`, fed entirely from the sim's event log. **It must never read `cell` or
`current_hp` off a `UnitInstance` during a replay.**

The reason is easy to miss: the simulation runs to completion *before* the first
frame animates, so by playback time every instance already holds its
end-of-battle values. Reading them live made units snap to their final tile the
moment they attacked — very visible on archers — and showed every health bar at
its finished value from frame one.

Ranged attacks now launch a projectile and the damage lands when it arrives:
`FLIGHT_PER_TILE` and `MELEE_REACH` in `battle_player.gd`. The sim is untouched —
travel time is presentation only, so it can't change who wins. If you want shots
that can miss a target that died mid-flight, that has to move into `CombatSim`,
and it's a balance change, not a visual one.

## Abilities and mana

Every unit has one ability. The bar is **100 for everyone** — only
`UnitData.mana_per_attack` differs, so a rate of 25 casts every fourth attack.

**Mana comes from landing attacks, nothing else.** A unit that can't reach
anything never charges. That's deliberate: it makes protecting your damage
dealers matter, and it means a Warden buried at the back is contributing less
than it looks.

Casting locks the unit in `CASTING` — no attacking, no moving — for `cast_time`.
Same exposure rule as committing to a tile step. A free bonus action would
undercut the positioning game the whole design rests on.

| Unit | Ability | What it does | Rate |
|---|---|---|---|
| Warden | Bulwark | 70 shield, absorbed before health, **never healed**. Casts once free at battle start. | 20 |
| Lancer | Impale | Strike through 3 enemies at 210% damage. **Passive: ordinary swings already hit 2.** | 25 |
| Archer | Quickdraw | −16% attack cooldown, permanent, stacking to 6. | 25 |
| Vexer | Blight | 11 damage every 0.5s, 6 times, on one enemy. Keeps ticking while the Vexer shoots elsewhere. | 12 |
| Pyre | Cinder Lance | 78 to the main target, 16 to everything within 1 tile of it. | 34 |

Pyre no longer has an area-of-effect *attack* — its ordinary hits are feeble on
purpose, and everything rides on landing the burst. The burst is pseudo-AoE:
it rewards picking the right target rather than the biggest clump.

Three things in here are easy to break, so they each have a test:

- **Haste stacks live in `battle_modifiers`, not `modifiers`.** The latter is the
  persistent buff list — haste stored there would carry into every later round of
  the match and compound without limit.
- **Shields are not healed.** `heal_to_full()` deliberately leaves `shield` alone,
  and `take_damage()` drains shield before health.
- **Pierce walks the line from the VICTIM, not the attacker.** A shot at a target
  offset by (3, 1) steps diagonally and never lands on the target's own tile, so
  walking from the attacker would damage whoever sits on the stepped line and
  miss the unit actually being aimed at.

To add a sixth ability: add a `Kind`, add its fields to `AbilityData`, and handle
it in `CombatSim._resolve_ability` — that match statement is the only place in
the simulation that knows abilities have kinds.

## Merging is a lottery

Two identical units still merge, but **what comes out is rolled at random** from
the loadout, one tier up. Two Wardens can hand you an Archer II.

`BoardModel.roll_merge_result()` does the draw, off a seeded RNG so a merge is
reproducible. It consumes the RNG, which is why `can_merge()` must never call it —
checking would change the result.

Leave `merge_pool` empty and merging falls back to straight promotion along
`next_tier`. The tests rely on that fallback, so don't delete it.

What this does to the game: merging is no longer a straight upgrade, it's a trade
of two bodies for one stronger but *unpredictable* one. A board built around a
plan can be knocked sideways by a bad roll. If that turns out to feel arbitrary
rather than tense, the knob is the pool — weight it toward the units being merged
rather than drawing uniformly.

## Rounds don't cost you units

The **entire** pre-battle roster is restored after every battle, the dead
included, healed and back on their own tiles. Losing a round costs a life and
nothing else.

Letting the dead stay dead compounds viciously: the side that loses round one
fields fewer units in round two, loses harder, and the match is decided long
before anyone runs out of lives. Restoring everyone makes each round a fresh test
of the arrangement, which is where the interesting decisions are.

The consequence is that boards only ever grow — five new units every prep, and
thirty tiles a side. That fills up in six rounds, so merging becomes a space
problem as much as a power one. That pressure is deliberate.

## Decisions the code is waiting on

- **PvP or PvE?** `_deploy_ai()` in `scripts/view/main.gd` is a placeholder that
  drafts and merges randomly. It doesn't change the architecture, but it changes
  everything about how fog of war should work.
- **Do buffs survive a merge?** `MERGE_INHERITS_BUFFS`, currently `false`.
  `false` makes buffs a reason *not* to merge; `true` makes buffed units snowball.
  Sharper now that merging is a lottery — inheriting buffs would soften a bad roll.
- **Should the merge pool be weighted?** It draws uniformly. Weighting it toward
  the merging unit's own type would keep merges mostly predictable with an
  occasional surprise.
- **Can units stop in the neutral row, or only pass through?** Right now they can
  stop there during combat and nobody can deploy there.
- **Should the fog hide the count too?** `FOG_SHOWS_COUNT`, currently `true`.
- **Is there a scout?** If yes, `sight_range` becomes live again and the fog needs
  per-unit reveal rather than a whole-half blanket.
- **Do ranged units kite?** They currently advance to max range and then hold.
  They never back off when something closes.
- **Bench interaction.** Bench→board is click-to-select-then-click-to-place;
  board→board is drag. Worth unifying to drag once you care about feel.

Board geometry note: the odd height is load-bearing. `mirror(y) = HEIGHT - 1 - y`
maps the centre row onto itself, which is the only reason the mirror-matchup test
is an exact fairness check. Going back to an even board costs you that.
