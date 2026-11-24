class_name BossPhase
extends Resource

## One phase of a boss: its name on the health bar, when it starts, how fast it
## works, and the moves it cycles through IN ORDER. The cycle is fixed on purpose —
## the fight is a pattern to learn, not a dice roll — and it loops: after the last
## move comes the first again.

@export var display_name: String = "Phase"

## The phase begins once the boss's health falls to this share of its maximum or
## below. 1.0 for the opening phase.
@export var hp_threshold: float = 1.0

## Also begins the moment the Central Crystal is all that is left, whatever the
## boss's health. The final phase is the push on the centre.
@export var on_central: bool = false

## Seconds the boss stands still announcing this phase when it begins — no moves,
## no swings, no walking. The breath before it changes stance, and the player's
## warning that the pattern they have learned is about to change.
@export var entry_pause: float = 1.5
## The move she opens this phase with the moment the pause is over: her signature for
## the phase, wound up like every big one. None for the first phase.
@export var entry_move: BossMove = null

## Seconds of ordinary fighting between one move landing and the next mark going up.
@export var gap: float = 4.0

## A multiplier on the boss's attack speed and its walking speed for this phase.
@export var haste: float = 1.0

## Share of all damage the boss deals that comes back to it as health.
@export var lifesteal: float = 0.0
## Extra attack damage for this phase (0.3 = +30%), on top of the haste above: she hits
## harder as well as faster with every phase.
@export var attack_bonus: float = 0.0
## Health she regenerates every second in this phase, a share of her full health.
@export var regen: float = 0.0

@export var moves: Array[BossMove] = []

@export_group("Summons")
## Minions called the moment this phase begins.
@export var summons_on_start: int = 0
## Then this many more every `summon_every` seconds while the phase lasts (0 = never).
@export var summon_every: float = 0.0
@export var summon_count: int = 0
## How much stronger this phase's minions are than BossData's base minion.
@export var minion_power: float = 1.0

@export_group("Music")
## What plays during this phase: a stretch of an audio file, looped for as long as
## the phase lasts. `music_to` of 0 means "to the end of the file". Empty path, or a
## file that is not there, and the boss screen keeps whatever is already playing.
@export_file("*.mp3", "*.ogg") var music_path: String = ""
## What the HUD calls that stretch while it plays ("Theme 1").
@export var music_label: String = ""
@export var music_from: float = 0.0
@export var music_to: float = 0.0
