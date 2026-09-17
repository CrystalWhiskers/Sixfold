class_name MenuBackdrop
extends Control

## The title screen's background: a real battle, played quietly behind the menu.
##
## Nothing here is faked. It builds a board, fills both sides with random units and runs
## CombatSim — the same simulation the game plays — so what you are watching is the
## actual game, including abilities, walls, gates and deaths.
##
## Two deliberate differences from how the game does it, both worth naming so nobody
## "fixes" them into agreement:
##
## 1. The game resolves the whole battle BEFORE frame one and replays an event log
##    (see BattlePlayer). This steps the simulation in real time instead. The log exists
##    so that sounds, floating numbers, cast bars and death animations can be sequenced
##    exactly; a backdrop has none of those, and nothing depends on who wins, so the log
##    and the player would be machinery with nothing to buy. Stepping live is a dozen
##    lines and cannot desynchronise from itself.
##
## 2. It plays on the map the player has SELECTED, and that is not a decoration — it is
##    the fix for a bug this would otherwise have. The board's shape lives in static
##    state on BoardModel (WIDTH, HEIGHT, the wall and void tables), so a backdrop that
##    picked its own map would overwrite the shape every other screen reads. Calling
##    GameSetup.apply_map() means the backdrop and the player always want the same
##    board, so there is nothing to clobber — and changing map in Loadouts changes what
##    you see here, for free.
##
## CombatSim plays no audio of its own — the view layer does — so a battle running here
## is silent without having to be silenced.

const TICK := 0.1

## Seconds of battle per second of real time. Below 1.0 on purpose: this is scenery, and
## scenery that moves faster than the game misrepresents the game.
const PLAY_SPEED := 0.85

## How much of the control the board is allowed to fill. Just under 1.0 so the outermost
## rank is not flush against the edge.
##
## This was 1.18 and fitted to HEIGHT alone, which was wrong and only showed up in a
## screenshot: the game's window is PORTRAIT (720x1280), and a 6x10 board fitted to that
## height comes out wider than the window, so the sides were cropped and most of the
## battle happened off screen. Fitting to whichever axis is tighter keeps the whole board
## visible whatever the window is doing.
const FIT := 0.96

## Give up on a battle that has not resolved by here and start another. Stops the
## backdrop settling into two survivors circling each other for the rest of the minute.
const MAX_BATTLE := 45.0

## How dark the scrim gets directly behind the menu column. Tuned off a screenshot: 0.68
## flattened the middle of the screen so completely that the battle was only visible in
## two strips at the top and bottom, which is most of the way back to a static
## background. This is the one number to change if the buttons are ever hard to read.
const SCRIM_PEAK := 0.46

## Where the scrim is at full strength, as a fraction of the screen from the top. The
## menu column runs from the title down to the loadout note, so the quiet band has to
## cover all of that and not just the middle — the first version peaked at the centre and
## left the title sitting on a bright unit.
const SCRIM_FROM := 0.18
const SCRIM_TO := 0.80

## Units per side. Five is what the game deploys.
const SIDE_SIZE := 5
const MAX_TIER := 4

var _board: BoardModel = null
var _sim: CombatSim = null
var _catalogue: Array[UnitData] = []
var _rng := RandomNumberGenerator.new()
var _carry := 0.0
var _elapsed := 0.0

## What each unit is doing between tiles, so it can slide instead of snapping.
##
## The simulation counts state_timer DOWN from the move's duration and never stores the
## duration itself, so the total has to be captured the first time a move is seen. That
## works because of the order inside CombatSim.step(): the tick that STARTS a move does
## not also advance its timer, so the first sample after a move begins is the full
## duration. Keyed by uid, and rebuilt every battle.
var _slides: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The backdrop must never take a click. It sits under the buttons and has nothing to
	# interact with, and without this it would quietly eat presses near the board.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_load_catalogue()
	_new_battle()


func _load_catalogue() -> void:
	if GameSetup.catalogue.is_empty():
		GameSetup.reload_catalogue()
	_catalogue.clear()
	for u in GameSetup.catalogue:
		# Only units that walk and swing. A backdrop that drew two Spires would be a
		# still image, and the whole point is that something is happening.
		if u.can_move and u.can_attack:
			_catalogue.append(u)


func _new_battle() -> void:
	_elapsed = 0.0
	_carry = 0.0
	_slides.clear()
	# The player's own map — see the note at the top of the file.
	GameSetup.apply_map()
	_board = BoardModel.new()
	for team in [BoardModel.TEAM_A, BoardModel.TEAM_B]:
		_fill(team)
	_sim = CombatSim.new()
	_sim.setup(_board, _rng.randi())
	queue_redraw()


func _fill(team: int) -> void:
	if _catalogue.is_empty():
		return
	var cells := _board.deploy_cells(team)
	if cells.is_empty():
		return
	# Shuffled rather than taken in order, so two battles on the same map do not put
	# their lines in the same place.
	var order := cells.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Vector2i = order[i]
		order[i] = order[j]
		order[j] = swap
	for i in mini(SIDE_SIZE, order.size()):
		var pick: UnitData = _catalogue[_rng.randi_range(0, _catalogue.size() - 1)]
		var tier := _rng.randi_range(1, MAX_TIER)
		_board.force_place(
			UnitInstance.create(BoardModel.at_tier(pick, tier), team), order[i])


func _process(delta: float) -> void:
	if _sim == null:
		return
	# Fixed-step accumulator. The simulation only knows how to advance in whole TICKs, so
	# a variable frame time is banked and spent in whole ticks; anything else would make
	# the battle run at the frame rate.
	_carry += delta * PLAY_SPEED
	var steps := 0
	while _carry >= TICK and steps < 8:
		_carry -= TICK
		_elapsed += TICK
		_sim.step()
		_record_slides()
		steps += 1
	if _sim.is_finished() or _elapsed >= MAX_BATTLE:
		_new_battle()
		return
	queue_redraw()


func _record_slides() -> void:
	for u in _board.units_view():
		if not u.is_alive():
			continue
		if u.state != UnitInstance.State.MOVING:
			_slides.erase(u.uid)
			continue
		var known: Dictionary = _slides.get(u.uid, {})
		if known.get("to", Vector2i(-1, -1)) != u.cell:
			# A move that has only just started, so state_timer is still its full
			# duration. Captured now because nothing stores it later.
			_slides[u.uid] = {
				from = u.move_from, to = u.cell,
				total = maxf(u.state_timer, TICK),
			}


func _slide_position(u: UnitInstance) -> Vector2:
	## Where to draw the unit, in TILES, as a float position between two cells.
	var here := Vector2(u.cell)
	if u.state != UnitInstance.State.MOVING:
		return here
	var slide: Dictionary = _slides.get(u.uid, {})
	if slide.is_empty() or slide.to != u.cell:
		return here
	var total: float = slide.total
	if total <= 0.0:
		return here
	# state_timer counts DOWN, so the fraction left is the fraction of the way it has
	# NOT gone yet.
	var left := clampf(u.state_timer / total, 0.0, 1.0)
	return Vector2(slide.from).lerp(here, 1.0 - left)


func _metrics() -> Dictionary:
	## Tile size and origin, worked out once per redraw. Fitted to whichever axis runs out
	## first, so the whole board is always on screen — see FIT.
	var rows := maxi(BoardModel.HEIGHT, 1)
	var cols := maxi(BoardModel.WIDTH, 1)
	var tile := minf(size.x / float(cols), size.y / float(rows)) * FIT
	var board_size := Vector2(float(cols) * tile, float(rows) * tile)
	return {tile = tile, origin = (size - board_size) * 0.5}


func _band(i: int, count: int) -> Rect2:
	## One horizontal slice of the screen, in whole pixels, that tiles exactly with its
	## neighbours.
	##
	## Worth its own function because the obvious version is wrong in a way you only see
	## in a screenshot: writing the height as `size.y / count + 1.0` to avoid seams makes
	## every band overlap the next by a pixel, and a translucent band drawn twice is
	## darker there — so the whole screen, units included, ended up with a dark hairline
	## every twenty pixels. Snapping both edges to integers means the bands meet instead
	## of overlapping and there is nothing to cover up.
	var top := floorf(size.y * float(i) / float(count))
	var bottom := floorf(size.y * float(i + 1) / float(count))
	return Rect2(0.0, top, size.x, maxf(bottom - top, 1.0))


func _draw() -> void:
	# The ground first, so everything else is drawn onto it. A vertical gradient faked
	# with a handful of bands: cheap, and at this scale indistinguishable from a real one.
	var bands := 24
	for i in bands:
		var t := float(i) / float(bands - 1)
		var band := Color(0.055, 0.062, 0.085).lerp(Color(0.085, 0.080, 0.105), t)
		draw_rect(_band(i, bands), band, true)

	if _board == null:
		return
	var m := _metrics()
	var tile: float = m.tile
	var origin: Vector2 = m.origin

	# The board itself, kept very quiet. This is the layer that has to stay out of the
	# way: if you can read the tile grid, it is too loud.
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var c := Vector2i(x, y)
			if BoardModel.is_void(c):
				continue
			# A wide gap and a very low alpha. The first version used a 6% inset at 0.55
			# alpha and the screenshot showed why that was wrong: at this tile size it
			# read as a wall of grey bricks competing with the menu, rather than as
			# ground the units stand on. If you can read the grid, it is too loud.
			var r := Rect2(origin + Vector2(float(x), float(y)) * tile,
				Vector2(tile, tile)).grow(-tile * 0.14)
			var ink := Color(0.15, 0.17, 0.22, 0.28)
			if BoardModel.is_wall(c):
				ink = Color(0.24, 0.22, 0.26, 0.45)
			elif BoardModel.is_high(c):
				ink = Color(0.18, 0.22, 0.27, 0.36)
			elif BoardModel.is_gate(c):
				ink = Color(0.34, 0.26, 0.46, 0.42)
			draw_rect(r, ink, true)

	# The units. Drawn as plain plates in their team's colour, tinted toward the tier
	# colour the real board uses, so the backdrop and the game agree about what a tier 5
	# looks like without this file owning a second palette.
	for u in _board.units_view():
		if not u.is_alive():
			continue
		var at := origin + _slide_position(u) * tile
		var body := Rect2(at, Vector2(tile, tile)).grow(-tile * 0.11)
		var team := (Color(0.38, 0.66, 0.69) if u.team == BoardModel.TEAM_A
			else Color(0.83, 0.63, 0.39))
		var shade := team.lerp(UnitView.tier_color(u.data.tier), 0.35)
		# Wounded units fade rather than showing a health bar. A bar would be a second
		# reading of the same information and would make the backdrop look like the HUD.
		var full := u.stat(StatModifier.Stat.MAX_HP)
		var health := 1.0 if full <= 0.0 else clampf(u.current_hp / full, 0.0, 1.0)
		# Bright enough to be the only thing on this layer that reads, dim enough to stay
		# behind the menu. Both halves were got wrong in turn: at the grid's own alpha the
		# screenshot was a field of rectangles with no figures in it, and at 0.42-0.88 a
		# unit walked over the title and won.
		shade.a = 0.26 + 0.30 * health
		draw_rect(body, shade, true)
		draw_rect(body, Color(shade.lightened(0.35), minf(shade.a + 0.2, 1.0)), false,
			maxf(tile * 0.05, 1.5))

	# A scrim over the middle of the screen, last, so it sits on top of the battle.
	#
	# This is what makes the menu readable, and it is the opposite of a vignette: the
	# menu column is CENTRED, so the middle is the part that has to be quiet and the
	# edges are where the battle is allowed to be seen. Built as horizontal bands whose
	# darkness peaks in the middle and falls off toward the top and bottom, so there is
	# no visible edge to the shading.
	var rows_of_scrim := 64
	for i in rows_of_scrim:
		var t := float(i) / float(rows_of_scrim - 1)
		# A plateau, not a peak: full strength across the whole band the menu occupies,
		# easing off above and below it so there is no visible edge.
		var weight := 1.0
		if t < SCRIM_FROM:
			weight = clampf(t / maxf(SCRIM_FROM, 0.001), 0.0, 1.0)
		elif t > SCRIM_TO:
			weight = clampf((1.0 - t) / maxf(1.0 - SCRIM_TO, 0.001), 0.0, 1.0)
		weight = weight * weight * (3.0 - 2.0 * weight)
		draw_rect(_band(i, rows_of_scrim),
			Color(0.05, 0.055, 0.075, SCRIM_PEAK * weight), true)
