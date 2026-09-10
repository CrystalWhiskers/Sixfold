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

Everything that makes a noise lives in `autoload/audio.gd`, and every file it wants
is a fixed name in `assets/`. **Replacing a sound is replacing a file** — no code
change, no table edit:

| file | plays when |
|---|---|
| `music/battle_1.ogg` … `battle_10.ogg` | the battle playlist — one is rolled at the top of every round from whatever is switched on in the menu |
| `music/menu_theme.ogg` | the menus |
| `sfx/melee_1.wav` … `melee_6.wav` | a melee unit swings (one picked at random) |
| `sfx/ranged_1.wav`, `ranged_2.wav` | anything that is not a melee swing or a beam — shots and spells |
| `sfx/laser.wav` | Transcendence, and nothing else |
| `sfx/critical.wav` | the 5% doubling lands |
| `sfx/death.wav` | a body drops, either team |
| `sfx/round_start.wav` | the Fight button — the press itself, not the bell after the hold |
| `sfx/select.wav` | cycling a slot in the loadout editor |
| `sfx/pickup.wav` | lifting a unit off the board to move or merge it |
| `sfx/confirm.wav` | a button that commits to something |
| `sfx/merge.wav` | you merge two units |
| `sfx/promotion.wav` | that merge came out a tier higher |
| `sfx/windfall.wav` | that merge threw off a free extra unit |

Volumes are the `*_DB` constants at the top of the same file, and the mix is
explained under [Sound, portraits and criticals](#sound-portraits-and-criticals).
Music must be **Ogg Vorbis with `loop=true` in its `.import`** — Godot's importer
defaults to `false`, so a track that has not been told to loop simply stops. There
is a test asserting every battle track loops, because that failure is silent.

**Tracks are numbered, never named.** `battle_track_name()` returns the index and
the menu shows "1", "2", "3". A name in code has to be kept in step with a file on
disk by hand and drifts the first time a placeholder is swapped; `battle_7.ogg is
track 7` needs no upkeep. Adding an eleventh track is dropping `battle_11.ogg`
into `assets/music` — `Audio` counts upward from `battle_1` until a file is
missing, and the menu builds one toggle per track it finds, so no code changes at
all. The toggles are a wrapping grid rather than a row for the same reason: ten
of them in a line would be wider than the window, and there is a menu-suite check
that none of them ends up off the screen.

Do **not** put audio in `scripts/combat/` — that layer runs thousands of times a
second during headless balance runs. The view layer is where sound belongs, and
`scripts/view/battle_player.gd::_apply()` is the one place every `attack`,
`damage`, `cast_resolve` and `death` event passes through during playback.

---

## Placeholder assets, and how to pull them out

Two things in this project are borrowed material standing in until your own art
and audio arrive. Neither is safe to hand in as part of a graded project, and
both are deliberately isolated so removing them is deleting files:

| What | Where | What breaks when it's gone |
|---|---|---|
| The Warden portrait | `assets/portraits/warden.png` | The unit falls back to a coloured block, like the other twenty-nine. |
| The Warden's death lines | `assets/voice/warden_*.wav` | Wardens die to the ordinary death thump, like the other twenty-nine. |

Delete the files (and their `.import` siblings) and nothing else needs editing.
`Audio` looks its voice pools up by counting files on disk, so a unit with none
is simply a unit that doesn't speak — there is no list of unit ids anywhere in
the code to keep in step. The one thing that *will* notice is the smoke test,
which asserts the Warden currently has six death lines and three overkill lines;
those two checks in `tools/smoke_test.gd::_check_voice_lines()` go with the files.

### How the voice system works

Files are named `<unit_id>_<kind>_<n>.wav` in `assets/voice/`, numbered from 1.
`kind` is either `death` or `overkill`. Giving the Reaver a voice is dropping
`reaver_death_1.wav` in that folder — no code change.

**Overkill** means the killing blow was larger than the victim's *entire* health
bar, not larger than whatever was left of it. `CombatSim.is_overkill()` decides
it at the moment damage lands, because that is the only place the number exists,
and stamps the answer onto the `death` event. Chipping a unit down and finishing
it with a tap is not an overkill — that is the most common death in the game and
it must not be the loudest. The two pools are exclusive: an overkill plays an
overkill line *instead of* a death line, never both.

---

## Running things

```
godot --headless --script res://tools/run_tests.gd      # 1569 model + sim tests
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

### The thirty-four buffs

Bronze / silver / gold, all in `tools/data_builder.gd`'s `BUFF_TABLE`. Every one
doubles from bronze to silver and doubles again to gold.

| Buff | Who | Effect |
|---|---|---|
| Mending Wind | Heal 5 / 7 / 10% of max health every second |
| Rupture | Attacks deal an extra 1 / 2 / 3% of the target's max health |
| Windfall | 10 / 20 / 30% chance on merge to summon one extra random unit |
| Promotion | 4 / 8 / 12% chance on merge for the result to gain a tier |
| Full Muster | While all five types are on the board: +30 / 60 / 90% health **and** attack |
| War Drums | +20 / 40 / 60% attack speed |
| Ironwall | Warden | +100 / 150 / 200% max health — the shield scales off max health |
| Marksmanship | Archer | +25 / 50 / 75% attack, +15 / 30 / 45% attack speed |
| Vigor | Lancer | +30 / 60 / 90% health, +20 / 40 / 60% attack |
| Conflagration | Pyre | +40 / 80 / 120% attack, +10 / 20 / 30% attack speed |
| Swarm | Vexer | +50 / 100 / 150% attack speed |
| Shadowcraft | Assassin | +10 / 20 / 30% attack speed, +15 / 30 / 45% attack |
| Fanfare | Herald | +20 / 40 / 60% attack, +25 / 50 / 75% health, **+aura power** |
| Undying | Revenant | +50 / 100 / 150% health **and** attack |
| Grace | Seraph | +35 / 70 / 105% health, +10 / 20 / 30% healing power |
| Covenant | Conjurer **and its Wisps** | +50 / 100 / 150% health, +30 / 60 / 90% attack |
| Cohesion | Amalgam | +100 / 200 / 300% max health |
| Incubation | Spire | **+3 / 6 / 9 flat mana a second**, +0.5 / 1 / 1.5 health |
| Confluence | Wellspring | **+3 / +6 / +9 flat mana a charge**, +30 / 60 / 90% health |
| Ascension | Transcendence | +50 / 100 / 150% health **and** attack |
| Dominion | Tyrant | +40 / 80 / 120% health **and** attack |
| Fabrication | Engineer **and its Sentries** | +50 / 100 / 150% health, +40 / 80 / 120% attack |
| Solitude | Paragon | +50 / 100 / 150% health **and** attack — and **at gold only**, two Paragons may be empowered instead of one |
| Whetstone | Reaver | +50 / 100 / 150% attack, +25 / 50 / 75% attack speed |
| Retaliation | Aegis | +25 / 50 / 75% health, **+15 / 30 / 45 points of damage resist** (flat, not a percentage of a percentage) |
| Remembrance | Vigil | +50 / 100 / 150% health — and **+1 / +2 / +3 more of the fallen raised per cast** |
| Gluttony | Devourer | +50 / 100 / 150% health, +20 / 40 / 60% attack speed |

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

### Gold is three times bronze, not four

**Two deliberate exceptions, added later.** War Drums now runs **20/40/60%** and
Ironwall **100/150/200%** — Ironwall on a flat +50 step rather than a multiple of
bronze, because a Warden's shield is a share of its max health and the doubling
version made the bronze pick feel like nothing next to the gold one. Everything
else still follows the rule below.

Every buff that scaled used to run **1x / 2x / 4x** across bronze, silver and
gold. That makes the last pick of a match worth more than the three before it put
together, and a gold Swarm at +200% attack speed was less a buff than a different
game.

They now run **1x / 2x / 3x**. Twenty buffs changed. The ones already linear —
Cohesion, Conscription, Bloodletting, Confluence, Solitude, Ascension — were left
alone, and so were the flag-shaped ones (Far Sight, Levy, Alchemy) and Reckless,
whose drawback deliberately *shrinks* as it gets rarer. Two buffs scaled
differently on their two stats, so the rule was applied per component rather than
per buff: Incubation's flat mana was already 3/6/9 and only its health half moved.

**Ten tests broke on this, which is the interesting part.** They had the old
numbers typed into them — `is_equal_approx(healer.stat(HEAL_POWER), 1.4)`,
`solo_hp * 2.2`, `base_interval / 1.6`. Each was rewritten to read the number off
the buff and assert the *relationship* instead: that attack speed divides the
interval rather than subtracting from it, that Ironwall's health bonus grows the
shield by the same ratio, that a Wisp inherits exactly what Covenant says. A test
that restates a tuning value only tests that nobody retuned it.

Two were worse than stale. `_test_merge_procs` stacked **seven** copies of
Promotion to guarantee a proc — a magic number that only reached certainty while
gold was 0.16. At 0.12 it lands at 84%, and the test started failing on a third
of its seeds. It now works out how many copies certainty needs from the buff.

The scaling law lives in exactly one place: the check that every scaling buff runs
one, two, three times bronze.

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
  real **ten seconds** — a third of the way to the sudden-death mark, by a long
  way the longest cast in the game, and all of it at double damage. It is long
  enough that a single tier 1 Warden can walk the length of the board and kill
  the Engineer before it finishes.
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

### What ten seconds costs, and who collects

The build has been lengthened twice, and each step cost real strength:

| Build time | Builds finished (random placement) | Inclusion win rate |
|---|---|---|
| 2.5s | — | 62% |
| 5s | 78% | 50% |
| **10s** | **49%** | **38%** |

At ten seconds it is a **below-average pick** — half its builds never finish, and
a round often turns before the turret exists. That is a deliberate choice rather
than an accident, but it is worth knowing it is not a free knob.

**Where the builds are lost flipped, too**, which is the interesting part. Over 80
matches with two Engineers a side:

| Placement | at 5 seconds | at 10 seconds |
|---|---|---|
| Random | 78% | 49% |
| Deliberately in the back rank | **62%** | **66%** |
| Back rank, no Assassin in either pool | 100% | — |

At five seconds, putting the Engineer somewhere safe made it **worse**: the
Assassin's Shadowstep opens *behind* the enemy line, which is exactly where a
builder goes to hide, and taking the Assassin out of both pools took the failure
rate to zero. At ten seconds the ordinary advancing army has time to arrive as
well, so distance starts paying for itself again and the back rank is the better
place after all — 66% against 49%.

So the same unit rewards opposite placements at the two build lengths, from one
number changing.

### Baiting the blink

Shadowstep does not pick the weakest target, it picks the **deepest** one — the
enemy standing furthest into its own half. That is a rule you can play against:
put something tough behind the Engineer and the blink lands on that instead.

| Formation | Builds finished | Win rate |
|---|---|---|
| Random placement | 53% | 45% |
| Engineers at the very back | 62% | 52% |
| **A tank behind them as bait** | **82%** | **69%** |

One extra body in the right place takes the Engineer from a below-average pick to
one of the better ones. The ten second build is not a nerf so much as a
requirement to protect it, which is the shape the unit wanted all along.

`_backline_enemy()` is asserted directly in the tests rather than through a
battle, because at tier 4 the Assassin's opener kills a mid-build Engineer during
`setup()` — the unit under test is already gone by the time the board settles, and
the check would pass for the wrong reason.

The Sentry was strengthened to match the longer build: **80 damage** a shot, up
from 45, and 110 health.

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

## The Aegis, and a resist stat

210 health, 20 damage, and **15% of every hit shrugged off before anything else
is counted** — the only unit in the game with innate resistance. It does not
out-damage anything. It makes hitting it a bad idea.

Resistance needed a new stat rather than reuse of `DAMAGE_TAKEN`. That one is a
*multiplier*, so a buff reading "+15% resist" would have had to be written as a
negative number to work, and every description would have printed backwards.
`StatModifier.Stat.RESIST` is a fraction where higher is better;
`damage_taken_multiplier()` is now `DAMAGE_TAKEN × (1 − resist)`, and resist is
clamped to **0.90** so nothing can stack its way to literal immunity.

**Retribution** is the first `REFLECT`. For five seconds it shrugs off a further
50% and sends **200% of what lands on it straight back** — but only at whatever
struck it from an adjacent tile, a swing or an ability alike. An archer across the
board is untouched, which is what makes it a melee answer rather than a blanket
one. Unlike the Paragon's taunt it does not plant the caster: the Aegis keeps
moving and swinging while it holds.

The reflected hit is dealt with `may_reflect` false. Two Aegis facing each other
would otherwise bounce one swing between them until a stack ran out, and there is
a test that puts two nose to nose and checks the event log does not explode.

Measured at **53%** inclusion — mid-pack, below the Warden's 75%, which is right
for a unit whose job is to be unpleasant rather than to win fights.

---

## The Reaver, and a burst that actually scales

95 health, 34 damage, the fastest swing and the fastest legs in the game. Less
health than a Lancer with more than twice its damage: it wins any exchange it
starts and loses any exchange it is caught in.

**Execute** is where the interesting part is. Flat `burst_damage` does not scale
with tier and no buff can reach it — a tier 6 Pyre's Cinder Lance still hits for
78 while its ordinary swing hits for 224. So Execute is written as
`burst_attack_multiple = 4.0`: four times the caster's *current* attack damage,
resolved through `burst_damage_of()`. That means it grows with tier (120 at tier
1, 3840 at tier 6) and Whetstone's attack bonus reaches it, which is what makes
the buff coherent with the unit.

**The Pyre and the Vexer still have the old problem.** Fixing them is the same
one-line change plus a balance pass, and it is not done.

Finding the stats took a sweep rather than a guess. At the first cut — 65 health,
"low survivability" taken literally — it came in at **37%**, below the Archer,
because a soft melee unit simply dies on the walk in:

| health / damage / move | Inclusion win rate |
|---|---|
| 65 / 30 / 0.38 | 37% |
| 90 / 30 / 0.38 | 45% |
| **95 / 34 / 0.34** | **53%** |
| 110 / 30 / 0.36 | 57% |
| 110 / 34 / 0.34 | 62% |

110 health reaches 57% but stops being fragile — that is mid-pack for this
roster. 95 is the honest compromise: bottom half of the roster by health, and
nothing that fragile out-damages it. There is a test that asserts exactly that,
against the roster rather than against a number, so it stays true as units are
added.

---

## The roster is ordered simplest first

`UNIT_TABLE`'s order is the menu's order **and** the starter loadout's — the
builder takes the first five playable units as the fallback loadout. So the order
is a decision, not a listing, and it runs least to most complicated:

Warden, Archer, Lancer, Reaver, Vexer, Pyre, Aegis, Tyrant, Seraph, Herald,
Revenant, Assassin, Wellspring, Amalgam, Transcendence, Conjurer, Vigil, Paragon,
Devourer, Spire, Engineer — then the two you never pick, the Wisp and the Sentry.

"Complicated" here means how many rules you have to hold in your head. The Warden
shields itself. The Engineer builds a timed turret on its own tile while exposed,
steps aside, repairs Mechanical units, holds its cast when capped, and has a
companion unit that only exists because of it.

A new player is handed the first five, which is the point of the ordering — and
there is now a test naming those five, because inserting a unit near the front
silently pushes one out. That is not hypothetical: the Aegis went in at slot five
first, which dropped the Vexer from the starter and broke a whole ability section
that had keyed its lookup table off the starter rather than the roster. The Aegis
moved to seventh, where it belongs anyway — innate resist *plus* a conditional
reflect is two ideas, not one.

**Reordering the table broke a test, in a way worth recording.** `_run_crossing`
built its two units as `_unit(2)` and `_unit(1)` — slots into the loadout — so
the movement-lockout test, the one the top of this file calls out as proving the
core mechanic bites, quietly became an Archer walking at a Lancer. It now looks
both units up by name. The scene test had the same shape of rot: it checked "a
match can be played entirely with the new units" against five hard-coded names
from back when those five were new, and had survived two reorders as a list of
the wrong units. It now checks that every unit on the board came from the
loadout its team actually drew with.

---

## The Paragon

Field exactly one and it starts the round **empowered**: 250% health, 200%
damage, and its ordinary swing lands on the whole 3x3 around whatever it hit.
Field two and neither of them is.

That cliff is the unit. Measured over 60 matches:

| Army | Inclusion win rate |
|---|---|
| 1 Paragon + 7 random | **68%** |
| 2 Paragons + 6 random | **32%** |
| 3 Paragons + 5 random | 32% |
| 1 Tyrant + 7 random | 65% |
| 2 Wardens + 6 random | 80% |

One is among the best single picks in the game; two is among the worst boards you
can field. The escape hatch is the one the game already has — two Paragons of the
same tier merge into one of the next, so a duplicate draw is a merge you were
going to want anyway rather than a dead unit.

**Empowerment is decided once, at the opening bell**, in `_decide_empowerment()`,
against the board as it stands then. Nothing that arrives later is ever empowered
— not a Mimic's copy, not a Spire's host, not a merge result — because this is a
reward for the board you built and a summon you can pay for is not that. There is
a test that has a Spire raise Paragons and checks every one of them comes up
small.

It is applied as **battle** modifiers, not permanent ones, so the round boundary
wipes it and next round re-decides from scratch against whatever you have then.

**Last Stand** is the first `TAUNT` in the game and only an empowered Paragon can
cast it. Every enemy within three tiles drops what it was doing and comes for it;
for four seconds it takes 90% less damage; and it can neither move nor swing
while it holds. It deals no damage at all — the ability is not an attack, it is a
way of choosing who the other army is fighting for four seconds.

`_mark_for()` runs ahead of `nearest_enemy()` and prefers an enemy holding a taunt
inside its radius. Testing that honestly needed care: with the Paragon as the only
enemy on the board, *everything* targets it and the test proves nothing, so the
real test gives every foe a closer friendly bait to prefer first and checks the
taunt pulls it off that.

**Solitude**, its buff, is the only one in the game whose gold tier does something
that is not a stat: it raises the empowered cap from one to two. Bronze and silver
give the stats alone.

---

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
| Stasis | Arrest | Freezes one enemy for 0.9s per tier — it cannot move, swing or cast — while it takes +15% damage per tier from everything, and dies leaving nothing behind. | 14 |
| Vexer | Blight | 11 damage every 0.5s, 6 times, on one enemy, **and +5% damage taken from every source per tier of the Vexer while it lasts**. Keeps ticking while the Vexer shoots elsewhere. | 12 |
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
| The Terrace | 9 x 15 | yes | **second layer** | A plateau each side with four staircases in front of it. Melee cannot touch the top from the ground. |
| The Crown | 9 x 13 | yes | **second layer** | One hill in the middle. You get a row of it, they get a row, and the crown belongs to nobody. |
| The Defile | 9 x 13 | yes | **second layer** | A one-tile gap in the middle and two raised roads beside it. There is no third option. |
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
now runs its own search: a distance field flooded out from the target across tiles
that are unblocked and not barrier-separated, and the mover takes the neighbour
with the lowest distance.

It is a 135-tile board at worst, so this is cheaper than it sounds, and it is
fully deterministic — neighbours are visited in a fixed order and ties go to the
first. `_greedy_step()` is still the fallback when the target is walled off
entirely. See *Queues, and the price of walking round one* below for what the
field costs a tile that one of your own is standing on.

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

## Two units that eat your own dead

Both the Vigil and the Devourer charge off `UnitData.mana_per_ally_death`, and
neither charges off anything else. That one field is the whole design: their bars
do not move when they swing, do not move when they kill, and do not move when the
fight is going well. **You cannot farm this.** It fills only while your own side
is losing people, which makes both units comebacks rather than snowballs — the
opposite of every other scaling mechanic in the game.

`CombatSim._feed_on_death()` pays out to living units on the **dead unit's own
team**, deliberately not the killer's. Killing things gives you nothing.

### The Vigil

Medium range, slow legs, and an attack barely worth mentioning. Four of your own
dying fills its bar; **Lament** then calls back one of your fallen per tier —
tier 1 raises one, tier 6 raises six — at **85% health**, on their own graves
where possible and beside the Vigil otherwise.

Which of your dead comes back is a **random draw** from everyone who has fallen,
seeded from `CombatSim.rng` like every other roll. That is on purpose: it means a
Vigil hands you back an army, never a specific unit you were hoping to rescue.

Tier is the entirety of its scaling. Its own stats barely move between tier 1 and
tier 6; what changes is how much of your board it gives back, and the probe shows
that as clearly as anything in the game — **40% at tier 1, 55% at tier 3, 65% at
tier 6**, where the Warden goes the other way (65 → 57 → 52).

Two rules keep it honest, both tested:

- **A body is used once.** `_take_fallen()` removes it from `_fallen`, so two
  Vigils never raise the same corpse and one Vigil never raises it twice.
- **Something already getting up is not available.** A Revenant mid-revive never
  enters the pile, so you cannot have it both ways.

### The Devourer

Melee, unremarkable, and it stays unremarkable until **five** of your own have
died — that is `grief = 25` against a 100-point bar. **Gorge** then transforms it
once: 2.5x health, 50% faster swings, a third quicker on its feet.

The second half is the part worth reading the code for. Once ascended — and
**only** once ascended — its swings start paying mana (`ascend_mana_per_attack`).
Every bar it fills after the transformation arms the next swing to **kill
outright**, whatever it hits and however much health that thing has left.

`_execute()` is a deletion, not a large number. It goes through shields, through
resistance, through the Aegis's reflect. That is not laziness — a tier 6 Warden
in this game carries **20,720 effective health** behind its opening shield, so
any "very big number" that reliably killed one would be obscene against
everything else. The one thing an execute does not go through is invulnerability,
so a guarded cast is still guarded.

Both the ordinary swing and the armed swing route their death through
`_fell()`. Keeping that in one place is what stops the execute from quietly
skipping the revive roll, or the mana it owes the other side's scavengers.

Measured: **52%** at tier 3 — above the roster median of ~42%, below the Vigil
(55%) and the Warden (57%), well below the Tyrant (65%). The tuning lever is
`grief` alone, and it is steep: 20 (five deaths) reads 47%, 25 (four) reads 52%,
34 (three) reads 58%.

### A test that passed for the wrong reason, again

`_find()` returns null for anything outside the roster, and the Wisp is hidden.
Three of the first Vigil tests built their corpses out of `_find("wisp")` — that
is, out of null — and reported failures that looked like broken game logic. The
fix is `_must_find()`, which fails a check when the roster has no such unit, so
the next one of these is a loud failure instead of a confusing one.

## The empowered Paragon is a siege engine, not a bigger soldier

`empower_attack_speed_mult` is the only empowerment multiplier allowed to go
*below* 1.0, and the Paragon is the only unit that uses it. Empowered, it gets
2.5x health and **4x** damage over a 3x3 — and swings at **0.35x** its own attack
speed, which is one blow every **3.81 seconds**. That is slower between swings
than anything else in the game including the Sentry.

The trade is deliberately extreme in both directions. Almost anything on the
board out-trades it over ten seconds. Almost nothing survives being in the wrong
square when it lands.

The number that matters is that this is **not a nerf to the Paragon** — it is a
cost attached to the empowered form only. Two Paragons are two ordinary Paragons
swinging at ordinary speed, exactly as before. There is a test for that, and it
fails if the multiplier is applied unconditionally.

| | One (empowered) | Two (neither empowered) |
|---|---|---|
| Before | 62% | 35% |
| After | 63% | 35% |

Unchanged, in other words — the same unit strength arriving in a completely
different rhythm, which was the whole point. Across tiers, one empowered Paragon
reads 70% at tier 1, 63% at tier 3, 55% at tier 6.

## Two fixes that made everything fight more

### A unit that could not walk did nothing at all

`_begin_move()` returned silently on every one of its four failure paths —
nowhere to step, a friend in the way, a failed shove — and `_decide()` returned
straight after calling it. So a unit whose chosen target was unreachable spent the
tick standing still, even with an enemy at its elbow. That is the "sometimes they
just don't attack" you were seeing.

`_begin_move()` now returns whether it actually moved, and a `false` falls through
to `_swing_at_hand()`, which re-picks a target from whatever is genuinely in reach
and swings at that. It deliberately does **not** use `u.target` — the whole point
is that the unit it wanted is unreachable and something else is not.

Writing a test for this took three attempts, and the first two passed for the
wrong reason:

1. **Boxing it in with Spires does not box it in.** `_begin_move()` trades places
   with a rooted neighbour on purpose, so a wall of Spires is a wall you walk
   through.
2. **Boxing it in with movable friends works, but then it simply targets the
   adjacent enemy** through the ordinary path and attacks. The test passed without
   the fix and proved nothing.
3. **A taunt is the honest case.** `_mark_for()` overrides distance entirely, so
   the unit is committed to something across the board while being elbowed. That
   version fails on the old code and passes on the new.

### Melee reaches the corners

`BoardModel.in_reach()` is new and replaces a bare `tile_distance <= reach`. For
the melee band it uses Chebyshev — all eight surrounding tiles — and for every
longer band it still uses Manhattan, so a "medium" unit reaches a diamond and not
a 5x5 box. Movement is still strictly four-way; nothing walks diagonally.

Two knock-ons that had to move with it:

- **The Aegis's reflect** uses `is_beside()` now. "Arm's length" has to mean the
  same eight tiles a melee unit can swing across, or a Reaver at its corner hits
  it for free.
- **`_has_shot()` no longer waves melee through unconditionally.** A diagonal
  swing can cross a barrier, so anything that is not orthogonally adjacent gets
  the line-of-fire check.

### What both did to the numbers

This is the part worth reading. Measured at tier 3, two of the unit plus six
random against eight random:

| | Before | Stuck fix only | Both |
|---|---|---|---|
| Warden | 57% | 68% | **73%** |
| Reaver | 50% | 70% | **68%** |
| Lancer | 47% | — | **55%** |
| Archer | 38% | 45% | **37%** |
| Vexer | 30% | — | **30%** |

The stuck fix is the big mover and it lifts everybody — units simply spend more
ticks fighting. Diagonal reach is the one that opens a gap: it takes the Archer
from 45% back down to 37%, because melee now closes and engages far more reliably.

Net effect: **melee is now clearly the stronger class.** That is a real
consequence of two changes that were both asked for and both fix genuine
problems, and it is not obviously wrong — but it is a decision, not a side effect,
and the lever if you want it back is ranged base damage or the `TARGET_SLACK`
band.

## Mutable terrain: the Sapper and the Mason

A fifth glyph, `%`, is breakable stone. It behaves exactly like `#` for movement,
sight and deployment — the only difference is that it can stop existing mid-battle.
It is a second glyph rather than a flag on the first because a map built around
Sappers needs walls they cannot touch.

`BoardModel` keeps the change as a per-battle overlay alongside the map's own
tables: `_rubble` (which walls may be broken at all), `_broken` and `_raised`
(this round's damage and building), and `_wall_hp` (what is left of each standing
one). **The map resource is never touched.** `clear_changes()` runs at the top of
`CombatSim.setup()`, so a map stays a static, shareable thing and a *battle* is
what makes it mutable. Every terrain query — `is_wall`, `is_blocked`,
`blocks_sight` — reads through the overlay, so pathfinding, targeting and the beam
all update for free the moment a wall comes down.

### Walls have health, and anyone can dig

A wall is not something one cast deletes. Map stone is `WALL_HP = 240`, and
`UnitData.wall_damage_mult` says what fraction of a unit's attack damage a swing
does to stone. At **0.15** an ordinary unit *can* chew out of a sealed room and
badly wants not to — a tier 1 Warden needs 47 swings. A Sapper is at **6.0**.

Because it is a multiple of attack damage rather than a flat number, digging speed
**doubles with every tier for free**, and the Sapper's attack buff reaches the
stone. That is the same shape as Reaver's Execute, and the opposite of the mistake
Cinder Lance still has.

### One number does the "go round, unless you can't" rule

This is the part I am happiest with. The weighted Dijkstra field built for
congestion already prices a tile rather than banning it, so a breakable wall is
just an expensive tile:

```gdscript
const WALL_COST := 40          # everyone else
const SAPPER_WALL_COST := 2    # a unit that digs for a living
```

At 40 an ordinary unit walks a very long way round rather than start digging —
breaking a wall is a last resort, not a shortcut. But it is **not infinite**, and
that is the whole trick: when a side is genuinely sealed in, the route through the
stone becomes the *only* route, the field prices it, and the army digs its way out.
No "is everything walled off?" check exists anywhere, because none is needed. At 2
a Sapper goes at the stone almost every time.

Permanent stone and holes stay impassable, so a map can still say "never through
here".

One thing this needed that was not obvious: `_downhill()` skipped anything that
was not an empty tile, so the field could price a route through a wall and then no
step would ever be taken along it — a unit standing still forever in a sealed room.
A wall is now a legal step for the *chooser* even though it is not a legal tile to
stand on, and `_begin_move()` turns a step into stone into a swing at it.

### The two units

- **Sapper.** 150 health, 26 damage, and it goes at stone the way everything else
  goes at flesh. Its charge is worth four of its own wall swings, so even a tier 1
  opens a map wall in one cast. Its ordinary combat stats are deliberately good:
  once the walls are down its utility is spent, and it has to still be worth its
  tile in round six. Measured **53% on Three Roads, 47% on the open board** —
  against the Warden's 57% and 68%. That gap between the two boards is the unit.
- **Mason.** 165 health, and it puts its first wall up **on the opening bell**
  before anyone has moved, then another on every full bar. The wall blocks
  movement and sight **for both armies, yours included**, and it never builds on a
  tile with a unit on it — walling a live unit into stone is not something the
  rest of the simulation is prepared for.

### The buffs

- **Demolition** (Sapper): +15/30/45% attack speed, +75/150/225% attack. It reaches
  the stone too, because wall damage is a multiple of attack.
- **Bastion** (Mason): +50/100/150% max health, and its walls are +100/200/300%
  tougher. That rider is what the buff actually buys — a tougher wall, not a bigger
  builder.

### A Mason's wall is a firing slit

`_raised` stores **who built each wall**, and `blocks_sight()` takes a team. A wall
is transparent to the side that raised it and opaque to everyone else. Map stone
has no owner and stops everybody.

This is the only team-aware terrain in the game, and it is deliberately only half
of the membrane from the original spec: **movement is unchanged**. `is_blocked()`
takes no team, so neither army walks through a Mason's wall. Yours shoots over it;
nobody strolls through it. That half is cheap — one dictionary value and one
parameter — while making movement team-aware would touch the pathfinder, the
distance field and the view all at once.

It breaks one long-standing invariant on purpose. `line_of_fire()` swaps its ends
so "A can shoot B" and "B can shoot A" never disagree over a rounding tie — but
across a membrane the two directions are *supposed* to disagree, and they do,
because the swap only fixes which end the walk starts from and not which tiles lie
on the line. There is a test asserting exactly that asymmetry, so nobody later
"fixes" it back.

It is also what the Mason was missing. It probed at **33%** as a plain wall and
**43%** as a firing slit — a full ten points, and from below the roster median to
sitting on it. A wall that blocked your own archers was most of why the unit read
badly at random placement.

### And it builds underfoot

`terrain_at_caster` puts the wall on the tile the Mason is standing on and steps
the Mason off it, the way the Engineer bolts its Sentry together under its own
feet. That makes **placing the Mason** the decision, rather than guessing which
way it happens to be facing when its bar fills.

Boxed in with nowhere to step, it falls through to building beside itself rather
than burning the whole bar — being unable to move is not a reason to produce
nothing. That is the Engineer's `holds_when_capped` lesson applied to a different
unit: a builder standing there achieving nothing is a trap, not pressure.

Net of both changes it reads **42%**, against 33% before either.

### Stone is battle state, and the round boundary is `_restore_roster()`

`clear_changes()` already ran at the top of `CombatSim.setup()`, so a *battle*
always began from the map as drawn. That was not enough. Between rounds — the
whole prep phase — last round's walls and holes were still standing, which meant
a Mason's wall from round two was sitting on tiles you were trying to deploy into
in round three. The usable board quietly shrank a little every round.

It now clears in `main.gd`'s `_restore_roster()` as well, and specifically
**before** deploy cells are worked out. The `setup()` call stays as the belt to
that braces: the sim guarantees a clean board even for a test that never went
through the round loop.

### One builder rule, in one function

`_vacate_for_build()` is the rule both builders follow: **what gets built takes
the builder's tile, and the builder steps off.** Never the other way round — a
Sentry that shuffled over to make room would be a turret in a place nobody chose,
and the whole point of both units is that where you stand them is where the thing
goes.

The Engineer already worked this way; the Mason was doing the same thing through a
second copy of the logic I had written separately. Now there is one function, and
the Conjurer is **deliberately not on it** — its wisps are a retinue that arrives
around it, not a thing it puts down, so it never moves for them. There is a test
asserting all three at once, so the exemption reads as a decision rather than as
an oversight in the Conjurer's data.

Boxed in with nowhere to step, both fall back to building beside themselves rather
than wasting the cast. Being unable to move is not a reason to produce nothing.

**Three Roads now degrades.** The middle five rows of both dividing walls are
breakable; the stone nearest each base is permanent, so nobody digs straight into
your back line. **The Breach** is a slab of breakable stone filling the whole
middle of the board with permanent pillars through it.

## The Culverin and the Parasite

### A shell that is actually in the air

Every other ability in the game resolves the instant its cast finishes. The
Culverin's does not: `_resolve_shell()` puts an entry in `_shells` and
`_tick_shells()` lands it 1.5 seconds later. That delay is the unit.

The important detail is that the shell is aimed at a **tile**, not at a unit.
Once it is in the air it is committed to a piece of ground, so anything that walks
off in the meantime is simply not there when it lands. Aim is picked by
`_thickest_cluster()` — whichever enemy has the most of its friends sharing a
cross with it, ties broken by closeness, so on a spread-out board it reads as an
ordinary sniper and only becomes a bomb when a clump forms.

Damage is a **cross**, not a box: 150% to the tile it lands on and 100% down each
arm. Corners are untouched, which is why *which axis* the clump lies along
matters. It is `shell_attack_multiple × attack damage`, so it scales with tier and
Enfilade reaches it.

Then the ground burns for six seconds. `field_at()` answers "what would this tile
do to a unit of that team", which is one function doing two jobs: `_tick_fields()`
uses it to deal the damage, and `_distance_field()` asks it and prices a burning
tile at `FIELD_COST = 3`. So units are **dissuaded, not forbidden** — they walk two
tiles round if they can and take the burn if they cannot. Making fire impassable
would let one shell wall off a corridor, which is a different and much stronger
unit than the one asked for.

**Enemies only.** Your own line walks through its own fire, which keeps the unit
usable when it is badly placed — the failure mode the Mason has.

Measured at **62%**, exactly level with the Warden.

### Siphon, and what "until death" costs

The Parasite reaches across the whole board — no range check at all — and fastens
onto whichever enemy has the largest **maximum** health. From then it loses 2.5%
of that maximum every second until it dies. Three deliberate properties:

- **Max, not current.** The bite does not shrink as the victim wears down, so it
  genuinely finishes what it starts.
- **Shields do not count.** A Warden's shield is worth more than its health; if
  the drain counted it, the Warden would become the thing the Parasite is *best*
  against rather than merely another big body.
- **It stacks.** Two Parasites, or one casting twice, drain twice as fast.

It runs through `_damage()` rather than subtracting health directly, which is how
the innate lifesteal applies to every tick of it for free. `lifesteal` is now a
real `UnitData` field feeding `_base(LIFESTEAL)`, the same shape as
`damage_resist` → RESIST, so Bloodletting adds to it rather than replacing it.

### An honest problem with the counter

You asked for this to answer high-health units like Transcendence. At tier 3 it
does — but so does everything else, by the same amount:

| | Alone | Against 2 Transcendences | Lift |
|---|---|---|---|
| Parasite | 48% | 58% | +10 |
| Warden | 62% | 72% | +10 |
| Culverin | 62% | 60% | −2 |

The Parasite gains exactly what the Warden gains, which means at tier 3 it is not
a *differentiated* counter — a tier 3 Transcendence has 660 health and 2.5% of
that is 16 a second.

At tier 6 the arithmetic is much better — 528 a second, about 75% of an apex
Transcendence's health over a 30-second round — but **it still does not finish one
alone**: 40 seconds to solo-kill against a round that hits sudden death at 30. Two
apex Transcendences beat everything regardless (Warden 0%, Parasite 2%).

There is also a design wrinkle worth deciding on: **the drain does not scale with
the Parasite's own tier at all.** A tier 1 Parasite drains an apex Transcendence
exactly as fast as a tier 6 one. Every other ability in the game scales, so this
stands out. I left 2.5% as specified rather than quietly changing it — the levers
are raising `drain_percent`, or multiplying it by the caster's tier so merging
Parasites actually sharpens the counter.

### The buffs

- **Enfilade** (Culverin): +20/40/60% attack speed, +75/150/225% attack. It reaches
  the shell, since shell damage is a multiple of attack.
- **Hunger** (Parasite): +25/50/75% attack speed and **+1/+2/+3 range bands, flat**.
  That is the one buff that can push a unit into Sniper and Unlimited — see below.

### The range ladder got two more rungs

The band ladder had a structural problem, not a rules problem. `RangeBand`'s
**value is the tile count** — `band_tiles()` returns the enum value directly — and
the top two rungs, Sniper and Unlimited, were reserved for buffs to reach. That
left Melee, Medium and Long as the only bands a unit could be printed at, so
"long range" had exactly one legal spelling and the Culverin was illegal at the
range it was designed for.

Fixed by making the ladder longer rather than by lifting the rule:

| Band | Tiles | |
|---|---|---|
| Melee | 1 | |
| Medium | 2 | |
| Long | 3 | |
| Sniper | 4 | **highest a unit may be printed at** |
| Siege | 5 | buffs only |
| Horizon | 6 | buffs only |
| Unlimited | 100 | buffs only |

`MAX_PRINTED_BAND` names the cutoff instead of the test hard-coding two band
names, so moving it later is a one-line change.

**New bands may only ever be appended at the top.** Inserting one in the middle
would silently hand a tile of reach to every unit above it — making Medium 3
would re-arm the Vexer, Pyre, Seraph, Conjurer and Wellspring in one edit. There
is now a test asserting Medium is still 2 and Long still 3, precisely so that
mistake fails loudly.

The Culverin sits at **Sniper**. Four tiles cost it a little rather than gaining
it: **58%**, down from 62% at Long, against the Warden's 62%. It reaches further
and therefore stops further out, which suits the shell less than it sounds — its
aim wants a clump, and a clump seen from four tiles has longer to disperse before
the shell lands. Still comfortably mid-upper, and it is the right band for what
the unit is.

Buffs now have real headroom: Hunger at gold takes the Parasite from Long to
Horizon, and Far Sight's single band means something at every tier of the ladder
rather than instantly maxing out.

## The Pariah, and a number I had to argue with twice

Five damage a swing — less than a Wisp — 230 health, no ability and no mana bar.
`alone_hp_damage` is the whole unit: while it is **isolated**, every hit also tears
out 12% of the target's maximum health.

It hangs off the same line as the Rupture buff, which already added a fraction of
the victim's max health to every hit, so the sum is one expression:

```gdscript
var frac: float = _hp_damage[source.team] + last_stand_share(source)
```

Being a fraction of the victim's maximum means it never needs to scale with tier —
it already does, and it is as dangerous against a tier 6 Transcendence as against
a Wisp. That is the point of the unit.

### Isolation: a 3×3, answered once, at placement

The condition used to be "last one of yours standing", asked live on every hit. It
is now **elbow room**, asked once:

```gdscript
const ISOLATION_RADIUS := 1   # a square, not a cross — the eight tiles around it
```

`_decide_isolation()` runs next to `_decide_empowerment()` in `setup()` and writes
a single bool onto the unit. Three consequences, all deliberate:

- **Diagonals count.** It is a 3×3 square, not a plus. `absi(d.x) <= R and
  absi(d.y) <= R`, not `absi(d.x) + absi(d.y) <= R`. The test that pins this is the
  one a player will try first, by tucking an ally into the corner.
- **It cannot change during the round.** Your line advancing past it does not
  switch it off; the ally crowding it dying does not switch it on. The Pariah is
  melee — a live check would disarm it the instant it walked up to something — and
  more importantly the player paid for this verdict at placement, so the game may
  not revise it afterwards.
- **Nothing that arrives after the bell is ever isolated.** Merge results, Mimic
  copies, Conjurer minions: same rule as the Paragon's `solo_empower`, and for the
  same reason. Placement is the whole cost, and a summon is not placement.

**Allies only, and that is a narrowing of what was asked for.** The brief said "no
units within a 3×3". Enemy placement happens behind fog, so counting enemies would
make the condition one whose inputs you cannot see — un-plannable, which is the
opposite of a placement puzzle. On the standard map it makes no difference at all
(the neutral row leaves the halves two tiles apart at the bell) but on a map with
`has_neutral = false` the front ranks start touching, and there it is the whole
unit. One line in `_isolation_clear()` reverses it if that call was wrong.

The player is told at the bell: an `ISOLATED` label, cold grey-blue, at the moment
they can still learn something from it.

### The tuning, redone from scratch

The old 30% was priced against "seven of your units have died". A tile in the
corner is nothing like that price, so the number had to come down a long way. Probe
is one Pariah at tier 3 plus seven random tier 3s against eight random tier 3s,
**200 seeds per row**, the two arms differing only in where the Pariah stands:

| `alone_hp_damage` | isolated | crowded |
|---|---|---|
| 3% | 50.5% | 46.5% |
| 5% | 53.0% | — |
| 8% | 52.5% | — |
| **12%** | **56.0%** | **46.5%** |
| 20% | 63.5% | — |
| 30% | 68.5% | — |

The crowded arm is flat at 46.5% at every share, which is the check that the
condition is actually gating: a misplaced Pariah is a unit with no ability, no bar,
and five damage a swing, and the number on it is irrelevant.

**12%.** Isolated it reads 56%, which sits with the Culverin (58%) and under the
Paragon (63%) and Colossus (62%) — a strong unit, not the best one. The ten-point
swing between the two arms is the largest thing placement alone buys in this game,
which is the point. 20% and 30% both make it the best unit on the board for the
cost of standing in a corner.

It is no longer four swings to kill anything; it is about eight. The old line was
correct for a condition that cost you the round, and wrong for one that costs you
a tile.

### And it climbs with tier

12% is the **tier 3** figure. The share now runs 7 / 9.5 / 12 / 14.5 / 17 / 19.5%
across the ladder, written per tier into the `.tres` files by the builder rather
than scaled at runtime.

A **flat step**, not the doubling every other stat gets, and the README used to
argue this should not scale at all: the share is a fraction of the victim's
*maximum* health, so the damage it deals already doubles per tier on its own.
Doubling the fraction on top of that compounds straight back into the
four-swings-kills-anything version. Tier 6 takes under three times what tier 1
does, and there is a test pinning both the evenness of the step and that ratio.

**Spite** gives +25/50/75% attack speed and +50/100/150% max health. Attack speed
is deliberately the offensive half: the share comes off **per hit**, so swinging
faster is the only thing that makes it come off quicker. An attack-damage buff
would do almost nothing here, which is why it does not have one — and there is a
test saying so.

## The Colossus, and why "per hit" is the whole unit

250 health, **95 damage** — the heaviest ordinary attack on the roster — one swing
every four seconds, and the longest stride of anything in the game. No ability, no
mana bar. Every time it is hit, `shield_on_hit` adds **3% of its maximum health**
to its shield, capped at one full health bar.

The load-bearing word is **per hit**, not per point of damage. That one choice is
the entire unit:

| Feeding it | Shield gained |
|---|---|
| Ten hits for 1 damage each | 10 x 3% = 30% of its health |
| One hit for 10 damage | 3% of its health |

So a dozen small attacks arm it faster than one enormous one, which is exactly the
brief. It hardens **after** the blow lands, too — there is no free first hit; what
a hit buys is protection from the *next* one.

### The trade-off is measurable, not just flavour

| Enemy team | Colossus | Warden |
|---|---|---|
| Random | 62% | 62% |
| Four Vexers (fastest, weakest) | **98%** | 92% |
| Four Culverins (slowest, heaviest) | **38%** | 42% |

Identical overall, six points better against rapid weak fire and four points worse
against slow heavy blows. A ten-point swing across the matchup, against the
tankiest unit already in the game — a real rock-paper-scissors axis rather than a
note on a card.

### Why it has a cap

Without `shield_cap` an attacker whose per-hit damage is smaller than 3% of the
Colossus's health could never out-pace the gain, and the unit would simply stop
dying — forever, not just for a while. The cap bounds how much it can hold at
once; **sudden death** is what eventually breaks a genuine stalemate, since
`pressure()` scales all damage upward after 30 seconds. The game already had the
answer to unkillable, so the unit did not need to invent one.

**Tempering** gives +75/150/225% max health and **+2.5/5/7.5% more of max health
per hit**. Both halves compound — a bigger pool makes every plate bigger *and* the
share itself goes up — so a gold pick more than triples the shield it gains per
hit, on top of more than tripling its health.

One test bug worth recording: the first version compared a buffed Colossus against
an unbuffed one **on the same team**, and the buff covers the unit *type* rather
than the individual, so both picked it up and the comparison was a unit against
itself. It passed while proving nothing. The unbuffed one now sits on the other
team.

## The round clock

A round runs **two minutes**, and if it gets there it is decided on **units still
standing**. Level on bodies is a draw, and a drawn round costs **both** players a
life.

Three pieces, and two of them are corrections to things that were already there:

**`_decide_timeout()` counts bodies, not health.** It used to total everyone's
remaining health as a fraction of their maximum. That is a fairer measure of who
was winning and a much worse one to play to — you cannot count it while watching,
so the result arrived as an announcement rather than something you saw coming.
Six units against five is a number on the screen the whole round.

Worth knowing if you ever change this back: the old rule summed *fractions*, so a
full-health tier 6 counted exactly as much as a full-health tier 1. Almost any
test board scores identically under both rules, and the first sabotage run I did
passed clean because of it. The case that separates them is **two healthy units
against three badly hurt ones** — 2.0 against 1.2 on fractions, two against three
on bodies — and that is the board the test uses.

**`SUDDEN_DEATH` moved from 30s to 90s.** Escalating damage exists to stop a
fight that would otherwise never touch. Starting it at thirty seconds meant almost
nothing survived to the timeout and the clock never decided anything — the
escalation did. It is the backstop now, not the rule, and it covers the last
thirty seconds only.

**A draw costs both sides a life**, which it did not before. A life is spent by
giving the other player a win, so a draw hands one to each. That means both can
cross the line together, so `match_winner()` needed an answer for it rather than
returning whoever it checked first: ahead on the line wins, dead level is a drawn
match.

The countdown on screen follows the **player's** clock, not the sim's. The battle
is fully resolved before frame one, so `sim.elapsed` is already at the end and is
no use — and at 4x speed the clock has to run at 4x with it or it would disagree
with what you are watching. It turns amber for the last thirty seconds, which is
also exactly when hits start escalating; one colour change for both facts,
because they arrive together.

## The second layer

Two maps use it — **The Terrace** (one plateau per side, four staircases each)
and **The Crown** (one hill in the middle that neither side wholly owns). Three
rules, and they live in two functions.

### Every map, with no exemptions

The eleven maps that had high ground *before* stairs existed all had staircases
cut into them rather than being grandfathered out of the rule — Killing Field, The
Steppes, The Cauldron, The Highlands, The Keep, The Anvil, Ramparts, The Bridge,
The Hourglass, The Chasm and The Compound. `^` means the same thing everywhere
now.

That is only safe because the builder refuses to produce a map it would break.
`_unreachable_high()` floods every connected patch of `^` and fails the build if
no `/` touches it, because a plateau with no way up is not difficult terrain —
it is a place nothing can stand, nothing can reach, and no melee unit could ever
attack into, and it is completely invisible in the map source unless you trace
the patch by eye. Two of the retrofits also broke the mirror-symmetry check that
was already there, which caught them immediately.

There is a matching test that walks every `.tres` in `data/maps` and asserts the
same thing about what actually shipped.

### `reach_against(attacker, target)`

Reach stopped being a property of a unit the moment the board got a second layer,
so it is now a property of the pair:

- **A melee unit standing on the ground cannot touch anything on high ground.**
  Not at a penalty — at all. It returns `0`, and `in_reach` now treats zero as a
  refusal rather than a short range. That guard is new and it had to be: the
  melee band is written as `if tiles <= 1: return is_beside(...)`, so a zero
  quietly meant "can hit anything at its shoulder" until this was added. Nothing
  had ever produced a zero before, because `reach_on()` floors at the melee band.
- **Shooting from high ground is worth a band**, which it always has been.
- **Shooting at high ground costs a band.** A Long-ranged Archer has to walk to
  Medium to touch the terrace.

The two ranged adjustments cancel, so a duel across two terraces is fought at
exactly the range it would be on flat ground — there is a test for that, because
it is the property that stops the rule quietly rewriting every ranged matchup on
a high-ground map.

Stairs are **ground**, not high ground. A melee unit standing on a staircase
still cannot hit the terrace above it; the stairs are how you get up, not up.

### `BoardModel.can_climb(from, to)`

```gdscript
if not is_high(to):
    return true
return is_high(from) or is_stairs(from)
```

Getting **down** off a plateau is free from any edge, and only getting up is
restricted — which is what makes a terrace a place you retreat to rather than a
box you get stuck in.

It is checked in four places, and the fiddly one is the distance field: that is
built **backwards from the goal**, so the step under consideration is the one from
`n` to `c` and the climb is checked that way round. Getting it the wrong way about
prices a staircase as if you were coming down it, and melee units walk to the foot
of a cliff and stop. The other three are `_downhill`, `_greedy_step`, and
`_begin_move` itself — the last purely as belt and braces, since that is the one
place every move actually happens.

The pathing needs no other help. A melee unit told to reach something on a terrace
finds the staircase on its own, because a weighted distance field with the climb
edges removed has exactly one route and finds it; there is a test that watches a
Reaver do it and asserts it passed over a stair tile on the way.

## The Stasis, and a death that leaves nothing

The Vexer's colder cousin: weak hits, a bar that fills fast, and an ability worth
more to everyone else than to itself. Full mana freezes one enemy for **0.9s per
tier** while it takes **+15% damage per tier** from every source — and if it dies
frozen, **nothing it would have done on death happens at all.**

### The freeze is three refusals, in three places

```gdscript
func _decide(u: UnitInstance) -> void:
    if u.is_frozen():
        return
```

Before the target is picked and before the full-mana cast, so a bar that filled
the tick before the freeze landed is **held rather than spent**. It does not act
less often — it does not act. `can_move_now()` and `can_attack_now()` also refuse,
which is what stops the consolation swing in `_swing_at_hand` from sneaking one
through, and `frozen_damage_taken()` joins the other multipliers in `_damage()`.

Both numbers are **read off the caster at the moment of the cast and frozen into
the victim**, the same rule the Vexer's vulnerability follows: killing the caster
does not thaw anything, and a buff picked mid-round does not deepen a freeze
already running. Two casters take the **longer** of the two rather than adding —
stacking freezes into a permanent lock is the one outcome nobody enjoys being on
the wrong end of.

### The second half is one branch in `_fell()`

```gdscript
var frozen := victim.is_frozen()
...
if frozen:
    return   # no revive roll, no body in the pile, no mana for the scavengers
```

That is the whole "disables on-death effects" clause, and it is one branch because
`_fell` is the single funnel every death goes through — an ordinary swing, a
spell, a Devourer execute. The three things it skips are the three things a death
in this game can trigger: the Revenant's revive, the corpse joining `_fallen` for
a Vigil to raise, and `_feed_on_death` charging the dead unit's own side's
scavengers. There is a test for each.

### Permafrost, and a buff with no machinery

The buff wants "+50% freeze time, +25% amp" and neither is a stat. Rather than
build a bespoke path, `FREEZE_POWER` and `FREEZE_AMP` were added to
`StatModifier.Stat` as base-1.0 multipliers — exactly what `HEAL_POWER` and
`AURA_POWER` already are — so Permafrost is an ordinary two-component STAT buff
and the whole existing buff system applies unchanged.

It runs **50/25, 75/50, 100/100**, which is neither the 1x/2x/3x rule nor a
straight line: the amp is deliberately behind at bronze and catches all the way up
at gold. The amp buff scales the **share**, not the multiplier — doubling x1.45
gives x1.90, not x2.90 — and there is a test that says so, because the other
reading is an easy mistake to make and a catastrophic one to ship.

### What it is worth

Two Stasis plus six random against eight random, tier 3, 150 seeds. The second
column is the matchup it exists for: eight Revenants, an army whose entire trick
is dying and getting back up.

| freeze | vs random | vs Revenants |
|---|---|---|
| ability off | 36.0% | 73.3% |
| 0.5s / 8% a tier | 36.7% | 79.3% |
| **0.9s / 15% a tier** | **38.7%** | **84.0%** |

Against a random field the ability is worth under three points. Against the army
it answers it is worth eleven. That gap is the unit — and it is the reason the
general win rate is the wrong number to tune it by.

The body was then raised from 130/7 to **160/8**, having learned the lesson the
Vexer taught:

| base hp/dmg | vs random | vs Revenants |
|---|---|---|
| 130 / 7 | 38.7% | 84.0% |
| **160 / 8** | **44.7%** | **90.7%** |
| 175 / 9 | 47.3% | 95.3% |
| 200 / 10 | 54.0% | 96.7% |

175 and 200 both push the counter matchup past 95%, which stops being a counter
and starts being a lockout. 160/8 leaves it a little under median in general —
correct for a unit whose value is in what it lets everything else do, which a
probe with random allies systematically under-measures — and a strong answer
rather than an automatic one.

## The Vexer's poison, and the one field that could scale

The Vexer was the weakest thing on the roster and the reason is structural rather
than a tuning miss: **an `AbilityData` is one resource shared by all six tiers of
a unit.** A tier 6 Cinder Lance hits for the same 78 as a tier 1 because
`burst_damage` is a number on a resource that does not know which tier is holding
it. `burst_attack_multiple` exists to route around exactly this — it says "this
many times the caster's own attack damage" instead of a flat figure — and Blight's
`dot_damage` has the same problem and no such escape.

Rather than fix that here, Blight gained a second effect that *does* scale, in the
cheapest way available:

```gdscript
target.apply_dot(ab.dot_damage, ab.dot_ticks, ab.dot_interval, u.uid,
    ab.dot_vulnerability_per_tier * float(u.data.tier))
```

Multiplying by the caster's tier at the moment of the cast. 5% per tier: a tier 1
Vexer opens its mark up 5%, a tier 6 opens it 30%, and the number is frozen into
that poison — killing the Vexer afterwards does not un-poison the target, and
buffing it mid-round does not retroactively deepen a poison already ticking.

**It rides on the dot entry, not on a separate timed effect.** `dots` is already
a list with a managed lifetime, so putting `vuln` in the dict means the
vulnerability's lifetime *is* the poison's, with nothing to expire, no cleanup at
the round boundary, and correct stacking for free.

Stacking is **additive**, and that is a decision: two tier 3 Vexers make a target
take 30% more, not 32.25% more. Multiplying would make the second Vexer worth more
than the first, which is not what someone reading "+15% damage taken" expects to
happen when they field another one.

It sits in `_damage()` with the other damage-taken multipliers, which means it
amplifies **the poison's own ticks** as well. That is deliberate: "from all
sources" cannot carve out the one source that applied it without becoming a
special case with nothing behind it.

### Then the dot itself was rewritten

`dot_damage` is now **zero** on Blight. The poison takes a share of the victim's
**current** health — 25% on the first tick, halving every tick after
(`dot_current_hp_percent` and `dot_falloff`):

| tick | share of what is left |
|---|---|
| 1 | 25% |
| 2 | 12.5% |
| 3 | 6.25% |
| 4 | 3.1% |
| 5 | 1.6% |
| 6 | 0.8% |

It front-loads **twice over**, and only one of those is the falloff: a share of
what remains is naturally largest on the first tick, because the most health the
target will ever have is what it has when the poison lands. There is a test that
the opening tick alone outweighs every later tick put together.

**Current health, not maximum**, and that is the unit's whole character. A share
of what is left approaches zero and never reaches it, so **Blight cannot kill
anything, at any tier, ever** — there is a test that re-applies it sixty times
against a lone target and checks the target is still standing. The Vexer takes a
great bite out of whatever is healthiest and hands it to somebody else to finish.
It also solves the scaling problem for free, the same way a share of maximum
would: no per-tier table, and proportionally identical against a tier 1 and a
tier 6.

`burst_damage` not scaling is still there on the **Pyre** and still worth the same
treatment.

### And it shuts the target down

`dot_suppresses` on Blight. While it is on, the target gains **nothing**: no
healing, no shields, no new haste stacks, no attack-speed aura from an ally, no
mana from a Wellspring.

The gate is `UnitInstance.is_suppressed()` and it lives in `heal()` and
`add_shield()` rather than at the call sites. That matters: "cannot be healed" has
to cover regen, the Seraph's burst, the Engineer's repair and lifesteal, and a
rule enforced in six places is a rule with five chances to be forgotten when a
seventh healer gets written. The three that cannot be caught that way — haste
stacks, the Herald's aura, the Wellspring's mana — are gated at their resolvers.

It stops things being **gained**; it does not strip what is already there. A
Warden that opened with its bulwark keeps the shield and simply cannot top it up,
and an Archer keeps the haste stacks it earned and simply cannot add to them.
Like the vulnerability, it rides on the dot entry, so it ends exactly when the
last suppressing poison does.

### None of which fixed the Vexer

Two Vexers plus six random against eight random, tier 3, 150 seeds:

| Blight | win rate |
|---|---|
| old flat 11 damage | 26.0% |
| 2% of max HP a tick + shutdown | 29.3% |
| 5% of max HP a tick + shutdown | 31.3% |
| **25% of current, halving (shipped)** | **28.7%** |
| 50% of current, halving | 32.7% |

Three separate rewrites, measured at 150 seeds each, and every one of them lands
inside noise of the others. Doubling the opening bite from 25% to 50% buys four
points. The ability was never the problem. The **body** is: 85 health is the
lowest on the roster by a distance, and a unit that dies in the first exchange
does not get to have an ability at all.

25% with a 0.5 falloff is shipped not because it measured best — nothing measured
meaningfully different — but because it is the number that reads as the design:
cripple, then peter out.

| Vexer base | win rate |
|---|---|
| 85 hp / 6 dmg (shipped) | 29.3% |
| 120 / 6 | 34.7% |
| 120 / 8 | 38.7% |
| 150 / 9 | 44.0% |
| 190 / 11 | 56.0% |

Roughly **170 / 10** lands it on the roster median. That is a tuning decision, not
a code one, and the numbers are in `UNIT_TABLE`.

## Units that get bored of walking

A unit that has not landed a blow in `IMPATIENT_AFTER` (6 seconds) will smash a
breakable wall next to it rather than take another step of a detour. Two pieces:

```gdscript
if is_impatient(u) and _smash_through(u):
    return
```

placed in `_decide` immediately *before* `_begin_move`, and a floor on wall damage
so the smashing achieves something.

**The first attempt was to make stone cheaper in the distance field** — set
`wall_cost_for()` to a low number while impatient and let the existing pathing
route through it. That was the tidier design and it does not work, for a reason
worth writing down: **movement here is diagonal.** Rounding the end of a Three
Roads lane wall costs about the same as going through it — measured on the live
field, the two routes came out at 7 and 7, an exact tie — so a price low enough to
break that tie is lower than the Sapper's, and at that point nothing distinguishes
a bored Warden from a Sapper. The field now stays honest about which route is
*shorter*, and impatience overrides it on the grounds that the unit has run out of
patience, which is not a claim about distance at all.

**The damage floor is not optional.** An ordinary unit does 0.15x its attack
damage to stone; at that rate a map wall outlasts the round several times over, so
choosing to dig without `IMPATIENT_WALL_MULT` would be strictly worse than
walking — a quirk that traps units against a rock. The floor (2.0x) opens a map
wall in a handful of swings and still leaves the Sapper (6.0x) three times faster
and, unlike anyone else, eager from the opening bell. It is a floor rather than a
bonus, so keeping a Sapper waiting does not speed it up.

`_smash_through` only takes a wall that is **closer to the target than the unit
is**. Without that guard a unit kept waiting anywhere starts demolishing whatever
stone is beside it, including the wall protecting its own back line.

**Its real limit**, which the test says out loud: it fires for a unit stuck *next
to* breakable stone, not for one already committed to the long way round. Three
Roads is only breakable across its middle five rows, so a unit that spends six
seconds walking is usually past any breakable tile by the time it gets bored.

The clock is `UnitInstance.dry_spell`, reset on the **swing** rather than the hit —
what it measures is "am I getting anywhere", and a shot that misses or is absorbed
still means the unit is in the fight rather than walking round a rock. Digging
does **not** reset it, so a unit that starts smashing keeps smashing until it is
through.

## Sound, portraits and criticals

### The audio autoload

`autoload/audio.gd` owns everything that makes a noise. Two things in it are worth
knowing:

**`play_music()` is idempotent.** Asked for the track that is already playing, it
returns immediately. That is what "plays all the time" means here — `main.gd`
starts the battle theme once in `_ready()` and the round loop (prep, battle, buff
pick, next round) never touches it again, so it never restarts mid-match.

**Effects are pooled, eight voices deep.** One `AudioStreamPlayer` per sound would
cut a swing short every time a second unit swung, and a busy tick has a dozen
units swinging. Each shot takes the next free voice; if all eight are busy it
takes the oldest anyway, because a clipped tail beats silence on the hit that
mattered.

Sounds fire on the **swing**, not the hit — an arrow should be heard leaving the
bow, with the crack of the hit arriving separately. Six melee samples and two
ranged ones get a little pitch wander on top (0.94–1.06), because six sounds on a
loop still read as a loop and the variation is what stops it. Spells draw from the
ranged pool too. The laser is the one exception and it belongs to **Transcendence
alone** — the branch keys off `beam_attack`, which is set on exactly one row in the
whole unit table, so hearing that sound means Transcendence is firing and nothing
else. There is a test asserting only one unit has the flag.

Missing audio is never fatal — a warning and silence, so a bad path cannot take
the scene down. Which is exactly why the smoke suite asserts the file list: a
renamed `.wav` costs you a sound and nothing else, and the way you would otherwise
find out is by slowly noticing something stopped happening.

**Levels.** `MELEE_DB` is 6 dB under everything else, which is about half the
loudness. Not a taste call — there is simply more melee than anything else, six
units swinging on a loop three tiles apart, and at the shared level it stopped
being feedback and became a wall. The rest of the ladder is ordered by how often a
sound fires against how much it matters when it does:

| | dB | fires |
|---|---|---|
| `DEATH_DB` | −14 | a few times a battle, in clumps |
| `MELEE_DB` | −12 | constantly |
| `MERGE_DB` | −10 | a handful a prep phase, in a quiet room |
| `SFX_DB` | −6 | ranged, spells, the beam |
| `PICKUP_DB` | −12 | every time you lift a unit |
| `CONFIRM_DB` | −6 | a button that commits to something |
| `ROUND_START_DB` | −2 | once a round, with nothing else playing |
| `PROC_DB` | −6 | a merge that got lucky — pinned 4 dB over `MERGE_DB` |
| `CRIT_DB` | −11 | a few times a battle |

**Music is rolled once per MATCH**, in `main.gd::_ready()`, and never touched
again. The playlist decides which track a match gets; it does not shuffle between
rounds. A match is one piece of music from the first prep phase to the last body.

**The three prep-phase sounds** — merge, promotion, windfall — hang off
`main.gd::_celebrate_merge()` and `_show_merge_procs()`, which are reached only
from a human drag. The AI's merges run through `_ai_merge_pass()` and never come
here, and that is load-bearing: a merge sound behind the fog would let you count
the opponent's units by ear.

**Death** fires in `battle_player.gd::_kill()`, not `_schedule_death()` — the
latter runs when the event is queued, which for a ranged kill is while the arrow is
still in the air. Both teams, because the fog lifts when the battle starts. Pitch
wander for the same reason the swings have it: a wipe kills six units in two
seconds and six identical sounds read as one glitch.

Music is converted to **Ogg Vorbis** and set to `loop=true` in the import file
(Godot's importer defaults to false, so looping music that has not been told to
loop simply stops). The effects stay `.wav`: short, and no decode latency.

### Criticals live in `_damage()`, not in `_begin_attack()`

5% for double damage, and **all damage can crit** — a swing, a spell, a shell, a
burning tile, a poison tick, a Siphon drain. That is only true because the roll
sits in `_damage()`, which every one of those routes through. Putting it in the
attack path would have quietly excluded half the game.

It rolls **last**, on the final figure, so a crit doubles what actually lands
rather than doubling a number that three multipliers still have to chew on. And it
rolls off the seeded `rng`, so a replay of the same seed crits in the same places.

`crit_chance` is a var rather than a constant, defaulting to `CRIT_CHANCE`. Two
existing tests measure exact damage totals — a dot's full duration, and the
movement-lockout duel that turns on `move_time` alone — and a 5% doubling turned
both into lotteries. They now set `sim.crit_chance = 0.0`. That is a real dial
("how often does anything crit"), not a test backdoor, and there is a test
asserting the default is still 5% and that zero really does silence it.

Every damage event carries a `crit` flag so the view can react: the floater goes
gold, bigger, marked with `!`, and lives 35% longer — measured against **its own**
lifetime, or it snaps from opaque to gone instead of fading.

### Portraits, and a child node that hid everything

`UnitData.sprite` already existed and had never been populated. The builder now
fills it from `assets/portraits/<id>.png`, falling back to `placeholder.png`, so
adding art for one unit is dropping one PNG at one path — no code change, no table
edit — and a unit with no art still draws its letter.

The portrait is **not** drawn by the `Sprite2D` child. A child CanvasItem always
renders above its parent's `_draw()`, which put the art on top of the team ring,
the health bar, the mana bar and the tier pips — every readable thing on the tile.
Setting `z_index = -1` fixed that and broke it differently: relative z put the
portrait behind the **board's** tiles and it vanished entirely. Both were only
invisible before because no unit had a sprite to hide anything with.

It is drawn inside `_draw()` instead, between the plate and the ring, which is the
one place with exact control over the order.

The **plate** is drawn now whether or not there is art. Behind a portrait the
unit's accent is pulled 62% toward grey and darkened — it is there to say whose
unit this is and what tier, not to be looked at — and the art is inset inside it so
a rim of that muted ground shows all the way round.

## Zoom

`BoardView` now keeps `_fit_tile` (what the window can show) and `zoom` (what you
asked for) separately, and `tile_size` is the product. One source of truth, and a
window resize no longer silently throws your zoom away.

- **Wheel** over the board, **+ / -**, and **0** to reset.
- 0.6x to 3x. Out is useful because the biggest maps hit the `MIN_TILE` floor and
  overflow even when fitted.
- The wheel zooms toward the **cursor**, not the board corner — `zoom_to()` works
  out which board point is under the mouse, changes the scale, and puts that same
  point back under the mouse. Without it, zooming in on a big map walks whatever
  you were looking at off-screen.
- The wheel anchors on the cursor when the cursor is over the board and on the
  middle of the window when it is not. It never *refuses* — see below.

### The wheel zoom that was wired up correctly and did nothing

The first version gated the wheel on `view_area.has_point(event.global_position)`
and silently failed every single scroll. `event.global_position` is in **viewport**
coordinates; `view_area` and every other mouse test in `board_view.gd` are in
**canvas** coordinates, which is what `get_global_mouse_position()` returns. The
test never passed, so the branch never ran, so nothing happened and nothing
complained.

Two changes came out of it:

- The cursor position for anything compared against `view_area` comes from
  `get_global_mouse_position()`. There is a comment on `wheel_zoom()` saying so.
- **The gate is gone.** Off the board it now zooms about the window centre instead
  of returning. A camera control that does nothing at all is a worse failure than
  one that zooms from slightly the wrong place, and the strict version was
  protecting against roster strips that do not actually scroll in this scene.

There is now a smoke-test check that pushes real `InputEventMouseButton` wheel
events through the viewport with `push_input` and asserts the zoom moved. It
tests the **delivery path**, not the zoom maths — no test of `zoom_by()` would
ever have caught this, because `zoom_by()` was correct the whole time. Reinstating
the old gate fails three of its checks.

One thing it deliberately does not cover: headless has no real pointer, so
`get_global_mouse_position()` does not follow a synthesised event and every scroll
in the test anchors on the window centre. The anchor-under-the-cursor behaviour is
not proven by it.

## Enemy letters read upside down

`UnitView` now knows `player_team` and draws the opposing side's initial rotated
180 degrees. It turns out to read faster than colour alone: the board separates
into "letters I can read" and "letters I cannot" without having to think about it.

Rotated about the tile centre rather than the text baseline, or the letter walks
off the square — and `draw_set_transform` replaces the canvas transform outright,
so it is reset immediately afterwards. Everything below it (health bar, tier pips,
mana) draws in plain local space.

## Queues, and the price of walking round one

The old distance field treated a tile with a friendly unit on it as solid. That
is wrong in both directions. It made a unit take any detour at all rather than
wait one tick behind an ally, and when *no* detour existed it fell through to
`_greedy_step()`, which walks the single tile that most reduces the straight-line
distance and has no idea a wall is there. On a map with one gate, that meant the
back half of an army fanning out along a wall while the front half fought.

So a friendly-occupied tile is no longer a wall, it is expensive:

```gdscript
const CONGESTION_COST := 6
```

The field is now Dijkstra rather than BFS, because steps no longer all cost 1.
A tile costs 1 empty and 6 with one of your own standing on it, which reads as:
*walk four tiles round rather than queue behind one, but do not walk twenty.*
Enemies are still solid — you have to go through them, and going through them is
what attacking is.

The number is a lever, and it is the one to touch if movement looks wrong. Set it
to 1 and everyone shoves down the shortest line in single file. Set it to 40 and
they scatter to the far side of the board to avoid each other. Six is roughly
"one ally is worth about half a screen of detour".

There is a test for this on a purpose-built two-gate map, and the useful thing
about it is that it **fails on the old code** — it asserts the unit holds at the
near gate and the old rule sent it sideways to the far one. Every test for new
movement behaviour in this project has to be run against the old rule first,
because several of them passed for the wrong reason before that became a habit.

## Targeting has slack in it

`nearest_enemy()` returning one exact answer meant every unit in a clump picked
the same body, the whole line fixated on it, and fights looked mechanical. Now:

```gdscript
const TARGET_SLACK := 2
```

A unit builds a pool of every enemy within `distance(nearest) + 2` and picks from
it at random. Two extra rules keep it from looking like indecision:

- **It is sticky.** A unit keeps its current target while that target is alive,
  visible and still inside the slack band. It only rerolls when the fight moves.
- **It is seeded.** The roll comes from `CombatSim.rng`, the same seeded stream as
  everything else, so a replay of the same seed is still frame-identical. This is
  randomness in the *fight*, not in the *simulation*.

The knock-on: positional tests can no longer assume the nearest enemy is the one
that gets hit. `_test_beam_wash` had to respace its dummies so the intended target
is unambiguously closest, and it now asserts that spacing outright rather than
relying on it.

## Levy is a headcount, not a fill

Levy used to fill your half of the board to its edges. On the big maps added with
the 33-map set that is fifty-odd units from one gold buff, which is not a buff,
it is a win button. It now tops you up to a **headcount of 30** — five units on
the board means Levy gives you twenty-five, and thirty already on the board means
Levy gives you nothing.

`_fill_half()` loops on `board.count_of(team) < target` instead of on free cells,
and the target comes from `buff.magnitude(rarity).x` rather than a constant, so
the number is tuned in `BUFF_TABLE` like every other buff. The description string
reads it from the same place, so it can never drift from what the buff does.

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
