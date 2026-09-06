# Six by Eleven

A merge autobattler on a 6×11 board with a neutral centre row. Built for **Godot 4.7.2**.

Open `project.godot` in Godot and press F5. You land on a **menu**: battle the
computer, play local PvP on one screen, or edit both sides' loadouts. Placeholder
coloured blocks instead of art, for now.

Each prep phase your units are **summoned straight onto the board** — there's no
tray to place them from. You rearrange by dragging: onto an empty tile to move,
onto a twin to merge, onto another of your units to swap. Click one to read its
stats.

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

**Or edit the tables** at the top of `tools/data_builder.gd` and regenerate.
Easiest way: open **`tools/regenerate_data.gd`** in the Script editor and press
**File > Run** (Ctrl+Shift+X). No terminal, no PATH. There's a command-line
entry point too, if you'd rather:

```
godot --headless --script res://tools/generate_data.gd
```

Both run the same code. This is faster for sweeping changes, but **it overwrites
everything in `data/` and deletes any file the tables no longer produce** — any
hand-tweak in the inspector is lost. Once you start tuning by hand, stop running
it.

Board-level knobs live in `scripts/runtime/board_model.gd`:

| Constant | What it does |
|---|---|
| `HEIGHT` / `NEUTRAL_ROW` | Board size. Flip to 12 and 6 to try the even board again. |
| `DIAGONAL_MOVEMENT` | Chebyshev (8-way) vs Manhattan (4-way, strict lanes). |
| `MERGE_INHERITS_BUFFS` | Whether a merged unit keeps its inputs' buffs. Currently `false`. |
| `merge_pool` | Set via `configure_merges()`. Non-empty turns merging into a lottery. |

And in `scripts/combat/combat_sim.gd`: `TICK` (simulation resolution) and
`DEFAULT_TIMEOUT` (how long before a stalled battle is decided on health — now 90s,
because the Warden rework pushed a full 7v7 past the old 45s cap).

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
godot --headless --script res://tools/run_tests.gd      # 1065 model + sim tests
godot --headless res://tools/smoke_test.tscn            # vs-computer match, start to finish
godot --headless res://tools/pvp_smoke_test.tscn        # local PvP: turn taking and the blind
godot --headless res://tools/menu_smoke_test.tscn       # menu, loadout editor, map grid
godot --headless res://tools/map_smoke_test.tscn        # a round on an undivided, non-default board
godot --headless --script res://tools/generate_data.gd  # regenerate data/ from the tables
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

- Data-driven units with a 6-tier merge chain, doubling per tier
- Board model with deploy zones, the neutral row, merging, mirror symmetry
- Tile-based combat: melee, ranged, spells with AoE shapes, A* pathing
- The movement lockout — a committed unit can't attack, and dies for it
- Deterministic seeded simulation with a full event log
- Grid rendering, click-to-place, drag-to-move, drag-to-merge, battle playback
- Round loop with full roster restoration, lives, and a first-to-4 win condition
- Prep-phase fog of war, lifting at the moment the battle starts
- The merge lottery, floating damage numbers, projectiles, and readable health
- Mana, and one ability per unit: shield, haste, damage-over-time, burst, pierce
- Orthogonal movement, plus tested displacement primitives for future abilities
- A data generator that runs from the editor and prunes its own orphans
- Bronze/silver/gold buff picking, with 28 buffs and their runtime effects
- Fourteen playable unit types, including stealth, auras, revives, healing,
  summons, mana zones and a wild-merging body
- A visible wind-up on every cast, so no ability lands out of nowhere
- A menu with mode select, and a loadout editor for both sides
- Local PvP on one screen, with a blind handover between prep turns
- Buff strips per side with hover-to-read descriptions
- A round-end hold: the final board stays put under a result banner before reset
- A unit codex: hover any unit, in battle or in the loadout menu, to read what it does
- A live force bar during battle that drains toward whichever side is winning
- Thirteen board shapes with terrain — holes, walls, thickness-free barriers and
  high ground — picked in the loadout menu

Not built yet:

- **AoE board marks.** Splash flashes the tiles, but a hit tile leaves no residue.
- **Batch balance runner (milestone 17).** `tools/run_tests.gd` already runs 120
  battles for the mirror check; generalise that into loadout-vs-loadout win rates.

---

## Buffs

Every second round (2, 4, 6, 8) both players pick a buff. **Both sides get the
same rarity; only the choices differ.** You see three options, take one, and the
opponent takes one of its own three at the same rarity.

| Pick | Round | Bronze | Silver | Gold |
|---|---|---|---|---|
| 1st | 2 | 70% | 25% | **5%** |
| 2nd | 4 | 40% | 40% | **20%** |
| 3rd | 6 | 15% | 45% | **40%** |
| 4th | 8 | 5% | 30% | **65%** |

**The rarity is rolled, not scheduled.** Gold can turn up on the very first pick
at 5%, and bronze is still possible on the last at 5%. The odds shift toward gold
each pick, so the escalation is still there — it just isn't guaranteed. One roll
decides the rarity for *both* players, so nobody gets a better tier than their
opponent; only the three options differ. The picker prints the round's odds under
the title so a lucky gold reads as lucky.

The table is `ODDS` in `scripts/runtime/rarity_table.gd` — one row per pick,
`[bronze, silver, gold]`, any weights you like (they don't have to sum to 100).
It lives outside `MatchState` because autoloads aren't available to
`tools/run_tests.gd`, which tests the roll against its own odds over 12,000 draws.

The three cards stack **vertically, centred, along the bottom** so they fit a small
window. Layout constants sit at the top of `scripts/view/buff_picker.gd`:
`CARD_WIDTH` (capped to the window if it's narrower), `CARD_HEIGHT`, `CARD_GAP`,
`BOTTOM_MARGIN`, and `CENTER_VERTICALLY` — flip that last one to `true` to park
the stack in the middle of the screen instead of near the bottom.

### The thirty-one buffs

Bronze / silver / gold, all in `tools/data_builder.gd`'s `BUFF_TABLE`. Every one
doubles from bronze to silver and doubles again to gold.

| Buff | Who | Effect |
|---|---|---|
| Mending Wind | all | Heal 1 / 2 / 4% of max health every second |
| Rupture | all | Attacks deal an extra 1 / 2 / 4% of the target's max health |
| Windfall | all | 10 / 20 / 40% chance on merge to summon one extra random unit |
| Promotion | all | 4 / 8 / 16% chance on merge for the result to gain a tier |
| Full Muster | all | While all five types are on the board: +30 / 60 / 120% health **and** attack |
| War Drums | all | +15 / 30 / 60% attack speed |
| Ironwall | Warden | +50 / 100 / 200% max health (the shield scales off it) |
| Marksmanship | Archer | +25 / 50 / 100% attack, +15 / 30 / 60% attack speed |
| Vigor | Lancer | +30 / 60 / 120% health, +20 / 40 / 80% attack |
| Conflagration | Pyre | +40 / 80 / 160% attack, +10 / 20 / 40% attack speed |
| Swarm | Vexer | +50 / 100 / 200% attack speed |
| Shadowcraft | Assassin | +10 / 20 / 40% attack speed, +15 / 30 / 60% attack |
| Fanfare | Herald | +20 / 40 / 80% attack, +25 / 50 / 100% health |
| Undying | Revenant | +50 / 100 / 200% health **and** attack |
| Grace | Seraph | +35 / 70 / 140% health, +10 / 20 / 40% **healing power** |
| Covenant | Conjurer **and its Wisps** | +50 / 100 / 200% health, +30 / 60 / 120% attack |
| Cohesion | Amalgam | +100 / 200 / 300% max health |
| Incubation | Spire | **+3 / +6 / +9 flat mana a charge**, +50 / 100 / 200% health |
| Confluence | Wellspring | **+3 / +6 / +9 flat mana a charge**, +30 / 60 / 90% health |
| Ascension | Transcendence | +50 / 100 / 150% health **and** attack |
| Dominion | Tyrant | +40 / 80 / 160% health **and** attack |
| Fabrication | Engineer **and its Sentries** | +50 / 100 / 200% health, +40 / 80 / 160% attack |

Fanfare carries a **third** modifier (`stat_c` / `third`) on top of its two:
+25 / 50 / 100% **aura power**, which multiplies the horn the Herald hands out.

Incubation and Confluence are the first buffs whose **two stats use different
modes**: `flat = true` makes `stat_a` (mana regen) a flat `+3`, while `flat_b`
stays `false` so `stat_b` (health) is still a percentage. Before this pair, `flat`
applied to the whole buff. If you add a mixed-mode buff, set both flags.

### Board and rule buffs

| Buff | Rarity | Effect |
|---|---|---|
| Conscription | any | Draw +1 / +2 / +3 more units every turn |
| Reckless | any | Deal +60 / 90 / 120% damage, take +20 / 15 / 10% — the drawback *shrinks* as it gets rarer |
| Bloodletting | any | 20 / 40 / 60% lifesteal on damage dealt |
| Far Sight | **Gold only** | Every unit gains +1 range band |
| Levy | **Gold only** | Right now: fill every free tile on your half with tier 1s |
| Alchemy | **Gold only** | Any two of your units of the same tier can merge, whatever they are |
| Conclave | **Silver only** | Right now: 3 tier-3 units. You draw nothing next round |
| Oblation | **Silver only** | Right now: your highest-tier unit is consumed; every other unit gains tiers |

**Oblation** pays out by the offering's tier: a tier 1–2 gives 1 tier, a 3–4 gives
2, a 5–6 gives 3. Feeding it something big is worth far more than feeding it spare
change.

**Exclusive** buffs (`exclusive_rarity`) only enter the pool at their own rarity —
a bronze round never offers Far Sight, and a gold round never offers Conclave.
**One-shot** buffs (`is_one_shot()`) fire the moment you take them, through
`_fire_one_shot()` in `main.gd`; the rest are ongoing.

Two of these needed new stats, each with a base chosen so a modifier reads
naturally: `DAMAGE_TAKEN` (base **1.0**, multiplies incoming damage in `_damage`)
and `LIFESTEAL` (base **0.0**, so its buff uses **flat** modifiers — a percent
modifier on a zero base does nothing, which is what `BuffData.flat` exists for).

### Reading them on the board

Both sides' buffs are on screen the whole match, on their own side of the board:
**Theirs** in a strip above the opponent's half, **Yours** in a strip below your
own. Each buff is a chip tinted by its rarity — bronze, silver, gold. Nothing is
hidden here; the fog conceals unit positions, not what the opponent picked, and
since you both draw at the same rarity every round, reading their pick is part of
the decision.

**Hover any chip — yours or theirs — to read exactly what it does** at the rarity
it was taken: name, rarity, who it affects, and the full description.

**A buff that isn't doing anything right now is greyed out.** Ironwall with no
Warden on that side, Full Muster one unit type short, anything at all on an empty
board — the chip desaturates and its tooltip says why. It lights back up the moment
the condition is met again, so the strip reads as live state rather than a receipt
of what you picked. The rule is `TeamBuffs.is_live()` and the explanation is
`TeamBuffs.why_idle()`; both are model-layer and tested, and the bars re-read the
board on every summon, merge, move and round end.

Global buffs — War Drums, Mending Wind, Rupture, Windfall, Promotion — count as
live whenever you have any unit at all, since nothing about the board switches
them off.

`scripts/view/buff_bar.gd` measures the row in `_relayout()` and paints it in
`_draw()`. Keep those separate: hit areas computed during `_draw()` don't exist
until the first paint, which breaks tooltips before the bar is drawn and makes the
whole thing untestable headless. Chips take their natural width when they fit and
share the space fairly when they don't, shortest first, so a long name is trimmed
with an ellipsis only once the row genuinely runs out of room. `BAR_HEIGHT` and
`BAR_GAP` in `main.gd` set where the strips sit.

### A unit buff is only in your pool if you field that unit

`BuffPool.offer()` takes the set of unit ids in that player's loadout and drops any
unit-specific buff whose unit isn't in it. Bring no Assassin, never see Shadowcraft.
The six global buffs are always in, so there are always at least six candidates for
three slots.

This is per player, from the **loadout**, not from what's currently on the board —
so the pool doesn't churn as units die and get redrawn.

`Covenant` is the one buff that names more than one unit: it lists `also_units =
["wisp"]`, so it reaches the Conjurer's summons too. Wisps are melee with 1 range,
which is why the attack half is worth taking. The pool gate still keys off the
*named* unit (`unit_id`), so you have to bring a Conjurer to be offered it — you
can't put a Wisp in a loadout.

### Round boundaries: what carries and what doesn't

Two separate resets, and it matters which is which:

- **Round start** (`_begin_prep`, and again at `_start_battle`) calls
  `TeamBuffs.resync()` on every unit: it clears `modifiers` and re-applies the
  team's buff picks from scratch, scaling current health by the change in max
  health. It is **idempotent**, so running it every round can't stack a buff twice.
  This is also what makes a unit-specific buff take hold the moment you field that
  unit, rather than only when it was drawn.
- **Round end** (`_restore_roster`) calls `reset_for_battle()` on the whole roster:
  mana, shields, damage-over-time, haste stacks, stealth, revive counts and every
  `battle_modifier` are wiped, and everyone comes back at full health. Only the
  buffs you *picked* survive, because those live in `modifiers`.

Conditional buffs (Full Muster) are still evaluated at battle start, since they
depend on what's actually on the board when the fighting starts.

### A beat before the fighting

Pressing Fight reveals the board, puts a **READY...** banner up, and holds for
`BATTLE_START_HOLD` (1.3s) before playback begins. The sim has already resolved by
then — the pause is purely so the reveal doesn't cut straight to swinging.
`battle_start_hold` is a variable so the tests can drop it; `main.battle_running`
tells them whether the pause or the battle proper is on screen.

### Healing power is a real stat

`StatModifier.Stat.HEAL_POWER` has a base of **1.0** rather than 0, so a +40%
modifier reads as 1.4x and multiplies the Seraph's burst. It's on the healer, not
the patient. Anything else that heals can multiply by it later.

### How they reach a unit

Three different paths, and it matters which one a buff takes:

- **Stat buffs** go into `UnitInstance.modifiers` — the persistent list. They are
  applied when you take the buff (to everything already on the board) and again
  to every unit summoned or merged afterwards. `TeamBuffs.apply_to()` is the one
  entry point; it is called from `_summon()`, from `BoardModel._roll_merge_procs()`,
  and from `_grant()` in `main.gd`.
- **Full Muster** is conditional, so it can't live in the persistent list. The sim
  checks the board at the start of each battle and, if all five types are present,
  adds it to `battle_modifiers` — which are wiped when the battle ends. Lose a type
  and it's gone next round, automatically.
- **Regen, Rupture and the merge procs** aren't stat changes at all. Regen and
  Rupture are read by `CombatSim` (`_tick_regen()`, and a bonus inside `_damage()`);
  the merge procs are rolled in `BoardModel._roll_merge_procs()`.

Rupture does **not** apply to damage-over-time ticks — Blight would otherwise
carry six free bonuses per cast. Regen fires on a one-second accumulator, not
per tick.

---

## The roster strips

Each side's loadout sits on their own half — theirs above their buff bar, yours
below yours — as chips tinted with each unit's accent, repeats collapsed into
`Warden x2`. Hovering a chip gives the same `UnitCodex` card the board and the
loadout menu use, so you can read what the opponent can draw without waiting to
meet it on the field.

Like the buff strips, they are **fixed to a half and never reordered per player**.
In PvP the bottom strip always says P1 and the top always says P2.

---

## Fog shows last round, not nothing

Fog used to hide the enemy half outright. Now it shows their **previous round's
board** as ghosts: dimmed, dashed-edged tiles with the unit's initial and tier,
drawn straight in `_draw_fog()` rather than instantiated. That matters — the rule
that no enemy `UnitView` exists in the tree while fogged still holds, and the
smoke test still checks it.

`main.gd._record_formations()` takes the snapshot **after `_restore_roster()`**,
which is what makes the Spire behave the way you would expect: a Spire that spent
itself is already out of the roster and does not appear, while the units it raised
are already in and do. Round one shows nothing, because there is no previous round
— the banner reads "hidden until you commit" instead of "last round's board".

What you see is always one round stale. It updates the moment the fight starts and
the real board is revealed.

---

## Picking with your eyes

The loadout menu shows the things you are choosing between, not just their names:

- **`MapPreview`** draws the whole board in a 112px box — walls, holes, high
  ground, barriers, the divider, and a faint team wash over each half. It sizes
  its own cells from the map's dimensions, so The Compound at 12 x 21 and The Pit
  at 4 x 9 both fit the same square.
- **`UnitIcon`** draws a unit the way the board does: its sprite when it has one,
  and otherwise the accent square with its initial, wrapped in its tier colour.
  One sits in front of every slot name and one in the detail panel, so the menu
  and the board never disagree about what a unit looks like.

Both are pure `_draw()` Controls with no scene files, which is also what makes
them testable headless — the menu suite checks the preview fits its box for the
largest map on disk, and that cycling a slot changes its icon.

---

## Reading what a unit does

Every unit's own description is generated from its data by `UnitCodex`
(`scripts/runtime/unit_codex.gd`), so there is exactly one place that decides how
a unit is explained and every surface says the same thing.

It is built from four sources, all already on `UnitData`:

| Part | Comes from |
|---|---|
| The headline | `display_name`, `tier`, `range_name()` |
| The one-line character note | `UnitData.note` |
| The stat line | health, damage, attack speed, reach |
| The passives | `can_move`, `can_attack`, `pierce_targets`, `merge_magnet`, `wild_merge` |
| The ability | `ability.display_name` + `ability.describe()`, plus how the bar fills |

`note` is authored once per unit, in the `UNIT_TABLE` row in
`tools/data_builder.gd` — those notes already existed for every unit; they are now
written into the resource instead of being a comment for whoever read the table.
Every tier of a unit carries the same note.

Two entry points matter:

- `card(data)` / `card_of(instance)` — the full multi-line block for tooltips.
  `card_of` reads the *live* stats, and when a unit is buffed it prints the
  buffed numbers and says what the base was, so a Gold War Drums is visible.
- `one_line(data)` / `one_line_of(instance)` — a single sentence for the status bar.

Where it shows up:

- **On the board, in prep and in battle.** `UnitInspector` is a transparent
  `Control` sitting exactly over the board. Hover a unit for the full card; click
  one for the one-liner in the status bar.
- **In the loadout menu.** Every slot carries its card as a tooltip, and hovering
  a slot fills the detail panel underneath both team cards.

### Why the inspector hit-tests views, not the board

During playback `board.unit_at(cell)` holds **end-of-battle** positions — the sim
finished before frame one. So `BoardView.unit_at_point()` measures against the
live `UnitView` positions instead, which is correct in prep (they are synced) and
correct in battle (they are being animated). Reading the model here would have
told you about whoever *ends up* on that tile.

The inspector is `MOUSE_FILTER_PASS`, not `STOP`: it needs the mouse for tooltips
and clicks, but the event has to keep travelling down to `BoardView`, which does
dragging and merging through `_unhandled_input`. Set it to `STOP` and the board
goes dead in prep.

Fog still applies: `unit_under()` returns nothing for a concealed unit, so you
cannot read the opponent's board through a tooltip while they are still arranging.

---

## The apex beam

A tier 6 Transcendence does not fire a projectile. Every ordinary attack is a beam:

- **Full damage down the line.** It already had `pierce_targets = 100`, so
  `_pierce_beyond()` hits every enemy standing behind the target, to the edge.
- **Half damage to the wash.** `UnitData.beam_splash` (0.5 at the apex) catches
  every enemy within one tile of any cell the beam passes through —
  `CombatSim._beam_wash()` walks `beam_cells()` and takes the eight neighbours of
  each. A `struck` set carries over from the pierce pass so nobody is hit twice.
- **A `beam` event** carrying the line and the wash, so the view can flash the
  line brightly and the wash faintly, and `BoardView.spawn_beam()` draws a wide
  fading bolt that keeps going past the target to the board edge. It is instant:
  `BattlePlayer` clears the target's flight time so no travel delay applies.

`UNLIMITED_TILES` is **100**, and the apex's pierce is 100 to match — the codex
checks `pierce_targets >= UNLIMITED_TILES` to decide whether to say "cuts through
everything in line" or print a number, so those two constants have to move
together.

---

## Rounds always end

Two tier-1 Wardens carry 275 points of shield each and deal about 12 damage a
second, so a pair of them plus a reviving Revenant genuinely could not finish
inside the 90-second timeout. That is a boring round, and the round-end code is
written around somebody being wiped out.

After `CombatSim.SUDDEN_DEATH` (30s) every hit is multiplied by
`pressure()` — `1 + (elapsed - 30) * 0.15`, so ×5.5 at a minute and ×10 at ninety
seconds. It applies to both sides equally, so it cannot decide a round by itself;
a mirror duel under pressure is still near even, and there is a test for that. A
`sudden_death` event fires once when it starts so the view can say so.

Before this, roughly 1 in 40 random 8-v-8 matches ran to timeout.

### Pressure moves as well as hits

The maze and corridor boards found the hole in that. A round can also overrun
because the last units never *meet*, and a bigger multiplier does nothing for a
unit that is still walking — the Gauntlet averaged 76 seconds and the Labyrinth
62. So `pressure()` divides `MOVE_TIME` too, floored at one tick. Every unit is
divided by the same number, so who outruns whom never changes, and the movement
lockout test still passes untouched.

### A corridor is where the movement rules stop being cosmetic

Two things that never mattered on an open board turned out to decide whether a
maze round finishes at all. Both were found by running forty random matches on
every map and printing the survivors of any round that hit the cap.

**A rooted unit is a cork.** A Spire cannot move, and occupied tiles are
impassable, so a Spire deployed onto a one-tile corridor sealed its own army in
for the rest of the round — one probe ended 90 seconds with twelve units alive
and 42 moves in the whole log. A unit whose only route is blocked by a friend
that *cannot walk* now trades places with it (`BoardModel.trade_places()` — the
same swap as `swap_cells()` without the deploy-zone check, which is a prep-phase
rule). The log carries a move for both, so the view animates a shove rather than
a teleport.

**Units queued badly.** When every route was blocked, `_next_step()` fell through
to a greedy step — walk whichever way shortens the straight-line distance. On an
open board that is a fine approximation. In a corridor it is pathological: the
units behind a jam scatter along the wall beside it and never arrive. Now the
fallback re-paths as if friendly units were not there and takes its place in the
queue: shove past anything rooted, and **wait** behind anything that will move on
its own. `_downhill()` also prefers an open tile to one it would have to queue
behind at equal distance.

Together with faster movement these took the Gauntlet from 76s average to 41,
the Labyrinth from 62 to 46, the Cage's worst round from 81s to 50, and removed
the Causeway's timeouts entirely.

There are tests for both rules on a purpose-built 3 x 11 corridor map. The rooted
one uses a **bollard** — a Warden duplicated with `can_move = false` and no
ability — not a Spire, because a Spire spends itself on its summon and clears the
corridor on its own, which made the first version of the test pass for the wrong
reason.

---

## The force bar

During a battle, a bar **beside** the board shows how many units each side still
has — your count filling up from the bottom, theirs pressing down from the top, in
the two team colours, so it reads the same way the board does. It stands to the
right of the board rather than above it, which leaves both horizontal slots for
the roster strips. It drains as units die, and when a side is wiped the bar is entirely the
other colour. That is the whole readout: proportional the whole way, and one solid
colour at the end.

It cannot come from the board model: the sim resolved the entire fight before the
first frame, so `living_units_of()` already knows the outcome.

It also must not be **reconstructed** from births and deaths in the view, which is
how it was first written and which drifted twice. Deaths are deferred by projectile
flight time and revives by flight plus a hair, so a delta tally has ordering
hazards that only show up in one match in twenty — and the bug it produces is a
number quietly one or two out, which nobody reports clearly.

So the **simulation emits the count itself**. `CombatSim._tick_counts()` runs at
the end of every tick, compares `living_count()` for both sides against the last
announced pair, and emits a `counts` event only when it changed. `BattlePlayer`
reads the two numbers straight off the event. There is nothing to drift.

`living_count()` includes units mid-revive, matching `_check_over()`, which counts
pending respawns before calling a round over — if the bar disagreed it would show
a wipe the simulation is about to undo. `main.gd.live_count()` follows the same
rule, and the HUD's `board X v Y` goes through it.

The bar is hidden during prep, where the enemy count is fogged anyway, and stays
up through the round-end hold so the final score is readable.

---

## Every cast has a wind-up

No ability appears out of nowhere. When `CombatSim` emits `cast_start`,
`BattlePlayer._begin_cast()` puts the caster's `UnitView` into a casting state,
and the view draws a closing ring plus a filling arc and the ability's name until
the cast resolves. The Archer visibly draws before it speeds up.

Two details keep it honest:

- **`cast_start` now carries `name` and `opener`.** The view needs the display
  name for the label; `opener` marks the battle-start casts.
- **Openers have `duration = 0.0` in the sim and still animate.** Battle-start
  abilities resolve inside `setup()` before the first tick — that is what makes
  the Herald's horn reach the ally who is about to walk away. The *view*, though,
  clamps the shown wind-up to `BattlePlayer.MIN_CAST_SHOW` (0.32s), so the
  simulation stays instant while the screen still shows a beat of setup.

The shown duration is divided by the player's `speed`, so a fast-forwarded
battle does not leave rings hanging on the board. `UnitView.die()` cancels a cast
in flight, so a unit killed mid-wind-up doesn't die with a ring around it.

If you want the animation longer or shorter, `MIN_CAST_SHOW` sets the floor for
openers and `AbilityData.cast_time` sets it for everything else — and `cast_time`
is a **real simulation cost**, so lengthening it is a nerf, not a visual tweak.

---

## A retinue, not a running total

`summons_made` counted how many a caster had *ever* made, and `summon_cap()`
capped against that. For the Spire that is right — it raises a host once and
spends itself. For the Conjurer it was wrong in two ways at once, and both showed
at tier 6: it opened with **one** wisp instead of three, and once it had made
three over the round it was finished even if all three were dead.

`AbilityData.summon_retinue` marks an ability as a standing retinue instead. Two
things change for it:

- **The cap counts who is standing.** `retinue_size()` walks the unit list for
  living units whose `summoned_by` is this caster. A wisp that dies frees its
  place, so the next full bar replaces it.
- **A cast fills the retinue** rather than making `summon_count` of them. So the
  opener brings a Conjurer straight up to strength — 1, 1, 2, 2, 3, 3 across the
  six tiers, the same ramp the cap always used.

`summon_want()` is the single place that decides how many a cast makes, because
`_resolve_summon()` and `summon_shortfall()` both need the answer and a round
where they disagree is a caster that burns its bar on nothing.

### A Spire never raises a Spire

`Raise Host` rolls two units at random from your own roster. Rolling a Spire
would hand the winner of one cast a free second cast, and that one another. The
filter is written against the mechanic rather than the name — nothing whose
ability spends its caster to summon can be summoned this way — so a future unit
with the same shape is covered without anyone remembering to add it. There is a
test that counts the self-spending summoners in the roster and checks exactly
that many are missing from the pool.

(`_open_now()` already refused to instant-cast a `consumes_caster` ability, which
stopped the *instant* runaway. This stops the slow one.)

---

## Mechanical and biological

Every unit is one or the other. Nothing reads it except the Engineer, and a
unit's chassis never changes — it exists so that "repairs machines" means
something specific rather than "heals whatever is nearby".

**Mechanical: the Sentry and the Spire.** Everything else is biological. Putting
the Spire in gives the Engineer something to do besides tend its own turret, and
an Engineer keeping a Spire alive long enough to raise its host is a real pairing
rather than a coincidence.

## The Engineer and the Sentry

The Engineer opens every round building a Sentry **on the tile it is standing
on**, then steps off and leaves it there.

Four things about it are new machinery rather than new numbers:

- **An opener that takes time.** `_resolve_openers()` normally calls
  `_open_now()`, which has no wind-up in the simulation at all. `Assemble` sets
  `opener_takes_time`, so the opener goes through `_begin_cast()` and takes its
  real 2.5 seconds — during which the Engineer can be killed and the Sentry never
  arrives.
- **A cast that exposes its caster.** The opposite of `guards_caster`, which is
  what makes the Spire invulnerable mid-cast. `exposes_caster = 1.0` doubles
  damage taken for the duration, and `UnitInstance.exposure()` returns 1.0 the
  instant the cast ends.
- **Building on your own tile.** `summon_at_caster` places the summon on the
  caster's cell and steps the caster into the nearest free neighbour, emitting a
  move for it so the view animates the shuffle. With nowhere to step it falls
  through to ordinary adjacent placement rather than wasting the cast.
- **A caster that holds instead of burning.** The Spire burning its bar with no
  room is deliberate — that is the pressure to merge before it is ready. Standing
  exposed for two and a half seconds to produce nothing is not pressure, it is a
  trap, so `Assemble` sets `holds_when_capped` and the previously-unused
  `can_cast()` finally gates `_decide()`. The Spire does not set it, so its
  behaviour is unchanged.

**The Sentry** cannot move and sees the whole board: 45 damage every 3.3 seconds
at tier 1, 1440 at tier 6. It is a `RANGED` unit, so `line_of_fire()` still
applies — a Sentry on the Labyrinth mostly stares at a wall, and on Killing Field
it covers everything. It is hidden from the loadout: built, not drawn.

That unit is also why `rooted` had to become **two** flags. It used to set
`can_move` and `can_attack` together, which was fine when the Spire was the only
rooted thing in the game. The Sentry is bolted to the floor and is the opposite of
harmless, so the builder now takes `rooted` and `harmless` separately and the
Spire declares both.

**Repair is a trait, not an ability** — the Engineer's one ability slot is already
spent on building the thing it repairs. It restores health every second to each
*adjacent* friendly Mechanical unit, and it **holds station with its machines
instead of advancing**. That last part is not flavour: without it the Engineer
steps off its build tile, walks at the enemy, and the repair never fires once,
because the turret it just built is the only mechanical thing on the board and it
is walking away from it. A 130-health, 8-damage body advancing is a donation
anyway.

## The Tyrant

240 health, 40 damage, no ability, and every one of **your own** units within two
tiles takes 30% more damage. The enemy's units standing next to it are unaffected,
and it does not burden itself.

`_burden_on()` is asked at the moment of the hit rather than tracked as aura
state. That means killing the Tyrant lifts the burden instantly, walking out of
its radius lifts it instantly, and there is nothing to clean up at the round
boundary — which is where the shield and mana state all has to be wiped.

The number was measured, not guessed. Running 60 matches of *two of this unit plus
six random* against *eight random*:

| Unit | Inclusion win rate |
|---|---|
| Warden | 82% |
| **Tyrant** | **82%** |
| Spire | 50% |
| Transcendence | 48% |
| Archer | 47% |

At the first value I tried (15% within 2 tiles) it came out at 85% against the
Warden's 82% — the drawback was a rounding error, because units in a random
deployment are rarely within two tiles of each other. At 30% it lands level with
the best body already in the game, which is the point: a genuine alternative to
the Warden rather than an upgrade over it.

---

## The apex beam reloads

Tier 6 Transcendence fires an unlimited-range beam that pierces 100 targets and
washes the rank behind them. It was doing that on the base attack speed, which
made "how often" matter more than "at what", and there is no counterplay to a
board-clearing shot every 1.4 seconds.

The base rate dropped from 0.7 to 0.45 attacks a second, and `apex.spd` is a
**multiplier** applied on top at tier 6 only — 0.5, so the apex fires every
**4.35 seconds** against tier 5's 2.22. It is the slowest thing on the board, and
a test asserts that against every other unit's tier 6 rather than against a
number, so it stays true if something else is slowed later.

---

## Nothing summoned goes missing

A unit that an ability paid for must end up on the board. Three rules make that
true, and each one was a bug before it was a rule.

**1. The search is the whole board, not one ring.** A revive used to look only at
the eight tiles around where the unit fell; on a busy board it found nothing and
the Revenant was deleted mid-resurrection. `CombatSim._any_free_cell()` now walks
every free tile nearest-first (`BoardModel.by_distance_to()`, with a deterministic
tiebreak so the seeded sim stays reproducible).

**2. Summons are all or nothing, and placement is per ability.**
`_summon_cells()` reserves every tile the cast needs before a single minion is
created. `AbilityData.summon_adjacent` decides where from: **Raise Host** takes the
free tiles **nearest the Spire first** (`BoardModel.by_distance_to`) so a host
arrives at its parent's shoulder, while **Call Wisp** scatters at random across the
Conjurer's own half, which is what keeps a clump of wisps out of one Cinder Lance.
Either way it only reaches further out when the nearer tiles are taken.
If it cannot reserve them all it returns nothing and the cast is wasted — visibly,
with a `reason` on the event and a red **NO SPACE** / **NO ROOM** label on the
caster. Six Spires firing means twelve units, and each cast takes the space it
needs or takes none.

The reservation is deterministic — no RNG at all — so a summon lands in the same
place for the same seed, and a boxed-in summoner gets the next ring out rather
than a random tile across the board.

Before this, `_summon_cell()` picked one tile at a time from the caster's own half
and gave up silently when that half was full. On a crowded board a Spire could
burn fifteen full bars in a round and put nothing on the field.

**3. A summon that outlives the round is measured against the round, not the
moment.** `Raise Host` sets `AbilityData.summon_persists`, which does two things:
the minion is marked `UnitInstance.permanent` and joins your roster for good, and
the cast is gated by `CombatSim.persist_room()`:

```
half capacity (30) - units that started the round - recruits already raised
```

Not "free tiles right now". Those differ the instant anyone dies, and a Spire that
filled the gaps left by corpses would hand you a roster too big for your own half
next round. So a Spire on a **full half raises nothing, ever** — merge first, or
it is a statue. That is the intended pressure, not a limitation.

`main.gd._absorb_recruits()` appends the recruits to `_roster` after the sim
resolves, with no cell: `_restore_roster()` gives them a free tile in their own
half, which `persist_room()` already guaranteed exists. Recruits that died in the
battle come back like everyone else.

---

## Spending a caster, and banking a bar

Two flags make the Spire a one-shot investment rather than an engine.

**`AbilityData.consumes_caster`** — after a successful cast, `_consume_caster()`
zeroes the caster's health, takes it off the board and emits a `death` with
`killer_uid = -1` and `consumed = true`. It is deliberately not routed through
`_damage()`: no lifesteal is credited, and `_try_queue_revive()` never sees it, so
nothing brings it back. `UnitInstance.consumed` survives `reset_for_battle()`, and
`_absorb_recruits()` drops consumed units from `_roster` in the same pass that
adds the recruits. A Spire trades itself for two units of its own tier.

A **wasted** cast does not spend the caster — only a cast that actually put units
on the board.

### Holding the bar instead of burning it

`_begin_cast()` spends mana the instant a cast *starts*, long before a summon finds
out there is no room. With a banked bar that meant a Spire on a crowded board
burned a full bar every thirteen seconds and produced nothing.

So `_decide()` now asks `can_cast()` first. For a summon, `summon_shortfall()`
returns `capped`, `no_home`, `no_room` or empty — **counted, never sampled**, because
probing with `_summon_cells()` would consume the seeded rng and desync every roll
after it. A unit that cannot land its summon simply holds a full bar and fires the
moment you make room by merging. The wasted-cast path stays as the safety net: the
board can change during the wind-up.

### Guarded casts

`AbilityData.guards_caster` makes `UnitInstance.is_invulnerable()` true for the
whole cast, and `_damage()` returns early with a `blocked` event instead of a
`damage` one. Raise Host has a 1.4s wind-up it cannot be killed during, so a Spire
that has waited rounds for a full bar always gets to spend it. The view draws a
blue shell around a guarded caster and flashes the unit white on each blocked blow.

**`UnitData.keeps_mana`** — `reset_for_battle()` skips the `mana = 0.0` line for
these units, so the Spire's progress is cumulative across rounds. That is the
only reason a Spire is worth fielding on a board too crowded to fire this round:
it is still filling. Everything else starts every round on empty.

Because `setup()` calls `reset_for_battle()` on every unit, the bank survives the
start of a battle too — a Spire that ended last round at 80 casts about three
seconds in.

---

## Units that don't fight

Two flags on `UnitData` let a unit sit out the parts of combat everything else
does. Both default to `true`:

| Flag | Effect |
|---|---|
| `can_move` | `false` means it never takes a step, ever. |
| `can_attack` | `false` means it never swings, so it never earns attack mana. |

`UnitInstance.can_act()` is `can_attack or can_move`. `CombatSim._decide()`
checks the full-mana cast **first** and only then bails on `can_act()`, which is
the whole trick: the **Spire** never moves and never attacks, but it still casts.
Reverse those two checks and it stands there forever.

A unit with `can_attack = false` needs another mana source or its ability is
dead weight — the Spire has `mana_per_second = 8.0` for exactly that reason.

---

## Wild merging, per unit

`BoardModel.can_merge()` answers yes when *any* of these hold, given matching
teams and tiers and a mergeable tier:

1. the two units are the same type (the ordinary case),
2. the team holds **Alchemy** (`wild_merge_teams`), or
3. **either unit** has `UnitData.wild_merge` set.

Case 3 is the **Amalgam**: it merges with anything you own at its tier, without
Alchemy, and it works from either side of the pair. What comes out is still the
merge lottery's business — unless a `merge_magnet` (the Transcendence) is
involved, which wins over everything.

---

## The round-end hold

When the last unit on one side falls, the board **stops where it is** for
`ROUND_END_HOLD` seconds (1.8 by default, in `main.gd`) under a ROUND WON / ROUND
LOST / DRAW banner. Only then does `_conclude_round()` restore the roster and move
to the next round. Without it the winning units teleport home the instant the
killing blow lands, and you never see how the fight actually ended.

`round_end_hold` is a plain variable rather than a constant so `tools/smoke_test.gd`
can drop it to 0.2s; the test also asserts the shipped default is at least a second.

---

## Modes

`scenes/menu.tscn` is the main scene. It sets two things on the `GameSetup`
autoload and then loads `main.tscn`, which reads them:

| Mode | Who plays | Prep |
|---|---|---|
| Battle the Computer | you are the bottom half, the computer takes the top | one prep turn |
| Local PvP | both halves are human, on one screen | two prep turns with a blind between |

`GameSetup` survives the scene change — that's the whole reason it's an autoload
rather than a value passed into `main.tscn`. It holds the mode, the unit catalogue,
and each side's five loadout slots. `main.gd` asks it for names (`team_name()`),
so the same code prints "You / Computer" or "Player 1 / Player 2" without
branching everywhere.

### Loadouts

Five slots per side, each cycling through the **fourteen** unit types. **Repeats are allowed and
are the point** — three Archers in your five means you draw Archers about 60% of
the time *and* your merge lottery rolls Archer 3 times in 5, because merging rolls
from the same list. `BoardModel.set_team_pool()` keeps the two lotteries separate;
`pool_for()` falls back to the shared pool when a team hasn't set one, which is why
every existing test still passes untouched.

### The local PvP blind

**Player 1 is the bottom half, Player 2 the top, always.** The order never
alternates: buff picks (when due) run Player 1 then Player 2, then prep runs
Player 1 then Player 2, every round. `GameSetup.turn_order()` is the single place
that order is written down, and `player_number()` is the single place the
bottom-is-P1 mapping lives.

Both draws are dealt at the start of prep, then each player takes a turn:

1. **Player 1** (bottom half) arranges, with fog hiding Player 2's units. Button says **Done**.
2. **The screen blinds** — an opaque cover naming who is up next, with Ready locked
   behind a `BLIND_SECONDS` countdown (2.5s) so nobody can rush it while the last
   player is still looking.
3. **Player 2** (top half) arranges, with fog now hiding Player 1. Button says **Fight**.

Nothing about the layout swaps between turns. Each player's buff strip stays on
their own half and keeps their own name — the bottom strip is always **P1**, the
top always **P2** — and the scoreboard always reads "Player 1 x – y Player 2" in
that order, whoever is currently arranging. The only thing that changes is a
highlight on the active player's strip and a "Player N is arranging" note in the
HUD. Labels that follow the viewer instead of the owner are exactly what made this
confusing the first time round.

`_board_view.player_team` is what makes the fog follow the active player — it is set
per prep turn and reset to the bottom half when the battle starts, so the replay is
fully visible to both. Ownership checks in `main.gd` all go through `_active_team`,
never `PLAYER_TEAM`, which is what stops Player 1 dragging Player 2's units.

The board is **not** flipped for Player 1; they arrange the top half as drawn. Doing
it properly means a per-player view transform, which is real work and would have
made this change much bigger.

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

**For most units, mana comes from landing attacks and nothing else.** A unit
that can't reach anything never charges. That's deliberate: it makes protecting
your damage dealers matter, and it means a Warden buried at the back is
contributing less than it looks.

There are now two other taps, both once-a-second and both on `UnitData`:

- `mana_per_charge` every `mana_charge_time` seconds — the unit charges on its
  own clock. The **Spire** runs on 8 a second and nothing else, since it cannot
  attack at all. Buffs raise the **size** of a charge, never its rate, so
  Incubation reads "+3 mana a charge". `mana_charge_time` is 1.0 across the whole
  roster right now; it is the dial for a unit that should gather more slowly.
- **Mana auras** — a `MANA_AURA` ability registers its caster in
  `CombatSim._mana_auras` and, on each of the caster's charges, hands
  `caster.mana_per_charge()` to every ally inside the box. That is the
  **Wellspring**: its `mana_per_charge` is not self-charge, it is the *output* of
  the pool it stands in.

The regen tick still runs once a second for everyone; `CombatSim._charge_due()`
holds a per-unit `mana_clock` so a unit can charge slower than that tick without
the tick itself slowing down. A charge time under one second is not possible —
the clock is only consulted once a second.

One consequence worth knowing: an active aura caster is **skipped** by
`_tick_mana_regen`, so its regen goes entirely into the zone and it never
re-casts a pool it has already opened. Remove that skip and the Wellspring spends
the whole battle recasting instead of shooting.

The aura uses `board.units_in_box()` (Chebyshev), not `tile_distance`
(Manhattan). A 3x3 zone is a *box*: the diagonal neighbours are in it. Manhattan
distance would silently drop the four corners and make the pool a plus sign.

Casting locks the unit in `CASTING` — no attacking, no moving — for `cast_time`.
Same exposure rule as committing to a tile step. A free bonus action would
undercut the positioning game the whole design rests on.

| Unit | Ability | What it does | Rate |
|---|---|---|---|
| Amalgam | *(none)* | **Merges with any unit of the same tier, whatever it is** — a personal Alchemy. No ability, no mana bar. | — |
| Spire | Raise Host | **Cannot move, cannot attack.** Gathers 8 mana a second, **keeping the bar between rounds**, and on a full bar raises **two units at random from your own roster at its own tier**, beside itself — or none at all. What it raises is **yours for the rest of the match**, and raising it **spends the Spire**: it dies on the spot and never comes back. | — |
| Wellspring | Overflow | Opens a **3x3 mana pool** around itself on the first beat. Every ally standing inside gains **6 mana a second**, all battle. | — |
| Warden | Bulwark | Shield worth **125% of max health**, absorbed before health, **never healed**. Up before the first tick. | 20 |
| Lancer | Impale | Strike through 3 enemies at 210% damage. **Passive: ordinary swings already hit 2.** | 25 |
| Archer | Quickdraw | +16% attack speed, permanent, stacking to 6. | 25 |
| Vexer | Blight | 11 damage every 0.5s, 6 times, on one enemy. Keeps ticking while the Vexer shoots elsewhere. | 12 |
| Pyre | Cinder Lance | 78 to the main target, 16 to everything within 1 tile of it. | 34 |
| Assassin | Shadowstep | Blinks behind the **deepest enemy on the board** for 46 damage, doubling every tier (1472 at tier 6), then cannot be targeted for 3.5s. | 25 |
| Herald | War Horn | The **four orthogonally adjacent** allies at the opening bell gain 12% attack speed per tier, all battle. | 30 |
| Revenant | Second Wind | 50% chance to get back up 1s after **every** death, at full health, no cap. | 25 |
| Seraph | Benediction | On a full bar, heals the **worst-hurt** ally within 3 tiles for 45% of max health, +20% of that per tier. | 34 |
| Transcendence | *(none)* | **Any merge it touches comes out an Transcendence.** No ability, no mana bar. At tier 6 every ordinary attack is a **beam**: full damage to everything in the line to the board edge, half to everything within a tile of it. | — |
| Conjurer | Call Wisp | Opens with a Wisp anywhere in its half and calls more on every full bar. **Wisps match its tier.** Cap is 1 at tiers 1–2, 2 at 3–4, 3 at 5–6. | 26 |

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

### Battle-start abilities resolve in `setup()`, not through a cast

Anything with `casts_at_battle_start` fires **before the first tick**, on the
formation the player actually built. This matters more than it sounds: the Herald's
horn used to run through the normal 0.3s cast, by which point the ally standing
next to it had already taken its first step and walked out of range, so the aura
buffed nobody. Resolving openers in `setup()` fixes that and makes the Warden's
shield genuinely instant, which is what it always claimed to be.

### Stealth and how targeting works

`_decide()` re-picks `board.nearest_enemy(u)` every time a unit is idle, and
`nearest_enemy()` skips anything with `is_hidden()`. So a stealthed Assassin isn't
"untargetable" by some special rule — it simply never comes up as the nearest
enemy, and units already busy with someone else have no reason to look for it.
That's the whole mechanic.

The consequence to watch: if **every** enemy is hidden, the other side has no
target and idles until stealth expires. Stealth is short for exactly that reason.
Lengthen `stealth_time` far enough and you get stalled battles decided on the
`DEFAULT_TIMEOUT` health check.

### A revived Revenant is a brand new unit

A dying Revenant still emits `death` and leaves the board — then goes into
`_respawns` and comes back a second later at its old cell (or the nearest free
one), at full health, **with no limit on how many times**. `_check_over()` counts
pending respawns, or a battle would be called while someone was still on their way
back up.

Treat what comes back as a **new unit on the field**, because mechanically it is:

- Everything targeting it lost its target when it left the board. Since `_decide()`
  re-picks the nearest enemy, whoever killed it will often walk off after somebody
  else and have to come all the way back.
- Its battle state is wiped — mana, shield, poison, haste stacks, stealth, and any
  Herald horn it was standing in. Team-wide battle modifiers (Full Muster) are
  re-applied from `_team_battle_mods` so a team buff isn't silently lost.
- Persistent buffs (the ones you picked in a buff round) stay, because those live in
  `modifiers`, not `battle_modifiers`.

The practical effect is that a Revenant is a tarpit: killing it costs the enemy the
tempo of re-acquiring a target, and half the time it does that to them twice.

### Summons change the unit list mid-battle

Summoned Wisps are appended to `_pending_units` and folded into `_units`/`_order`
at the **end** of the tick, never during the loop that is iterating `_order`.
They're built from the same `UnitInstance.create()` as anything else and get the
team's stat buffs applied, so War Drums speeds up your Wisps too.

Neither survives the round: `_restore_roster()` rebuilds the board from the roster
snapshot taken at battle start, and a Wisp was never in it.

---

## The Transcendence

A deliberate outlier: medium range, 165 health, 22 damage, no ability at all. Its
whole identity is the `merge_magnet` flag — `BoardModel.magnet_of()` checks both
sides of a merge and, if either is a magnet, skips the merge lottery entirely and
returns that unit's own `next_tier`. So an Transcendence is never lost to a bad roll, and
with Alchemy it eats anything of its tier.

At **tier 6** it enters its apex state, authored through the `apex` block on its
row in `UNIT_TABLE`: health and damage ×4 on top of the usual ×32 (21120 and 2816),
**Unlimited** range, and 99 pierce. Tiers 1–5 are an ordinary medium-range body.

The `apex` block is generic — any unit row can carry one, and it only applies at the
top tier.

---

## Maps

The board is no longer one fixed shape. `data/maps/*.tres` holds a `MapData` per
board — width, height, whether there is a neutral divider, and its terrain — and
there are **thirty-three** of them. You pick one at the top of the loadout menu.

Maps load off disk alphabetically, which put Standard somewhere in the twenties,
so each one carries a `rank` stamped from its position in `MAP_TABLE` and the
menu sorts by that. The table's order is therefore the menu's order, and it runs
roughly simple to strange: plain rectangles, then open ground with high places on
it, then loose cover, then structure, then something worth holding, then the
boards cut up by holes, then the three awkward ones at the end.

| Map | Shape | Divider | Terrain | Character |
|---|---|---|---|---|
| Standard | 6 x 11 | yes | — | The original. 30 tiles a side. |
| Skirmish | 6 x 8 | **no** | — | Short and undivided; the front ranks start in each other's faces. |
| The Pit | 4 x 9 | yes | — | 16 tiles a side. Merge or drown. |
| Broad Front | 9 x 11 | yes | — | Wide, with a long walk to the enemy. |
| The Crush | 8 x 6 | **no** | — | Wide and shallow; almost everything is in range at once. |
| The Long March | 5 x 15 | yes | — | A deep corridor. Archers get to work for a long time. |
| The Duel | 3 x 7 | yes | — | Nine tiles a side. No flank, no cover, nowhere to put a mistake. |
| Killing Field | 13 x 9 | yes | high ground | Wide and shallow with a firing step at both backs. |
| The Steppes | 11 x 13 | yes | high ground | Open ground in terraces; every ridge is a range band. |
| The Cauldron | 11 x 11 | yes | high ground | A rim of high ground round a low floor. |
| The Quarry | 9 x 11 | yes | walls | Loose stone; no shot crosses the board cleanly. |
| The Shatter | 9 x 11 | yes | holes | The Quarry with holes where the stone was — same walk, no cover. |
| The Grove | 7 x 11 | yes | walls | Pillars the whole way down. No clean shot anywhere. |
| The Warrens | 6 x 11 | yes | walls | Stone blocks break each half into lanes. |
| The Spine | 9 x 11 | yes | walls | One wall down the length with three doors through it. |
| The Ring | 9 x 11 | yes | walls | A block in the dead centre. Two flank fights that cannot help each other. |
| Three Roads | 11 x 13 | yes | walls | Three walled lanes meeting only behind each side's own lines. |
| Four Corners | 11 x 11 | yes | walls | Two rooms a side, one gate each, one hallway across the middle. |
| The Gauntlet | 7 x 13 | yes | walls | Alternating baffles. Nothing sees down it; crossing takes twice the steps. |
| The Highlands | 6 x 8 | **no** | walls, high ground | No divider, a boulder each side, a ridge at both backs. |
| The Keep | 9 x 11 | yes | walls, high ground | One fortress, dead centre, two doors. Whoever gets in owns the middle. |
| The Redoubt | 9 x 11 | yes | walls | A walled fort each end with two gates and a road around it. |
| The Anvil | 9 x 11 | yes | holes, high ground | A high plateau in a dry moat, one ramp each side. |
| Ramparts | 7 x 11 | yes | barriers, high ground | Thickness-free barriers pinch the middle to three columns. |
| Crossroads | 11 x 11 | yes | holes | A plus. Narrow approaches into a middle the full width of the board. |
| The Bridge | 7 x 11 | yes | holes, high ground | Two shores and a three-wide crossing, overlooked from both banks. |
| The Hourglass | 9 x 11 | yes | holes, high ground | Wide at the ends, three tiles across in the middle. |
| The Chasm | 9 x 11 | yes | holes, high ground | A trench end to end, crossable only at the two flanks. |
| The Shoals | 11 x 11 | yes | holes | Islands joined by one-tile necks, every one of them in plain sight. |
| The Causeway | 7 x 15 | yes | holes | Single file for eight rows, in full view of both shores. |
| The Cage | 7 x 11 | yes | barriers | Every barrier waist-high: shoot the whole board, walk almost nowhere. |
| The Labyrinth | 9 x 25 | yes | walls | A real maze. Open staging at both ends, one tile wide the whole way through. |
| The Compound | 12 x 21 | yes | walls, high ground | The biggest board. 81 tiles a side, cut into rooms, four gates across the middle. |

### Terrain

A map may carry a `rows` grid — one string per row, top first — and a `lines`
list. Four glyphs:

| Glyph | Means | Takes a tile | Blocks movement | Drawn |
|---|---|---|---|---|
| `.` | open ground | — | no | normal tile |
| `#` | a solid wall | **yes** | yes | a stone block |
| `X` | a hole | **yes** | yes | **nothing** — this is what makes a board stop being a rectangle |
| `^` | high ground | no | no | a tinted tile with a chevron |

`lines` are the other kind of wall: **barriers that sit between two tiles rather
than on one**. Packed as `Vector4i(ax, ay, bx, by)`, they block the step across
without costing either tile. Ramparts uses eight of them to pinch an 7-wide board
down to three columns while every tile stays usable and deployable.

### The Labyrinth is a real maze

The first Labyrinth was a serpentine — one long snake of corridor with no
choices in it. It read as a maze but played as a queue. It is now generated the
way a maze actually is: a depth-first carve over a 4 x 9 lattice of cells,
knocking out the wall between neighbours as the walk visits them, which gives
**exactly one path between any two points** and no loops to shortcut.

The top and bottom three rows are left **completely open**. Both sides stage on
a clear field, see their own formation, and only then feed into the corridors —
so the maze is the battlefield, not the deployment zone. Between those fields
the board is one tile wide almost everywhere: 126 open tiles out of 225, ten
junctions, and only two ways through the middle row.

That shape changes the game rather than decorating it. A melee unit in a
one-wide corridor is a cork — nothing gets past it, and nothing behind it can
help. Ranged units cannot shoot through `#`, so a corridor fight is always the
front two units and no one else. Merging up before you commit matters more here
than on any other board, because a wide, shallow army has nowhere to be wide.

The carve is verified before it ever reaches the builder: mirror-symmetric,
fully connected by flood fill, 62 usable tiles a side.

### What stops a shot

| | Stops a step | Stops a shot |
|---|---|---|
| `#` solid wall | yes | **yes** |
| `X` hole | yes | no — you can fire across a gap |
| barrier (`lines`) | yes | no — waist-high, shoot over it |

`BoardModel.line_of_fire()` walks a Bresenham line between the two tiles and
fails on the first `#` in the way. It runs from a **canonical end** — the
lexicographically smaller cell — so "A can shoot B" and "B can shoot A" can never
disagree over a rounding tie. There is a test that checks that symmetry across
every vertical pair on the Labyrinth.

Only **ranged units** are gated on it (`UnitInstance.is_ranged()`, the same
`attack_type != MELEE` predicate high ground uses). A melee unit is standing next
to whatever it is hitting, so there was never a wall in between.

Targeting is deliberately **not** gated on sight. `nearest_enemy()` still picks
the closest enemy through a wall, and `_decide()` sends the unit walking when it
has no shot — otherwise a ranged unit behind stone would have no target and stand
there forever. Pierce stops at the first wall, and so does the apex beam.

### Tiers you can tell apart

Six tiers of the same unit used to differ only by two characters in a corner
badge. `UnitView.tier_color()` now gives each tier its own colour — steel, green,
blue, violet, **yellow, red** — used three ways at once: the corner badge becomes a
solid chip of it, an inner rim inside the team ring thickens as the tier climbs,
and a row of **pips along the bottom edge counts the tier** so you can read it
without reading. The body fill takes a little of the colour too, so a tier 6
looks hotter than a tier 1 of the same unit without losing its identity.

A test asserts no two tier colours are within 0.3 of each other in RGB, so
"make T5 a bit more orange" can never quietly collide with T6. Two more assert
that T5 is yellow and T6 is red specifically — the top two are the ones players
scan for, so which is which is a choice, not an artefact of list order.

### High ground

Standing on `^` gives a unit **+1 range band** — but only if it shoots.
`UnitInstance.reach_on(high)` adds the band when `attack_type != MELEE`, so
Archers, Vexers, Pyres, Seraphs and Wellsprings all gain from a ridge and every
melee unit gains nothing. It stacks with Far Sight, which means an Archer with a
gold Far Sight standing on high ground goes Long → Sniper → **Unlimited**.

The sim asks `u.reach_on(BoardModel.is_high(u.cell))` when deciding whether to
shoot or walk, so the bonus applies where the unit *is*, moment to moment — walk
off the ridge and you lose it.

### Picking one of thirty-three

Thirty-three boards do not fit behind a `<` and a `>`. The picker is a scrolling
grid of `MapChip`s — each one a small `MapPreview` of the board's real shape with
its name under it — and the chosen one's summary, note and terrain breakdown show
underneath. You choose by recognising a silhouette rather than by clicking
thirty-two times, and the shapes are distinct enough that this actually works.

The chips are a `ButtonGroup`, so exactly one is lit; `_refresh_map()` re-lights
from `GameSetup.map_index` rather than trusting the click, so a map selected from
anywhere else still shows correctly.

The grid is 216 pixels of scroller inside a panel that already held two loadouts
and a detail pane, and adding it pushed **Done off the bottom of the screen** —
which left no way out of the menu at all. The editor is now a fixed title, a
scrolling body, and a fixed button row: whatever else goes into it, the way out
stays pinned. A test walks the editor for its buttons and asserts both are inside
the viewport, and it fails on the version that shipped broken.

`menu_smoke_test` picks **every** map in the grid and checks the board that comes
up is the one asked for. That matters because `BoardModel.use_map()` silently
falls back to the default board when handed an invalid map — without this check a
broken map would look like a working Standard.

### The fairness rule

`MapData.invalid_reason()` returns a sentence, not a bool, and the builder prints
it. It enforces four things:

1. **`has_neutral == (height is odd)`.** An odd board splits into two equal
   halves *and* a leftover middle row, so the divider is that row. An even board
   splits evenly on its own, so a divider would steal a rank from one side.
2. **The terrain grid mirrors itself.** For every cell, `glyph(c)` must equal
   `glyph(mirror(c))`. Without this a map can hand one side better cover before a
   single unit is placed.
3. **Every barrier has its mirror**, and runs between two adjacent, on-board
   tiles that are not both walls.
4. **At least 8 usable tiles a side**, so a draw is never impossible.

`GameSetup.reload_maps()` refuses to load an invalid map, and the model suite
walks every map on disk and checks its halves match, its tiles are all reachable,
and a whole battle resolves on it.

### The camera

A 9 x 25 maze at a readable tile size is taller than the window. The old
behaviour was to shrink the tile until the whole board fit, which on the
Compound and the Labyrinth produced tiles too small to tell a Warden from a
Wisp. `BoardView.MIN_TILE` is now 56 px: **a big board overflows instead of
shrinking**, and you move the camera to see the rest.

- **Drag** anywhere on the board that isn't one of your own units. `_begin_drag`
  already had to decide between "pick up a unit" and "do nothing"; "do nothing"
  became "pan". Dragging off the edge of the board but still inside the window
  pans too.
- **Arrow keys** pan by `KEY_PAN` (46 px) a press.
- At the start of your prep, `main.gd._look_at_half()` centres the camera on
  **your** half, so you never open a round looking at empty enemy ground.

`view_area` is the window the board is seen through; `position` is where the
board currently sits relative to it. `pan_limits()` clamps the offset so you can
always reach both edges and never scroll past them, and an axis that already
fits is centred rather than panned — so on the Standard board the camera never
moves at all and nothing about it changes.

**The camera is not part of taking your turn.** `BoardView.interactive` goes
false the moment the fighting starts — there is nothing to pick up mid-battle —
and `_unhandled_input()` used to return on that flag before it reached any of the
pan handling. So a 25-row board froze on whichever third you happened to be
looking at for the whole fight. Only the drag-a-unit path is gated on
`interactive` now; the keys and the camera-drag always run.

**The HUD belongs to the window, not the board.** Every bar, roster and banner
around the board was laid out from `_board_view.position` and `board_size()`.
That is the same thing as `BOARD_AREA` on the Standard map, which is why it
survived this long — but the Labyrinth's board is 1400 pixels tall, so the
player's own buff bar landed at y=1540 and their roster at y=1570, both off the
bottom of a 1280-tall screen, both sliding further away with every pan, and the
force bar was sized 74 x 1400. They are all laid out from `BOARD_AREA` now, and
`map_smoke_test` builds a whole Main on the Labyrinth and asserts every piece of
the HUD is on screen, is not taller than the screen, and does not move when the
camera does.

Two consequences worth knowing:

- **`BoardMask`** paints the four bands outside the window. The board is a
  Node2D in the world and the HUD is a `CanvasLayer` over it, so the mask goes
  in as the first child of `UI/Root` — over the board, under the HUD. It is the
  cheapest honest clip available short of moving the board into a SubViewport.
- **The inspector covers the window, not the board.** `UnitInspector.bind()`
  sizes itself to `view_area`, and `to_board()` converts a point on it back into
  board space. Anything that hit-tests units has to do that conversion now —
  this is exactly what broke three smoke-test checks when the camera landed, and
  the test now converts instead of assuming the two spaces coincide.

### Why the dimensions are static, not const

`BoardModel.WIDTH`, `HEIGHT`, `NEUTRAL_ROW` and `HAS_NEUTRAL` are **static vars**
now. `BoardModel.use_map()` sets them; `BoardModel.reset_map()` puts the default
back. Only one board is ever live, so a single shape is not a real constraint —
and keeping the names meant several hundred `BoardModel.WIDTH` references across
the sim, the view and the tests kept working untouched.

The cost is that they are global: **any test that changes the map must put it
back**. `_test_maps()` calls `reset_map()` when it finishes, and so does the
undivided-map scene test, or every suite after them would run on the wrong board.

### Deploy rows

`first_row()` and `last_row()` are the only places that know about the divider:

```
A: rows 0 .. NEUTRAL_ROW-1
B: rows NEUTRAL_ROW+1 .. HEIGHT-1     (divided)
   rows NEUTRAL_ROW   .. HEIGHT-1     (undivided — the halves touch)
```

`is_neutral()` returns false everywhere on an undivided map, which is what makes
`can_deploy()`, the tile colouring and the "nothing sits in the neutral row" rule
all do the right thing without any of them special-casing anything.

### The pathfinder had to be rewritten

`AStarGrid2D` can mark a *tile* solid. It has no way to say "these two open tiles
are not connected", which is exactly what a barrier is. So `CombatSim._next_step()`
now runs its own BFS: a distance field flooded out from the target across tiles
that are unblocked, unoccupied and not barrier-separated, and the mover takes the
neighbour with the lowest distance.

It is a 135-tile board at worst, so this is cheaper than it sounds, and it is
fully deterministic — neighbours are visited in a fixed order and ties go to the
first. `_greedy_step()` is still the fallback when the target is walled off
entirely.

### Fitting any board to the same screen

`BoardView.fit_to(area)` picks `tile_size` from whichever axis is tighter and
centres the result, so every map draws into `main.gd`'s `BOARD_AREA` — the same
504x924 slot the 6x11 board always used. The HUD, buff strips, roster strips and
force bar are all positioned from `board_size()` afterwards, so none of them move
when the shape changes. The Pit gets 102px tiles; Broad Front gets 56px.

---

## Range bands

Attack range is a **band**, not a raw tile count. `UnitData.RangeBand`:

| Band | Value | Reaches | Who has it |
|---|---|---|---|
| Melee | 1 | 1 tile | Warden, Lancer, Assassin, Herald, Revenant, Wisp, Amalgam, Spire\* |
| Medium | 2 | 2 tiles | Vexer, Pyre, Seraph, Conjurer, Wellspring |
| Long | 3 | 3 tiles | Archer |
| Sniper | 4 | 4 tiles | — reserved |
| Unlimited | 5 | the whole board (`UNLIMITED_TILES`, 100) | T6 Transcendence |

\* The Spire's melee band is bookkeeping only — it has `can_attack = false`, so
its range never comes up.

Sniper and Unlimited are deliberately unused by the starting roster: they are what a range
buff promotes you *into*. A `+1` `ATTACK_RANGE` modifier moves a unit one band, so
Archer → Sniper, and a second one makes it a board-wide threat. Stacking past
Unlimited does nothing.

`UnitData.band_tiles()` converts a band to tiles and clamps garbage, so 0 reads as
Melee and 99 reads as Unlimited. **The sim asks `UnitInstance.attack_reach()`, never
the raw stat** — the raw stat is the band number, and treating band 5 as "5 tiles"
would quietly halve an unlimited unit's reach. `range_name()` is what the prep
inspector and loadout editor print.

Bands never change with tier: merging makes a unit hit harder, not further.

---

## Movement is orthogonal

Units step to one **orthogonally adjacent** tile at a time. No diagonals, ever.

Two separate constants control this, and they answer different questions:

| Constant | What it governs |
|---|---|
| `DIAGONAL_MOVEMENT` | Whether a unit can step diagonally. Now `false`. |
| `DIAGONAL_RANGE` | Whether *distance* counts a diagonal as 1. Now `false`. |

They're split on purpose. With both `false` the grid is strict — **a melee unit
cannot hit the enemy standing diagonally beside it**, because that tile is two
steps away. Setting `DIAGONAL_RANGE` back to `true` while movement stays
orthogonal gives units diagonal reach they can't step into; that's a common
roguelike setup and a real design choice, not an oversight.

Be aware what the range metric change did to reach. Distance is Manhattan now,
so an Archer's range of 4 covers a **diamond of 41 tiles** rather than the 9x9
square of 81 it covered under Chebyshev. Every range in the game got roughly
half its old footprint without a single number changing. Retune ranges before
you retune anything else.

Pathing also got harder: four-way movement means units can't slip diagonally
past each other, so a crowded board congests more and battles run longer.

## Displacement

`BoardModel.push()` and `BoardModel.teleport()` are the primitives for forced
movement — knockbacks, pulls, leaps. `CombatSim.displace()` wraps them and emits
a `displace` event that playback animates.

Displacement is deliberately **not** `_begin_move()`. It's something done *to* a
unit, so it ignores deploy zones, costs no `move_time`, and doesn't lock the unit
out of attacking. A unit caught mid-step is dropped back to `IDLE`, because its
committed destination is meaningless once something has thrown it elsewhere.

A push stops at the board edge or the first occupied tile, so shoving someone
into a wall of bodies moves them nothing.

Nothing calls it yet — it's tested plumbing. Adding a knockback ability is a new
`AbilityData.Kind` and one case in `CombatSim._resolve_ability()`.

## Six tiers, doubling

Each merge doubles **health and damage**. Tier 6 is 32x a tier 1.

Attack speed, move time and range deliberately do **not** scale:

- Doubling attack speed would compound with the damage doubling and put tier 6
  at over 1000x the damage-per-second of a tier 1. Move time is
  lower-is-better, so doubling it would make a merged unit worse.
- Doubling range would give a tier-6 Archer a reach of 128 tiles on a board 11
  deep — it would hit anything, anywhere, from spawn.

Power scales. Tempo and reach don't.

### The counting problem

2-to-1 merging means a tier N costs **2^(N-1)** tier-1 units:

| Tier | Units | Tier | Units |
|---|---|---|---|
| 2 | 2 | 5 | 16 |
| 3 | 4 | 6 | **32** |
| 4 | 8 | | |

A whole match hands you 5 units a round over at most 7 rounds — **35 units**.
Tier 6 therefore costs 32 of a possible 35: reachable only at full stretch, in
the longest match, with the merge lottery cooperating. That's why the cap is 6
and not 7 — tier 7 would cost 64 and could never appear at all.

`run_tests.gd` asserts the top tier stays reachable, so if you change
`UNITS_PER_DRAW`, `WINS_NEEDED` or `TIERS`, it'll tell you when the ceiling
becomes dead content.

The merge lottery makes it much worse than that. Two units only merge if they are
*identical*, and each merge rolls a random type, so building toward one high-tier
unit is fighting the randomness the whole way. Realistically you'll see tier 3
often, tier 4 sometimes, tier 5 rarely, and nothing above it.

Levers, if you want the top tiers to actually appear:

- **`MatchState.UNITS_PER_DRAW`** — more units per round is the bluntest fix.
- **`MatchState.WINS_NEEDED`** — longer matches mean more draws.
- **Weight the merge pool** toward the merging unit's own type, so building is
  possible at all. Currently uniform across five types.
- Or leave it, and treat tiers 5 to 7 as something that only happens in a long
  custom game. Dead content, but harmless.

Also worth watching: a 32x spread means a high-tier unit is untouchable by
low-tier ones, and a mismatched fight will run to `DEFAULT_TIMEOUT` and be settled
on remaining health rather than by anyone dying.

## Data files link, they don't embed

Every `.tres` under `data/` must **reference** the files it depends on, never
carry inline copies of them. `run_tests.gd` asserts this, because when it broke
nothing looked wrong at runtime — the loadout simply read its own private copies
and every number tuned in the inspector was silently ignored.

The trap, if you ever write your own generator: `ResourceSaver.save()` does not
set `resource_path` on the object it just wrote, and `FLAG_CHANGE_PATH` doesn't
either. Until an object knows its own path it still looks anonymous, so anything
referencing it gets it embedded. `take_over_path()` after saving is what fixes it.

You can spot the failure by eye — a healthy `starter.tres` is under a kilobyte
and lists `ext_resource` lines pointing at `data/units/`. The broken one was
14KB of inline copies.

## Footguns the code no longer explains

The source has no comments in it, by request. These are the things those comments
used to warn about — every one of them was a real bug, not a hypothetical.

| Where | The trap |
|---|---|
| `board_model.gd` | `all_units()` returns a **snapshot**; `units_view()` returns the **live** array. Hold the live one across anything that adds or removes a unit and your indices run off the end. |
| `battle_player.gd` | Never read `cell` or `current_hp` off a `UnitInstance` during playback. The sim already finished, so those hold end-of-battle values. |
| `unit_instance.gd` | Battle-only stat changes go in `battle_modifiers`, never `modifiers`. The latter persists across rounds. |
| `unit_instance.gd` | `heal_to_full()` deliberately leaves `shield` alone. Shields are not healed. |
| `combat_sim.gd` | `_pierce_beyond()` walks the line from the **victim**, not the attacker. A diagonal step never lands on an off-axis target's tile. |
| `board_model.gd` | `can_merge()` must never call `roll_merge_result()` — it consumes the RNG, so checking would change the outcome. |
| `data_builder.gd` | `take_over_path()` after every save, or resources embed instead of linking. |
| `board_view.gd` | `remove_child()` before `queue_free()`; freeing is deferred and duplicates stack within a frame. |
| `buff_picker.gd` | Use `set_anchors_and_offsets_preset()`, not `set_anchors_preset()`. The latter sets anchors but leaves the offsets alone, so a code-built Control stays 0×0 and its whole UI collapses into the top-left corner — laid out, visible, and off in a corner. |
| `combat_sim.gd` | Fixed `TICK`, never frame delta. A slow frame would change who wins. |
| `unit_data.gd` | Never mutate a `UnitData`. Units of a type share one object, and in the editor you'd be editing the file. |
| `unit_instance.gd` | `attack_speed` is **attacks per second** — higher is faster. Use `attack_interval()` when you want seconds. There is no cooldown stat any more. |
| `board_model.gd` | `promote_to()` wipes `modifiers`, so a merge re-applies the team's buffs afterwards. Skip that and merging launders your buffs away. |
| `buff_data.gd` | `LIFESTEAL` bases at 0, so its buff must use `flat`. A percent modifier on a zero base is silently worth nothing. |
| `board_model.gd` | `magnet_of()` is checked **before** `roll_merge_result()`. Rolling first and overriding after would burn an RNG draw and desync the seeded merge lottery. |
| `buff_data.gd` | Match a unit against `covers()`, not `unit_id` — Covenant also names the Wisp, and a bare `unit_id` check silently skips summons. |
| `unit_instance.gd` | `HEAL_POWER` bases at 1.0, not 0. Every other stat bases at its data value; a 0 base here would zero out all healing. |
| `team_buffs.gd` | Only `Kind.STAT` buffs are applied to units. Everything else is read where it takes effect — don't "fix" that by applying them all. |
| `team_buffs.gd` | `FULL_ROSTER_TYPES` is the single source of truth for "all five types" — `combat_sim.gd` reads it too. Two copies would let the greyed-out chip and the actual bonus disagree. |
| `buff_bar.gd` | Hit areas are built in `_relayout()`, never `_draw()`. Rects computed while painting don't exist before the first paint, which breaks tooltips and can't be tested headless. |
| `main.gd` | Ownership goes through `_active_team`, never `PLAYER_TEAM`. In PvP those differ for half the prep phase, and using the constant hands one player control of the other's units. |
| `game_setup.gd` | Player 1 is `TEAM_B` (bottom), Player 2 is `TEAM_A` (top) — the opposite of the raw team indices. Always go through `player_number()`/`team_name()`; numbering off `team + 1` silently swaps the two players everywhere. |
| `main.gd` | Nothing in the HUD or the buff strips is ordered relative to the active player. Fixed positions and fixed labels, with a highlight for whose turn it is. |
| `board_model.gd` | `configure_merges()` clears the per-team pools, so call it **before** `set_team_pool()`, never after. |
| `board_model.gd` | Board dimensions are static vars, so they are global. A test that calls `use_map()` must call `reset_map()` before it returns, or every suite after it runs on the wrong board. |
| `map_data.gd` | `has_neutral` must match the height's parity. An even board with a divider, or an odd one without, gives one side an extra rank — `is_valid()` is the only thing standing between you and a silently unfair map. |
| `board_view.gd` | Anything positioned relative to the board reads `board_size()`, never `WIDTH * 84`. Tile size now depends on the map. |
| `board_model.gd` | `is_empty()` excludes blocked tiles, which is what stops every placement path — draws, summons, revives, blinks, restores — from putting a unit inside a wall. Adding a new placement route needs nothing extra as long as it goes through `is_empty()` or `free_cells()`. |
| `combat_sim.gd` | A barrier lives on the edge between two tiles, so `AStarGrid2D` cannot express it. The BFS in `_next_step()` exists for that one reason — do not "simplify" it back to a grid solver. |
| `map_data.gd` | Terrain must mirror vertically. An unmirrored `#` is a free advantage for whoever gets the cover, and nothing else in the game would ever tell you. |
| `combat_sim.gd` | `_open_now()` refuses to open an ability with `consumes_caster`. A raised Spire instacasting Raise Host would raise more Spires, which would raise more, inside one resolve. |
| `board_model.gd` | `line_of_fire()` runs from a canonical end. Bresenham from A to B and from B to A can disagree on a tie, and a game where you can shoot someone who cannot shoot back is a bug nobody will report clearly. |
| `combat_sim.gd` | Targeting is not gated on line of fire — only the attack is. Gate targeting and a ranged unit behind a wall has nothing to walk toward. |
| `unit_instance.gd` | High ground is read from the unit's **current** cell every time it decides, not baked in at spawn. `attack_reach()` is the flat-ground answer; `reach_on()` is the real one. |
| `main.gd` | `GameSetup.apply_map()` runs at the very top of `_ready()`, before `fit_to()` or `bind()`. Both ask the board how big it is. |
| `combat_sim.gd` | New units go in `_pending_units` and are absorbed at the end of the tick. Appending to `_units` mid-loop grows the array `_order` is iterating. |
| `combat_sim.gd` | `_check_over()` counts pending respawns. Without that a Revenant's team loses the round while it is still getting up. |
| `data_builder.gd` | A unit row with `hidden = true` is built but kept out of both loadouts. That's how the Wisp exists without being pickable. |
| `run_tests.gd` | Assert on `effective_hp()`, not `current_hp`, when a Warden might be the victim — its opening shield eats the first 70 damage and hides the hit. |
| `run_tests.gd` | Read a revived unit's health from the `respawn` event, not from the instance after more steps — the fight carries on and it takes hits immediately. |
| `combat_sim.gd` | The Assassin's burst uses `pow(2, tier - 1)`, matching the health/damage curve. Linear `* tier` falls off a cliff by tier 4. |
| `combat_sim.gd` | The Warden's shield is a **share of max health**, so Ironwall and tiers both grow it. A flat number stops mattering by tier 3. |
| `combat_sim.gd` | Reach comes from `attack_reach()`, never `stat_int(ATTACK_RANGE)`. The stat is a **band**, and band 5 means the whole board, not five tiles. |
| `combat_sim.gd` | `_decide()` checks the full-mana cast **before** it bails on `can_act()`. Reverse those and the Spire — which can neither move nor attack — never casts at all. |
| `combat_sim.gd` | A unit with a live mana aura is skipped by `_tick_mana_regen()`. Without that skip its own regen refills its own bar and it spends the battle recasting a pool it already opened. |
| `board_model.gd` | A 3x3 zone is `units_in_box()` (Chebyshev), not `tile_distance()` (Manhattan). Manhattan silently drops the four corners and turns the box into a plus sign. |
| `buff_data.gd` | `flat` covers `stat_a` only; `stat_b` has its own `flat_b`. A mixed-mode buff (Incubation: flat mana, percent health) needs both set deliberately. |
| `unit_instance.gd` | `MANA_REGEN` bases at `data.mana_per_second`, so a flat `+3` buff reads as "+3 a second" without the unit needing a nonzero base. |
| `battle_player.gd` | The shown cast duration is `max(sim_time, MIN_CAST_SHOW) / speed`. Openers cost 0s in the sim on purpose — clamping in the **view** is what keeps them instant and still visible. |
| `combat_sim.gd` | `summon_shortfall()` counts free cells; it must never call `_summon_cells()` to find out. Sampling consumes the seeded rng and desyncs every roll after it. |
| `combat_sim.gd` | `_beam_wash()` shares its `struck` set with the pierce pass. Without it the unit directly behind the target takes full damage *and* the wash. |
| `main.gd` | `_record_formations()` runs after `_restore_roster()`, not before. Before it, a spent Spire is still in the roster and its recruits are not — the ghosts would show exactly the wrong thing. |
| `main.gd` | `_celebrate_merge()` runs after `_after_board_change()`, which rebuilds every view. A pop set before it is thrown away. |
| `board_view.gd` | Ghosts are drawn, never instantiated. Adding a real `UnitView` for a fogged enemy would leak the live board through the fog and break the no-enemy-in-tree rule. |
| `run_tests.gd` | A Warden makes a bad damage target: its opening shield is 125% of max health, so `current_hp` never moves. Use a Spire — rooted, unshielded, and it holds still for a positional test. |
| `combat_sim.gd` | `_consume_caster()` deliberately bypasses `_damage()`. Routing a self-spend through the damage path credits lifesteal to nobody and offers the unit a revive roll it should never get. |
| `unit_instance.gd` | `consumed` and `permanent` both survive `reset_for_battle()`. They are roster bookkeeping, not battle state — clearing them resurrects a spent Spire and demotes a recruit. |
| `unit_instance.gd` | `keeps_mana` is why `reset_for_battle()` cannot unconditionally zero `mana`. For a Spire the bar *is* its progress, and it is the only progress it has. |
| `combat_sim.gd` | A summon reserves every cell it needs *before* creating anything. Placing one at a time means a half-raised host, and the caster paid a full bar for it. |
| `combat_sim.gd` | `persist_room()` measures against the half's capacity and the round's starting count — never `free_deploy_cells()`. Free tiles appear whenever someone dies, and a roster built from those overflows the half next round. |
| `combat_sim.gd` | A revive searches the whole board (`_any_free_cell`), not the ring around the corpse (`_free_cell_near`). The ring version silently deleted units. The blink still uses the ring on purpose — "behind the target" is meant to be local. |
| `combat_sim.gd` | `return a if cond else [] as Array[T]` erases the element type and the typed caller rejects it **at runtime**, not at parse time. Clear the array and return it instead. |
| `main.gd` | `_restore_roster()` checks `can_deploy` as well as `is_empty`. `force_place` ignores halves, so a unit that ended the battle in enemy territory would be restored there. |
| `combat_sim.gd` | The live count is emitted by the sim, never rebuilt in the view from births and deaths. Deferred deaths and revives make a delta tally drift about one match in twenty. |
| `main.gd` | The match seed honours `GameSetup.debug_seed` when it is non-zero. Without it the scene suites are unreproducible and an intermittent failure cannot be chased. |
| `main.gd` | Unit counts during battle come from `BattlePlayer.living()`, never `board.living_units_of()`. The board already holds the finished fight, so the model would spoil the result the moment the battle starts. |
| `battle_player.gd` | `respawn_start` puts a unit **back** on the tally. `CombatSim._check_over()` counts pending respawns, so a bar that dropped them would show a wipe the sim is about to undo. |
| `unit_inspector.gd` | Hit-test against `UnitView` positions (`BoardView.unit_at_point()`), not `board.unit_at(cell)` — during playback the model holds end-of-battle cells. |
| `unit_inspector.gd` | `MOUSE_FILTER_PASS`, never `STOP`. The overlay needs the mouse for tooltips, but `BoardView` needs the same event for dragging and merging. |
| `loadout_editor.gd` | A `Label` defaults to `MOUSE_FILTER_IGNORE`, so it gets no tooltip and no `mouse_entered`. Slot labels are set to `STOP` deliberately. |
| `data_builder.gd` | Rows in `UNIT_TABLE` are only written to the resource if `_make_units()` copies them. `note` sat unread in that table for weeks — adding a key is two edits, not one. |
| `smoke_test.gd` | The battle-start hold and the round-end hold both look identical from outside (nothing is playing). Tell them apart by order — `_start_hold_checked` — not by `battle_running`, which is already false in both. |
| `unit_view.gd` | `die()` cancels an in-flight cast. Skip that and a unit killed mid-wind-up dies with the ring still drawn around its corpse. |
| `board_model.gd` | `can_merge()` honours `wild_merge` on **either** side of the pair. Checking only the first argument makes the Amalgam work in one drag direction and not the other. |
| `team_buffs.gd` | `resync()` rebuilds `modifiers` from scratch. Appending instead would double every buff each round. |
| `main.gd` | `_start_battle()` awaits the start-of-round pause, so it is async. Anything that assumed playback begins on the same frame as the phase change needs `battle_running`. |

## When it won't start

The status line under "Round N" names the specific failure:

| Message | What to do |
|---|---|
| "Can't load … at all" | The file is missing, or its script failed to bind. Regenerate. |
| "…loaded as X, not a LoadoutData" | Stale editor cache. Close Godot, delete the `.godot` folder, reopen. |
| "Loadout is empty or has a null unit" | Regenerate. |

If a script error mentions a nil board, that's `BoardView` drawing before it was
bound — it shouldn't happen any more, and there's a test keeping it that way.

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

## The draw lands on the board

Units arrive already placed, on random free tiles in your half. There is no
holding area, deliberately: a tray lets you defer the decision, and the decision
*is* the game.

The consequence is that **a draw with nowhere to go is lost**. If your half is
full, the units that don't fit are gone — not held over. The status line says so
in as many words, because silently dropping them would read as a bug, and feeling
that loss is the point of the space pressure.

`_summon()` in `main.gd` does the placing, for both sides. The stand-in opponent
runs the same path and then merges opportunistically.

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

- **Should the board flip for Player 1 in PvP?** Right now both players use the
  same orientation, so one of them is arranging "upside down". A view transform
  would fix it and is the single biggest polish item left in that mode.
- **How good should the computer be?** `_ai_merge_pass()` merges greedily and
  deploys at random. Local PvP now gives you a way to test balance without it.
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
- **The rarity odds.** `ODDS` in `rarity_table.gd`. A 5% gold on pick 1 is a rare
  treat; raise it if you want the swing to matter more often.
- **Can the same buff be taken twice?** The picker excludes what you already hold,
  so no. `TeamBuffs` stacks correctly if you allow it — `_taken_ids()` is the gate.
- **Does the AI pick well?** It picks uniformly at random from its own three.

Board geometry note: the odd height is load-bearing. `mirror(y) = HEIGHT - 1 - y`
maps the centre row onto itself, which is the only reason the mirror-matchup test
is an exact fairness check. Going back to an even board costs you that.
