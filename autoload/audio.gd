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

## Boss defence. All synthesized by tools/generate_sfx.gd. The charge-up is the
## boss gathering herself for a big move (it used to borrow the round-start sound,
## which says "a round begins", not "get out of the way"); the slam is any of her
## moves landing (it used to borrow the critical-hit sting).
const BOSS_CHARGE_DB := -8.0
const BOSS_SLAM_DB := -9.0
const SHADE_DB := -10.0
const RECRUIT_DB := -9.0
const UPGRADE_DB := -8.0
var _boss_charge: AudioStream = null
var _boss_slam: AudioStream = null
var _shade_summon: AudioStream = null
var _recruit: AudioStream = null
var _upgrade: AudioStream = null

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

## The three buses everything plays through, each feeding Master.
##
## They exist so the sliders can exist. Until now every sound in the game — the music,
## the swings, the death lines — went straight to Master, so there was exactly one fader
## and it moved all of them together.
##
## Declared in default_bus_layout.tres AND ensured at runtime by _ensure_buses().
##
## The layout file is not optional. The web build plays sound through the browser's
## own audio graph ("sample" playback), and that graph is built from the bus layout
## the engine starts with — a bus added from script afterwards exists in AudioServer
## but is never wired to the speakers, so every sound routed through it was silent on
## the web while the desktop build was fine. _ensure_buses() stays as the safety net
## for the opposite failure: if the layout is deleted or a bus renamed in the audio
## panel, the lookups would otherwise return -1 and the sliders would do nothing.
## A test checks the layout names match these constants.
const MUSIC_BUS := "Music"
const SFX_BUS := "Effects"
const VOICE_BUS := "Voice"

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

## The three category faders, each on its own bus and each multiplying with Master rather
## than replacing it. Same reasoning as `volume` above and it is the whole reason these
## are buses: within a category the mix ladder is untouched, so pulling the effects down
## keeps the crits above the swings by exactly as much as before.
var music_volume := 1.0:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_bus(MUSIC_BUS, music_volume)

var sfx_volume := 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_bus(SFX_BUS, sfx_volume)

## Kept apart from the effects deliberately, and not only for the mix. Everything in
## assets/voice is borrowed placeholder material that is going to be pulled out, so being
## able to switch exactly that off without touching the game's own sounds is worth a
## fader of its own while it is still there.
var voice_volume := 1.0:
	set(value):
		voice_volume = clampf(value, 0.0, 1.0)
		_apply_bus(VOICE_BUS, voice_volume)

## How many battle_N.ogg files there are. Counted once at startup.
var battle_track_count := 0

## And how many boss_N.ogg files. Zero is a perfectly good answer — the boss
## rule simply never fires and the toggle has nothing to let in.
var boss_track_count := 0


func _apply_volume() -> void:
	_apply_bus("Master", volume)


func _apply_bus(name: String, level: float) -> void:
	## One fader, on one bus. Shared by all four rather than written out per category,
	## because the mute-at-zero rule below is the kind of thing that gets remembered in
	## three places out of four.
	var bus := AudioServer.get_bus_index(name)
	if bus < 0:
		return
	# Muted outright at zero rather than left at some very small decibel figure.
	# linear_to_db(0) is negative infinity, and a fader that reads "0%" should be
	# silence and not a faint hiss.
	AudioServer.set_bus_mute(bus, level <= 0.0)
	if level > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(level))


func _ensure_buses() -> void:
	## Adds the three category buses if they are not already there, each routed to Master.
	##
	## Idempotent on purpose: an autoload is built once per run, but this also has to
	## survive a project that DOES ship a bus layout naming some of them, and adding a
	## second bus with the same name would leave the lookups pointing at whichever one
	## the server happened to return.
	for name in [MUSIC_BUS, SFX_BUS, VOICE_BUS]:
		if AudioServer.get_bus_index(name) >= 0:
			continue
		var at := AudioServer.bus_count
		AudioServer.add_bus(at)
		AudioServer.set_bus_name(at, name)
		AudioServer.set_bus_send(at, "Master")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Before anything is routed to them, and before the faders are applied — a player
	# assigned to a bus that does not exist yet falls back to Master silently, and the
	# symptom is a slider that moves and changes nothing.
	_ensure_buses()
	_apply_volume()
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)
	_apply_bus(VOICE_BUS, voice_volume)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	_music.volume_db = MUSIC_DB
	add_child(_music)
	# Looping is set on the stream rather than by reacting to `finished`, which
	# would leave an audible gap at the loop point.
	_music.finished.connect(_restart_music)

	for i in SFX_VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = SFX_BUS
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
	_boss_charge = _load_one("boss_charge.wav")
	_boss_slam = _load_one("boss_slam.wav")
	_shade_summon = _load_one("shade_summon.wav")
	_recruit = _load_one("recruit.wav")
	_upgrade = _load_one("upgrade.wav")
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
		_music.play(maxf(_segment_from, 0.0))


## A stretch of a file looped as a track of its own — the boss defence's phase
## music, which is several pieces cut from one long file. -1 when the music player
## is playing an ordinary whole track.
var _segment_from := -1.0
var _segment_to := -1.0


static func segment_wrap(position: float, from: float, to: float) -> float:
	## Where the music should jump to, or -1 to carry on. Past the end of the stretch
	## it goes back to its start PLUS however far it overshot, so the beat keeps its
	## place: a loop checked once a frame would otherwise drop the overshoot and
	## stutter. A stretch that runs to the end of the file (`to` of 0) is looped by
	## the stream itself instead — see play_segment — which is sample-accurate.
	if to > from and position >= to:
		return from + fmod(position - to, to - from)
	return -1.0


func play_segment(key: String, path: String, from: float, to: float) -> bool:
	## Loops `from`..`to` seconds of `path` (to 0 = the end of the file). Returns false,
	## and leaves the current music alone, if the file is not there — the boss music
	## is personal and never exported, so its absence is normal on the web.
	if not enabled:
		return false
	if key == _music_now:
		return true
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var s := load(path) as AudioStream
	if s == null:
		return false
	var start := maxf(from, 0.0)
	var wrap_to := to
	if s is AudioStreamMP3 and to > from:
		# A stretch that ends mid-file: cut the file just after it, so the stream ends
		# there and the engine itself loops it, on the exact sample. A wrap checked
		# once a frame lands up to a buffer late and is heard as a hiccup.
		var cut := _mp3_cut(path, s as AudioStreamMP3, to)
		if cut != null:
			# The cut falls on the first MP3 frame boundary at or after `to` (frames
			# are 26 ms); the loop start moves by the same amount, so the loop is
			# exactly `to - from` long and keeps the beat.
			cut.loop = true
			cut.loop_offset = from + (cut.get_length() - to)
			s = cut
			wrap_to = 0.0
	elif s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		# A stretch that runs to the end of the file loops in the stream itself, back
		# to its start: the engine does that on the exact sample. Anything else that
		# ends mid-file must not loop in the stream, or it would play on into the
		# next piece; _process wraps it instead.
		s = s.duplicate()
		s.set("loop", to <= from)
		s.set("loop_offset", start)
	_music_now = key
	_segment_from = start
	_segment_to = wrap_to
	_music.stream = s
	_music.play(start)
	set_process(true)
	return true


## Cut-down copies of MP3s, by path and end time: cutting re-reads the whole file.
var _cuts := {}


func _mp3_cut(path: String, s: AudioStreamMP3, to: float) -> AudioStreamMP3:
	var key := "%s@%.4f" % [path, to]
	if _cuts.has(key):
		return _cuts[key]
	var bytes := mp3_bytes_until(s.data, to)
	if bytes.is_empty():
		return null
	var cut := AudioStreamMP3.new()
	cut.data = bytes
	# The decoder may hide a few samples at the start (encoder delay); the cut is
	# only good if it really ends at or just after `to`.
	if cut.get_length() < to - 0.001 or cut.get_length() > to + 0.1:
		return null
	_cuts[key] = cut
	return cut


static func mp3_bytes_until(data: PackedByteArray, seconds: float) -> PackedByteArray:
	## The file up to the end of the first MP3 frame that finishes at or after
	## `seconds` (counting audio frames from the first), or empty if it is not an MP3
	## this can walk. Frames only ever borrow bits from frames BEFORE them, so the
	## cut-down file decodes exactly like the start of the whole one.
	var i := 0
	if data.size() >= 10 and data[0] == 0x49 and data[1] == 0x44 and data[2] == 0x33:
		i = 10 + ((data[6] & 0x7f) << 21 | (data[7] & 0x7f) << 14 \
			| (data[8] & 0x7f) << 7 | (data[9] & 0x7f))
		if data[5] & 0x10:
			i += 10
	const RATES_1 := [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
	const RATES_2 := [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
	const HZ := [44100, 48000, 32000]
	var samples := 0
	var frames := 0
	var first := true
	var tag_at := -1
	var tag_end := -1
	var delay := 0
	while i + 4 <= data.size():
		if data[i] != 0xff or (data[i + 1] & 0xe0) != 0xe0:
			return PackedByteArray()
		var version := (data[i + 1] >> 3) & 3
		var layer := (data[i + 1] >> 1) & 3
		var rate_i := data[i + 2] >> 4
		var hz_i := (data[i + 2] >> 2) & 3
		if version == 1 or layer != 1 or rate_i == 0 or rate_i == 15 or hz_i == 3:
			return PackedByteArray()
		var mpeg1 := version == 3
		var hz: int = HZ[hz_i] / (1 if mpeg1 else (2 if version == 2 else 4))
		var kbps: int = (RATES_1 if mpeg1 else RATES_2)[rate_i]
		var length := (144000 if mpeg1 else 72000) * kbps / hz + ((data[i + 2] >> 1) & 1)
		# A LAME/Xing header frame holds no audio: it does not count.
		var tag := false
		if first:
			for at in range(i + 4, mini(i + 40, data.size() - 4)):
				var word := data.slice(at, at + 4).get_string_from_ascii()
				if word == "Xing" or word == "Info":
					tag = true
					tag_at = at
					tag_end = i + length
					# The decoder hides the encoder's delay at the start, so the cut
					# has to run that much further to end at or after `seconds`.
					var ext := _tag_extension(data, at, tag_end)
					if ext >= 0:
						delay = ((data[ext] << 4) | (data[ext + 1] >> 4)) + 529
			first = false
		i += length
		if not tag:
			samples += 1152 if mpeg1 else 576
			frames += 1
			if float(samples - delay) / hz >= seconds:
				var out := data.slice(0, mini(i, data.size()))
				if tag_at >= 0:
					_retag(out, tag_at, tag_end, frames)
				return out
	return PackedByteArray()


static func _tag_extension(data: PackedByteArray, at: int, end: int) -> int:
	## Where the encoder's delay and padding sit in a Xing/Info header frame (two
	## 12-bit numbers, after the optional counts and table), or -1 if it has none.
	var flags := data[at + 7]
	var p := at + 8
	for bit: int in [1, 2, 4, 8]:
		if flags & bit:
			p += 100 if bit == 4 else 4
	if p + 24 >= end or data[p] == 0:
		return -1
	return p + 21


static func _retag(out: PackedByteArray, at: int, end: int, frames: int) -> void:
	## The header frame says how long the whole file is, and decoders believe it:
	## rewrite it for the cut — its frame and byte counts, and no end padding (the
	## padding belonged to the whole file's last frame, which is gone).
	var flags := out[at + 7]
	var p := at + 8
	if flags & 1:
		for k in 4:
			out[p + k] = (frames >> (24 - 8 * k)) & 0xff
		p += 4
	if flags & 2:
		for k in 4:
			out[p + k] = (out.size() >> (24 - 8 * k)) & 0xff
	var ext := _tag_extension(out, at, end)
	if ext >= 0:
		# A stored 529 reads back as no padding at all.
		out[ext + 1] = (out[ext + 1] & 0xf0) | (529 >> 8)
		out[ext + 2] = 529 & 0xff


func _process(_delta: float) -> void:
	if _segment_from < 0.0 or not _music.playing:
		return
	# The precise playhead: the position at the last mix plus the time since it, so
	# the check is not a whole audio buffer late.
	var at := _music.get_playback_position() + AudioServer.get_time_since_last_mix()
	var jump := segment_wrap(at, _segment_from, _segment_to)
	if jump >= 0.0:
		_music.seek(jump)


func play_music(name: String) -> void:
	# Idempotent by design: called on every scene ready and every round start, so
	# it has to be free to call when nothing needs to change.
	if not enabled or name == _music_now:
		return
	var path := "%s/%s.ogg" % [MUSIC_DIR, name]
	if not ResourceLoader.exists(path):
		push_warning("Audio: no such track '%s'" % path)
		return
	_segment_from = -1.0
	_segment_to = -1.0
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
	_segment_from = -1.0
	_segment_to = -1.0
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


func _fire(stream: AudioStream, db: float, pitch := 1.0, bus := SFX_BUS) -> void:
	## `bus` is what lets the voice lines be faded separately from the game's own sounds
	## while still sharing this one pool of players. Set per PLAY rather than per player,
	## because the pool is a ring of eight reused for everything — pinning a bus to a
	## player would mean a voice line landing on whichever slot came free and playing
	## through the effects fader about seven times out of eight.
	if not enabled or stream == null:
		return
	var v := _free_voice()
	v.bus = bus
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


func play_boss_charge() -> void:
	_fire(_boss_charge, BOSS_CHARGE_DB)


func play_boss_slam() -> void:
	# A little pitch wander: Onrush lands nine of these in a row.
	_fire(_boss_slam, BOSS_SLAM_DB, _rng.randf_range(0.95, 1.05))


func play_shade_summon() -> void:
	_fire(_shade_summon, SHADE_DB, _rng.randf_range(0.96, 1.04))


func play_recruit() -> void:
	_fire(_recruit, RECRUIT_DB)


func play_upgrade() -> void:
	_fire(_upgrade, UPGRADE_DB)


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
	_fire(_pick(pool), OVERKILL_DB if overkill else VOICE_DB, 1.0, VOICE_BUS)
