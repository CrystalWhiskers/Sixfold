extends SceneTree

## Writes the boss defence's synthesized sound effects into assets/sfx. Every sound
## here is made from sine waves and filtered noise in this file — no samples — so it
## can be regenerated, retuned and shipped freely.
##
##   godot --headless --script res://tools/generate_sfx.gd
##
## Then open the editor (or run `godot --headless --import`) so the new .wav files
## are imported. Rerunning OVERWRITES the files listed in _initialize.

const RATE := 44100
const OUT := "res://assets/sfx"

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 6
	_save("boss_charge.wav", _boss_charge())
	_save("boss_slam.wav", _boss_slam())
	_save("shade_summon.wav", _shade_summon())
	_save("recruit.wav", _recruit())
	_save("upgrade.wav", _upgrade())
	_save("boss_teleport.wav", _boss_teleport())
	quit()


func _boss_teleport() -> PackedFloat32Array:
	## Her retreat: a sharp rising shimmer that snaps off — there, then gone.
	var n := int(RATE * 0.7)
	var out := PackedFloat32Array()
	out.resize(n)
	var p := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / 0.7
		p += TAU * lerpf(220.0, 1760.0, k * k) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		hp = noise - hp * 0.6
		var e := sin(minf(k / 0.85, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.85, 1.0, k))
		out[i] = (sin(p) * 0.7 + sin(p * 1.5) * 0.3 + hp * 0.25 * k) * e
	return out


func _save(file: String, samples: PackedFloat32Array) -> void:
	# Normalised to a fixed peak so every effect starts from the same loudness and the
	# per-sound levels in Audio are the only place loudness is decided.
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, clampi(roundi(samples[i] / peak * 0.89 * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	var path := "%s/%s" % [OUT, file]
	print("  ", path, "  err=", w.save_to_wav(ProjectSettings.globalize_path(path)),
		"  %.2fs" % (float(samples.size()) / RATE))


static func _env(t: float, attack: float, length: float) -> float:
	## A soft rise over `attack`, then a fall to nothing at `length`.
	if t < attack:
		return sin(t / attack * PI * 0.5)
	return clampf(1.0 - (t - attack) / maxf(length - attack, 0.001), 0.0, 1.0)


func _boss_charge() -> PackedFloat32Array:
	## The wind-up before a big move: a low rumble that swells and climbs, its throb
	## getting faster, so it reads as "something is coming" rather than a hit.
	var n := int(RATE * 1.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var phase2 := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / 1.5
		var hz := lerpf(48.0, 150.0, k * k)
		phase += TAU * hz / RATE
		phase2 += TAU * hz * 1.503 / RATE
		# Filtered noise whose filter opens as it builds.
		var cut := lerpf(0.02, 0.22, k)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * cut
		var throb := 0.6 + 0.4 * sin(TAU * lerpf(5.0, 16.0, k) * t)
		var swell := pow(k, 1.4) * (1.0 - smoothstep(0.9, 1.0, k))
		out[i] = (sin(phase) * 0.8 + sin(phase2) * 0.3 + lp * 1.6) * throb * swell
	return out


func _boss_slam() -> PackedFloat32Array:
	## The blow landing: a short downward whoosh into a deep thud.
	var n := int(RATE * 0.75)
	var out := PackedFloat32Array()
	out.resize(n)
	var bp := 0.0
	var lp := 0.0
	var phase := 0.0
	var hit := 0.11
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		if t < hit:
			# The whoosh: noise through a band that slides down.
			var k := t / hit
			var noise := _rng.randf_range(-1.0, 1.0)
			lp += (noise - lp) * lerpf(0.5, 0.12, k)
			bp += (lp - bp) * 0.25
			s += (lp - bp) * sin(k * PI) * 0.9
		else:
			var u := t - hit
			phase += TAU * lerpf(90.0, 38.0, minf(u / 0.25, 1.0)) / RATE
			s += sin(phase) * exp(-u * 6.0) * 1.2
			# The crack of the impact itself.
			lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.35
			s += lp * exp(-u * 28.0) * 0.9
		out[i] = s
	return out


func _shade_summon() -> PackedFloat32Array:
	## A shade stepping out of its circle: a dark, sucking swell of two detuned low
	## tones under breathy noise, falling away.
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	var p1 := 0.0
	var p2 := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var hz := lerpf(150.0, 70.0, t / 0.9)
		p1 += TAU * hz / RATE
		p2 += TAU * hz * 1.06 / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.08
		var e := _env(t, 0.35, 0.9)
		out[i] = (sin(p1) * 0.6 + sin(p2) * 0.6 + lp * 1.4) * e * e
	return out


func _bell(out: PackedFloat32Array, start: float, hz: float, decay: float, gain: float) -> void:
	var from := int(start * RATE)
	for i in range(from, out.size()):
		var t := float(i - from) / RATE
		var e := exp(-t * decay) * minf(t / 0.004, 1.0)
		out[i] += (sin(TAU * hz * t) + 0.35 * sin(TAU * hz * 2.0 * t)
			+ 0.12 * sin(TAU * hz * 3.01 * t)) * e * gain


func _recruit() -> PackedFloat32Array:
	## A new unit signing on: two quick bright notes, up a fifth.
	var out := PackedFloat32Array()
	out.resize(int(RATE * 0.45))
	_bell(out, 0.0, 659.25, 14.0, 0.7)
	_bell(out, 0.075, 987.77, 10.0, 0.8)
	return out


func _upgrade() -> PackedFloat32Array:
	## A level bought: a rising four-note arpeggio that rings on.
	var out := PackedFloat32Array()
	out.resize(int(RATE * 0.9))
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		_bell(out, 0.065 * i, notes[i], 7.0 if i == notes.size() - 1 else 11.0,
			0.55 + 0.1 * i)
	return out
