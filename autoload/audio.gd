extends Node

## Everything that makes a noise, in one place.
##
## Music is two looping tracks that cross over at the scene boundary — the menu
## has one, the battle scene has the other, and `play_music()` is a no-op when the
## track asked for is already the one playing, so moving between prep and battle
## inside the same scene never restarts it. That is what "plays all the time"
## means here: the round loop does not touch the music at all.
##
## Sound effects are pooled. One AudioStreamPlayer per sound would cut a swing
## short every time a second unit swung, and a battle has a dozen units swinging
## at once, so there is a ring of players and each shot takes the next one.

const MUSIC_DIR := "res://assets/music"

## The battle playlist, found by counting upward from battle_1.ogg until one is
## missing — same trick as the melee samples. Adding a third track is dropping
## battle_3.ogg into assets/music and giving it a name below; nothing else.
const BATTLE_PREFIX := "battle_%d"

## The boss pool, counted the same way. Separate from the battle tracks rather
## than mixed in with them, because whether these can come up in an ordinary
## round is a SETTING — see GameSetup.boss_in_pool — and a single list could not
## answer that question.
const BOSS_PREFIX := "boss_%d"

## Tracks are identified by NUMBER and nothing else — the menu shows "1", "2",
## "3". Names were tried and dropped: the files are placeholders that will be
## swapped out, a name in code has to be kept in step with a file on disk by hand,
## and "battle_7.ogg is track 7" needs no upkeep at all.
const SFX_DIR := "res://assets/sfx"

## Voice lines live apart from the effects on purpose. Everything in assets/sfx
## is the game's own sound; everything in assets/voice is borrowed placeholder
## material that will be pulled out. Keeping them in separate folders means
## removing the voices is deleting one folder and nothing else — no editing of
## this script, no dangling constant, no silent failure.
##
## Every unit shares these lines. There is deliberately no per-unit lookup here:
## one roster-wide voice is what the game actually wants today, and a per-unit
## pool with exactly one unit in it is machinery pretending to be a feature.
const VOICE_DIR := "res://assets/voice"

## How many effects may overlap. Eight is comfortably more than a busy tick ever
## needs and small enough that a stuck one is obvious.
const SFX_VOICES := 8

## Music sits under the effects on purpose: the swings are the feedback, the
## track is the room.
const MUSIC_DB := -14.0
const SFX_DB := -6.0

## Melee is quieter than everything else because there is simply more of it: a
## melee line is six units swinging on a loop three tiles apart, and at the shared
## level that stops being feedback and becomes a wall. Six decibels down is about
## half the loudness, which leaves the swings audible under the crits and the
## music instead of on top of them.
const MELEE_DB := -12.0

## The crit is meant to cut through a wall of swings, and it was doing it with
## level alone at -2 — the loudest thing in the game, several times a battle. It
## is a distinctive enough sample to carry on timbre instead, so it sits barely
## above the swings now and reads as a punctuation mark rather than an alarm.
const CRIT_DB := -11.0

## Merges happen a handful of times a prep phase and are the one thing the player
## did on purpose — but they happen in a quiet room with no battle to carry over,
## so they do not need the level the combat sounds fight for.
const MERGE_DB := -10.0

## A promotion or a windfall is a merge that got lucky, so it wants to be heard
## OVER the merge sound it lands on top of — but only just. Kept four decibels
## above MERGE_DB rather than at a fixed level, so quietening one does not turn
## the other into a jump scare.
const PROC_DB := MERGE_DB + 4.0

## Interface, not battle. It plays with nothing else going on, so it does not
## need the headroom the combat sounds fight over.
const CONFIRM_DB := -6.0

## The one moment in the round with nothing else happening, so it can be the
## loudest thing in the game without ever fighting anything for room.
const ROUND_START_DB := -2.0

## Well under the confirm: this fires on every click of an arrow you hold down
## to scroll through a roster, and at confirm's level that is a machine gun.
const SELECT_DB := -14.0

## Handling, not announcing. You pick a unit up a dozen times a prep phase,
## often without going through with it.
const PICKUP_DB := -12.0

## A death used to sit above the swing that caused it. It does not any more: a
## big trade drops four bodies inside a second and at that level the deaths, not
## the fighting, became what the battle sounded like. Now it sits just under the
## swings — present, countable, not the headline.
const DEATH_DB := -14.0

## Down with the melee swings, and for the same reason: a Warden's shield eats a
## dozen hits in a row, so this is one of the most frequently played sounds in
## the game and cannot sit anywhere near the top of the mix.
const SHIELD_DB := -13.0

## The beam belongs to one unit and it fires continuously, so unlike a swing it
## is never a single event you want to notice — it is a texture that runs under
## the fight. It sat at the shared effects level for a long time and was by some
## distance the loudest thing on any board with a Transcendence on it.
const LASER_DB := -15.0

## A voice line rides ON TOP of the death thump rather than replacing it — the
## thump is the event, the cry is the character — so it sits a little above the
## thump to be heard through it, and still under the swings.
const VOICE_DB := -12.0

## An overkill is rare and it is the game telling you something happened. Three
## decibels over the ordinary line is enough to read as "that one was different"
## without becoming the loudest thing on the field.
const OVERKILL_DB := VOICE_DB + 3.0

var _music: AudioStreamPlayer = null
var _music_now := ""
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0

var _melee: Array[AudioStream] = []
var _ranged: Array[AudioStream] = []
var _laser: AudioStream = null
var _crit: AudioStream = null

## The three prep-phase sounds. They are the only ones that fire outside a
## battle, and the only ones that answer something the player did on purpose
## rather than something a unit did on a timer.
var _merge: AudioStream = null
var _windfall: AudioStream = null
var _promotion: AudioStream = null

var _death: AudioStream = null

## A hit stopped by a shield. Fires alongside the swing that caused it, not
## instead of it — you hear the blow and then the shield answering it.
var _shield_hit: AudioStream = null

## The two voice pools, shared by every unit on the board. Both may be empty —
## the whole folder is placeholder material and the game has to keep working the
## day it is deleted, which is why nothing here warns about a missing file.
var _death_voice: Array[AudioStream] = []
var _overkill_voice: Array[AudioStream] = []

## The one UI sound. Every button that commits to something plays it — starting a
## match, taking a buff, closing the loadout editor — so the interface answers
## back in one voice instead of a different noise per screen.
var _confirm: AudioStream = null

## The bell. Plays once when the fighting actually starts, not when the button is
## pressed — there is a wind-up hold between the two.
var _round_start: AudioStream = null

## The lightest sound in the game. Cycling a loadout slot fires it on every
## click and a slot gets clicked through a dozen times, so it has to be a tap and
## not an announcement.
var _select: AudioStream = null

## Lifting a unit off the board. Fires once per drag, and a prep phase is a lot
## of drags, so it lives down with the other handling sounds rather than up with
## the ones that announce something.
var _pickup: AudioStream = null

## Its own stream so the pick is reproducible per battle rather than depending on
## how many sounds happened to have played before it.
var _rng := RandomNumberGenerator.new()

var enabled := true

## Overall loudness, 0 to 1, driven by the slider in the settings menu.
##
## Applied to the Master BUS rather than to any of the level constants above. The
## mix ladder — melee under the crits, the crits under the round bell — took a
## lot of passes to get right, and a volume control that touched those numbers
## would flatten it the moment it was moved. One fader on the bus moves all of
## them together and leaves the relationships between them exactly as they are.
var volume := 1.0:
	set(value):
		volume = clampf(value, 0.0, 1.0)
		if not is_inside_tree():
			return
		_apply_volume()

## How many battle_N.ogg files there are. Counted once at startup.
var battle_track_count := 0

## And how many boss_N.ogg files. Zero is a perfectly good answer — the boss
## rule simply never fires and the toggle has nothing to let in.
var boss_track_count := 0


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	# Muted outright at zero rather than left at some very small decibel figure.
	# linear_to_db(0) is negative infinity, and a fader that reads "0%" should be
	# silence and not a faint hiss.
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(volume))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_volume()
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = MUSIC_DB
	add_child(_music)
	# Looping is set on the stream rather than by reacting to `finished`, which
	# would leave an audible gap at the loop point.
	_music.finished.connect(_restart_music)

	for i in SFX_VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = "Master"
		v.volume_db = SFX_DB
		add_child(v)
		_voices.append(v)

	_melee = _load_run("melee_%d.wav", 6)
	_ranged = _load_run("ranged_%d.wav", 2)
	_laser = _load_one("laser.wav")
	_crit = _load_one("critical.wav")
	_merge = _load_one("merge.wav")
	_windfall = _load_one("windfall.wav")
	_promotion = _load_one("promotion.wav")
	_death = _load_one("death.wav")
	_shield_hit = _load_one("shield_hit.wav")
	_confirm = _load_one("confirm.wav")
	_round_start = _load_one("round_start.wav")
	_select = _load_one("select.wav")
	_pickup = _load_one("pickup.wav")
	_death_voice = _load_voice_run("death")
	_overkill_voice = _load_voice_run("overkill")
	while ResourceLoader.exists("%s/%s.ogg" % [
			MUSIC_DIR, BATTLE_PREFIX % (battle_track_count + 1)]):
		battle_track_count += 1
	if battle_track_count == 0:
		push_warning("Audio: no battle tracks in %s" % MUSIC_DIR)
	while ResourceLoader.exists("%s/%s.ogg" % [
			MUSIC_DIR, BOSS_PREFIX % (boss_track_count + 1)]):
		boss_track_count += 1
	_rng.randomize()


func _load_one(file: String) -> AudioStream:
	var path := "%s/%s" % [SFX_DIR, file]
	if not ResourceLoader.exists(path):
		# Missing audio is never fatal. The game is perfectly playable silent, and
		# a missing file should not take the whole scene down with it.
		push_warning("Audio: no such sound '%s'" % path)
		return null
	return load(path) as AudioStream


func _load_voice_run(kind: String) -> Array[AudioStream]:
	## Counts upward from _1 until a number is missing, the same trick the melee
	## pool uses — except the count is not written down anywhere, because these
	## files are going to be deleted and a hard-coded 6 would turn that deletion
	## into six warnings. Adding a seventh death line is dropping death_7.wav into
	## assets/voice; removing the voices is deleting the folder. Neither touches
	## this script.
	var out: Array[AudioStream] = []
	var n := 1
	while true:
		var path := "%s/%s_%d.wav" % [VOICE_DIR, kind, n]
		if not ResourceLoader.exists(path):
			break
		var s := load(path) as AudioStream
		if s != null:
			out.append(s)
		n += 1
	return out


func _load_run(pattern: String, count: int) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for i in range(1, count + 1):
		var s := _load_one(pattern % i)
		if s != null:
			out.append(s)
	return out


func _restart_music() -> void:
	if _music.stream != null:
		_music.play()


func play_music(name: String) -> void:
	# Idempotent by design: called on every scene ready and every round start, so
	# it has to be free to call when nothing needs to change.
	if not enabled or name == _music_now:
		return
	var path := "%s/%s.ogg" % [MUSIC_DIR, name]
	if not ResourceLoader.exists(path):
		push_warning("Audio: no such track '%s'" % path)
		return
	_music_now = name
	_music.stream = load(path) as AudioStream
	_music.play()


func now_playing() -> String:
	## Which track is on the music player right now, or "" for silence. Exists for
	## the settings screen's track preview: it has to put back whatever it
	## interrupted, and only this knows what that was.
	return _music_now


func battle_track(index: int) -> String:
	## 1-based, matching the file names and what the menu shows.
	return BATTLE_PREFIX % index


func boss_track(index: int) -> String:
	## 1-based, matching the file names.
	return BOSS_PREFIX % index


func battle_track_name(index: int) -> String:
	return str(index)


func boss_track_name(index: int) -> String:
	# "B1", "B2" — numbered like the battle tracks but marked, so a boss track
	# switched into the ordinary rotation is still identifiable in the menu.
	return "B%d" % index


func stop_music() -> void:
	_music_now = ""
	_music.stop()


func _free_voice() -> AudioStreamPlayer:
	# Prefer one that is idle; if every voice is busy, take the oldest anyway
	# rather than dropping the sound. A clipped tail is better than silence on the
	# hit that mattered.
	for i in _voices.size():
		var idx := (_next_voice + i) % _voices.size()
		if not _voices[idx].playing:
			_next_voice = (idx + 1) % _voices.size()
			return _voices[idx]
	var take := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return take


func _fire(stream: AudioStream, db: float, pitch := 1.0) -> void:
	if not enabled or stream == null:
		return
	var v := _free_voice()
	v.stream = stream
	v.volume_db = db
	v.pitch_scale = pitch
	v.play()


func _pick(pool: Array[AudioStream]) -> AudioStream:
	if pool.is_empty():
		return null
	return pool[_rng.randi_range(0, pool.size() - 1)]


func play_attack(kind: UnitData.AttackType, beam := false) -> void:
	# The laser belongs to ONE unit. `beam_attack` is set on exactly one row in
	# the whole table — Transcendence — so this branch is "is this Transcendence"
	# spelled in terms of what the unit does rather than what it is called, which
	# is what keeps it working if a second beam unit ever appears.
	if beam:
		_fire(_laser, LASER_DB)
		return
	# Everything else that is not a melee swing plays the ranged pool, spells
	# included. Spells used to borrow the laser and no longer do: with one unit
	# owning that sound, hearing it means Transcendence is firing and nothing else.
	if kind != UnitData.AttackType.MELEE:
		_fire(_pick(_ranged), SFX_DB, _rng.randf_range(0.96, 1.04))
		return
	# A little pitch wander on top of six samples: six swings on a loop still
	# reads as a loop, and the variation is what stops it.
	_fire(_pick(_melee), MELEE_DB, _rng.randf_range(0.94, 1.06))


func play_crit() -> void:
	_fire(_crit, CRIT_DB)


func play_merge() -> void:
	_fire(_merge, MERGE_DB)


func play_promotion() -> void:
	# Deliberately NOT layered under the merge sound at the same instant — the
	# view spaces the proc labels after the merge label, and these follow them, so
	# you hear "merged... and it promoted" rather than one thicker chord.
	_fire(_promotion, PROC_DB)


func play_windfall() -> void:
	_fire(_windfall, PROC_DB)


func play_confirm() -> void:
	_fire(_confirm, CONFIRM_DB)


func play_round_start() -> void:
	_fire(_round_start, ROUND_START_DB)


func play_pickup() -> void:
	_fire(_pickup, PICKUP_DB)


func play_select() -> void:
	# A touch of pitch wander, because holding an arrow down fires this faster
	# than any other sound in the game and identical repeats read as a buzz.
	_fire(_select, SELECT_DB, _rng.randf_range(0.96, 1.04))


func play_death() -> void:
	# A little pitch wander for the same reason the swings have it: a wipe kills
	# six units in two seconds, and six identical sounds read as one glitch.
	_fire(_death, DEATH_DB, _rng.randf_range(0.93, 1.07))


func play_shield_hit() -> void:
	# Pitch wander, like the swings. A Warden under fire plays this several times
	# a second and identical repeats read as a stuck sample rather than a shield.
	_fire(_shield_hit, SHIELD_DB, _rng.randf_range(0.94, 1.06))


func play_death_voice(overkill := false) -> void:
	## Layered over play_death(), not instead of it: the thump is the event, the
	## cry is the character. With the folder empty this does nothing at all and
	## every death is just the thump, which is why it is safe to call on every
	## death in the game without checking anything first.
	##
	## The two pools are exclusive. An overkill plays an overkill line and NOT an
	## ordinary one — that is the whole point of having a separate pool, and
	## playing both would only sound like a mistake. Nor does an overkill fall
	## back to the ordinary pool when the overkill pool is empty: the line is
	## supposed to mean something, and a fallback would make it mean nothing.
	var pool := _overkill_voice if overkill else _death_voice
	# No pitch wander here. It works on a thump because a thump has no pitch to
	# speak of; on a voice it sounds like a broken tape.
	_fire(_pick(pool), OVERKILL_DB if overkill else VOICE_DB)
