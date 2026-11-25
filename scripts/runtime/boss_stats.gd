class_name BossStats
extends RefCounted

## The boss defence's running tally, fed the same events the screen plays — so the
## counters move as the fight is SEEN, not as the simulation (which runs ahead)
## resolves it. Read live for the HUD counter and whole for the results screen.

var player_team := BoardModel.TEAM_B
var boss_uid := -1

var dealt := 0.0            ## everything the army dealt
var to_boss := 0.0
var to_summons := 0.0
var taken := 0.0            ## everything the army took
var deployed := 0           ## units the army put on the field
var lost := 0               ## of those, how many died
var summons_killed := 0
var crystals_broken := 0
var phase_reached := 0
var retreats := 0           ## boss retreats that ran their course
var by_type := {}           ## unit id -> damage dealt
var names := {}             ## unit id -> display name


func record(e: Dictionary, units: Dictionary) -> void:
	match String(e.get("kind", "")):
		"boss_start":
			boss_uid = int(e.uid)
		"damage":
			var victim: UnitInstance = units.get(int(e.uid), null)
			var source: UnitInstance = units.get(int(e.get("source_uid", -1)), null)
			var amount := float(e.get("amount", 0.0))
			if victim == null or amount <= 0.0:
				return
			if source != null and source != victim and source.team == player_team \
					and victim.team != player_team:
				dealt += amount
				if victim.uid == boss_uid:
					to_boss += amount
				else:
					to_summons += amount
				# One row per unit TYPE, whatever its tier: "Warden" and "Warden III" are
				# the same unit, merged up.
				var kind := base_name(source.data.display_name)
				kind = LUMPED.get(kind, kind)
				by_type[kind] = float(by_type.get(kind, 0.0)) + amount
				names[kind] = kind
			elif victim.team == player_team and not victim.structure:
				taken += amount
		"spawn", "summon":
			var u: UnitInstance = units.get(int(e.uid), null)
			if u != null and u.team == player_team and not u.structure \
					and not bool(e.get("restored", false)):
				deployed += 1
		"death":
			var u: UnitInstance = units.get(int(e.uid), null)
			if u == null:
				return
			if u.structure:
				crystals_broken += 1
			elif u.team == player_team:
				lost += 1
			elif u.uid != boss_uid:
				summons_killed += 1
		"boss_phase":
			phase_reached = maxi(phase_reached, int(e.get("index", 0)))
		"boss_retreat_end":
			if bool(e.get("completed", false)):
				retreats += 1


## Units counted under another's row in Top Damage: what a unit builds is its work.
const LUMPED := {"Sentry": "Engineer"}


static func base_name(display: String) -> String:
	## A unit's name without its tier numeral: "Vexer IV" -> "Vexer".
	var parts := display.split(" ")
	if parts.size() > 1 and parts[parts.size() - 1] in ["I", "II", "III", "IV", "V", "VI"]:
		parts.remove_at(parts.size() - 1)
	return " ".join(parts)


func top_dealers(n: int) -> Array:
	## [[name, damage], ...], biggest first.
	var rows := []
	for id in by_type:
		rows.append([String(names.get(id, id)), float(by_type[id])])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	return rows.slice(0, n)


static func short(v: float) -> String:
	## 950, 12.3k, 1.25M — a counter that fits on one line.
	if v >= 1.0e6:
		return "%.2fM" % (v / 1.0e6)
	if v >= 1.0e4:
		return "%.1fk" % (v / 1.0e3)
	return str(roundi(v))
