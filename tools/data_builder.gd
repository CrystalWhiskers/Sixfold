class_name DataBuilder
extends RefCounted

const UNITS_DIR := "res://data/units"
const ABILITY_DIR := "res://data/abilities"
const LOADOUT_DIR := "res://data/loadouts"
const BUFF_DIR := "res://data/buffs"
const MAP_DIR := "res://data/maps"

const TIERS := 6
const HP_SCALE := 2.0
const DMG_SCALE := 2.0

# A map is fair when the halves match: an odd board needs the neutral divider,
# an even one splits on its own and must not have it.
const MAP_TABLE := [

	{
		id = &"standard", name = "Standard", w = 6, h = 11, neutral = true,
		note = "The default. Five rows each with a no-man's row between them.",
	},
	{
		id = &"skirmish", name = "Skirmish", w = 6, h = 8, neutral = false,
		note = "Short and undivided — the two front ranks start in each other's faces.",
	},
	{
		id = &"the_pit", name = "The Pit", w = 4, h = 9, neutral = true,
		note = "Narrow and shallow. Sixteen tiles a side, so you merge or you drown.",
	},
	{
		id = &"broad_front", name = "Broad Front", w = 9, h = 11, neutral = true,
		note = "Wide and divided. Room to spread out, and a long walk to the enemy.",
	},
	{
		id = &"the_crush", name = "The Crush", w = 8, h = 6, neutral = false,
		note = "Wide, shallow, no divider. Everything is in range of everything almost at once.",
	},
	{
		id = &"the_long_march", name = "The Long March", w = 5, h = 15, neutral = true,
		note = "A deep corridor. Ranged units get to fire for a long time before anything arrives.",
	},
	{
		id = &"the_duel", name = "The Duel", w = 3, h = 7, neutral = true,
		note = "Three tiles wide and nine to a side. There is no flank, no cover and nowhere to put a mistake.",
	},
	{
		id = &"killing_field", name = "Killing Field", w = 13, h = 9, neutral = true,
		rows = [
			"^^^^^^^^^^^^^",
			"...//...//...",
			".............",
			".............",
			".............",
			".............",
			".............",
			"...//...//...",
			"^^^^^^^^^^^^^",
		],
		note = "Thirteen wide and shallow, with a firing step along both backs. Almost everything is in range of almost everything from the opening tick.",
	},
	{
		id = &"the_steppes", name = "The Steppes", w = 11, h = 13, neutral = true,
		rows = [
			"^^^^^^^^^^^",
			"..//...//..",
			"..^^^^^^^..",
			"....//.....",
			"....^^^....",
			"....//.....",
			"...........",
			"....//.....",
			"....^^^....",
			"....//.....",
			"..^^^^^^^..",
			"..//...//..",
			"^^^^^^^^^^^",
		],
		note = "Wide open ground in terraces. Every ridge is a range band for whoever gets to it, and the back rank of each side is the highest ground on the board.",
	},
	{
		id = &"the_cauldron", name = "The Cauldron", w = 11, h = 11, neutral = true,
		rows = [
			"..//...//..",
			".^^^^^^^^^.",
			".^.......^.",
			".^.......^.",
			".^.......^.",
			".^/...../^.",
			".^.......^.",
			".^.......^.",
			".^.......^.",
			".^^^^^^^^^.",
			"..//...//..",
		],
		note = "A rim of high ground all the way round a low floor. Ranged units want the wall; melee wants them off it.",
	},
	{
		id = &"the_quarry", name = "The Quarry", w = 9, h = 11, neutral = true,
		rows = [
			".........",
			".........",
			".........",
			".#.#.#.#.",
			".........",
			"#.#.#.#.#",
			".........",
			".#.#.#.#.",
			".........",
			".........",
			".........",
		],
		note = "Loose stone scattered across the middle. Nothing is truly blocked, but no shot crosses the board cleanly, and pierce and beams die on the first block they meet.",
	},
	{
		id = &"the_shatter", name = "The Shatter", w = 9, h = 11, neutral = true,
		rows = [
			".........",
			"..X...X..",
			".........",
			"X..X.X..X",
			".........",
			".X.X.X.X.",
			".........",
			"X..X.X..X",
			".........",
			"..X...X..",
			".........",
		],
		note = "The Quarry with holes where the stone was. The walk is the same and the cover is gone: everything can see everything, and nothing can walk straight at it.",
	},
	{
		id = &"the_grove", name = "The Grove", w = 7, h = 11, neutral = true,
		rows = [
			".......",
			"..#.#..",
			".#...#.",
			"...#...",
			".#...#.",
			"..#.#..",
			".#...#.",
			"...#...",
			".#...#.",
			"..#.#..",
			".......",
		],
		note = "Stone pillars scattered the whole way down. There is no clean shot anywhere on this board — everything happens at the range you find each other.",
	},
	{
		id = &"the_warrens", name = "The Warrens", w = 6, h = 11, neutral = true,
		rows = [
			"......",
			".####.",
			"......",
			"..##..",
			"......",
			"......",
			"......",
			"..##..",
			"......",
			".####.",
			"......",
		],
		note = "Blocks of stone break both halves into lanes. Nothing walks straight at anything.",
	},
	{
		id = &"the_spine", name = "The Spine", w = 9, h = 11, neutral = true,
		rows = [
			"....#....",
			"....#....",
			".........",
			"....#....",
			"....#....",
			".........",
			"....#....",
			"....#....",
			".........",
			"....#....",
			"....#....",
		],
		note = "One wall down the length of the board with three doors through it. Two lanes that can reinforce each other, but only at three places, and never by shooting across.",
	},
	{
		id = &"the_ring", name = "The Ring", w = 9, h = 11, neutral = true,
		rows = [
			".........",
			".........",
			".........",
			"..#####..",
			"..#####..",
			"..#####..",
			"..#####..",
			"..#####..",
			".........",
			".........",
			".........",
		],
		note = "A block of stone in the dead centre that nothing crosses and nothing sees through. The fight is two separate flank fights, and neither side can help the other.",
	},
	{
		id = &"three_roads", name = "Three Roads", w = 11, h = 13, neutral = true,
		rows = [
			"...........",
			"...........",
			"...#...#...",
			"...#...#...",
			"...%...%...",
			"...%...%...",
			"...%...%...",
			"...%...%...",
			"...%...%...",
			"...#...#...",
			"...#...#...",
			"...........",
			"...........",
		],
		note = "Three lanes, walled off from each other the whole way, meeting only behind each side's own lines. You are not fighting one battle here, you are funding three — unless you brought a Sapper. The middle of both dividing walls is breakable stone: knock a hole in it and the map stops being three fights and becomes one. The stone nearest each base is permanent, so nobody digs straight into your back line.",
	},
	{
		id = &"the_breach", name = "The Breach", w = 11, h = 13, neutral = true,
		rows = [
			"...........",
			"...........",
			"...........",
			".%%%#%#%%%.",
			".%%%%%%%%%.",
			".%%%#%#%%%.",
			".%%%%%%%%%.",
			".%%%#%#%%%.",
			".%%%%%%%%%.",
			".%%%#%#%%%.",
			"...........",
			"...........",
			"...........",
		],
		note = "A slab of breakable stone filling the whole middle of the board, with permanent pillars through it that nothing can shift. Without a Sapper there are two narrow lanes round the outside and a very long walk; with one you cut your own road through the middle and decide where the fight happens. The pillars mean the slab never fully disappears.",
	},
	{
		id = &"four_corners", name = "Four Corners", w = 11, h = 11, neutral = true,
		rows = [
			".....#.....",
			".....#.....",
			".....#.....",
			".....#.....",
			"##.#####.##",
			"...........",
			"##.#####.##",
			".....#.....",
			".....#.....",
			".....#.....",
			".....#.....",
		],
		note = "Two rooms each side, one gate each, and a single hallway across the middle. You commit to a left or a right before you know where they went.",
	},
	{
		id = &"the_gauntlet", name = "The Gauntlet", w = 7, h = 13, neutral = true,
		rows = [
			".......",
			".......",
			"#####..",
			".......",
			"..#####",
			".......",
			".......",
			".......",
			"..#####",
			".......",
			"#####..",
			".......",
			".......",
		],
		note = "Baffles alternating down a long board. Nothing sees down it, so every corner is an ambush, and crossing takes more than twice the steps it looks like.",
	},
	{
		id = &"the_highlands", name = "The Highlands", w = 6, h = 8, neutral = false,
		rows = [
			".^^^^.",
			"..//..",
			"..##..",
			"......",
			"......",
			"..##..",
			"..//..",
			".^^^^.",
		],
		note = "No divider, a boulder in each half, and a long ridge at the back of both. Short, high and mean.",
	},
	{
		id = &"the_keep", name = "The Keep", w = 9, h = 11, neutral = true,
		rows = [
			".........",
			".........",
			".........",
			"..#####..",
			"..#^^^#..",
			"../^^^/..",
			"..#^^^#..",
			"..#####..",
			".........",
			".........",
			".........",
		],
		note = "One fortress, dead centre, two doors on the neutral row, nine tiles of high ground inside and stone on every other side. Whoever gets in first owns the middle of the board.",
	},
	{
		id = &"the_redoubt", name = "The Redoubt", w = 9, h = 11, neutral = true,
		rows = [
			".........",
			".#######.",
			".#.....#.",
			".##.#.##.",
			".........",
			".........",
			".........",
			".##.#.##.",
			".#.....#.",
			".#######.",
			".........",
		],
		note = "A walled fort at each end with two gates and a road around the outside. Archers inside cannot be shot at until something comes through a gate at them.",
	},
	{
		id = &"the_anvil", name = "The Anvil", w = 9, h = 11, neutral = true,
		rows = [
			".........",
			".........",
			"..../....",
			"...X/X...",
			"..X^^^X..",
			"..X^^^X..",
			"..X^^^X..",
			"...X/X...",
			"..../....",
			".........",
			".........",
		],
		note = "A high plateau ringed by a dry moat, with one ramp on each side. Holding it means every archer you own gains a range band and shoots over the moat at everything below.",
	},
	{
		id = &"ramparts", name = "Ramparts", w = 7, h = 11, neutral = true,
		rows = [
			".^^^^^.",
			"..//...",
			".......",
			".......",
			".......",
			".......",
			".......",
			".......",
			".......",
			"..//...",
			".^^^^^.",
		],
		lines = [
			[0, 4, 0, 5], [1, 4, 1, 5], [5, 4, 5, 5], [6, 4, 6, 5],
			[0, 6, 0, 5], [1, 6, 1, 5], [5, 6, 5, 5], [6, 6, 6, 5],
		],
		note = "Barriers with no thickness pinch the middle to three columns. The back rank of each side is a firing step.",
	},
	{
		id = &"crossroads", name = "Crossroads", w = 11, h = 11, neutral = true,
		rows = [
			"XXX.....XXX",
			"XXX.....XXX",
			"XXX.....XXX",
			"...........",
			"...........",
			"...........",
			"...........",
			"...........",
			"XXX.....XXX",
			"XXX.....XXX",
			"XXX.....XXX",
		],
		note = "A plus. Both sides come down a narrow approach into a middle that is suddenly the full width of the board.",
	},
	{
		id = &"the_bridge", name = "The Bridge", w = 7, h = 11, neutral = true,
		rows = [
			".......",
			"./.../.",
			".^...^.",
			"XX...XX",
			"XX...XX",
			"XX...XX",
			"XX...XX",
			"XX...XX",
			".^...^.",
			"./.../.",
			".......",
		],
		note = "Two shores joined by a three-wide crossing. Everything has to funnel over it, and the high ground on each bank overlooks the whole span.",
	},
	{
		id = &"the_hourglass", name = "The Hourglass", w = 9, h = 11, neutral = true,
		rows = [
			".........",
			".........",
			"X.......X",
			"XX./^..XX",
			"XXX...XXX",
			"XXX...XXX",
			"XXX...XXX",
			"XX./^..XX",
			"X.......X",
			".........",
			".........",
		],
		note = "Wide at both ends and three tiles across in the middle, with the pinch overlooked from either side.",
	},
	{
		id = &"the_chasm", name = "The Chasm", w = 9, h = 11, neutral = true,
		rows = [
			".........",
			".........",
			".^^...^^.",
			"./...../.",
			".XXXXXXX.",
			".XXXXXXX.",
			".XXXXXXX.",
			"./...../.",
			".^^...^^.",
			".........",
			".........",
		],
		note = "A trench splits the field end to end, and the only ways over it are the two flanks. Archers duel across the gap from the first second; anything with a sword has a long walk to make.",
	},
	{
		id = &"the_shoals", name = "The Shoals", w = 11, h = 11, neutral = true,
		rows = [
			"...XX.XX...",
			"...XX.XX...",
			"...........",
			"XX.XXXXX.XX",
			"XX.XXXXX.XX",
			"...........",
			"XX.XXXXX.XX",
			"XX.XXXXX.XX",
			"...........",
			"...XX.XX...",
			"...XX.XX...",
		],
		note = "Islands joined by necks a single tile wide. Nothing here blocks a shot and almost everything blocks a step, so the necks are killing grounds long before anything reaches them.",
	},
	{
		id = &"the_causeway", name = "The Causeway", w = 7, h = 15, neutral = true,
		rows = [
			".......",
			".......",
			".......",
			"XX...XX",
			"XXX.XXX",
			"XXX.XXX",
			"XXX.XXX",
			"XXX.XXX",
			"XXX.XXX",
			"XXX.XXX",
			"XXX.XXX",
			"XX...XX",
			".......",
			".......",
			".......",
		],
		note = "One tile wide for eight rows, in full view of both shores the whole way. Holes do not stop an arrow, so crossing means walking single file through everything they have.",
	},
	{
		id = &"the_cage", name = "The Cage", w = 7, h = 11, neutral = true,
		lines = [
			[0, 1, 0, 2], [1, 1, 1, 2], [2, 1, 2, 2], [3, 1, 3, 2],
			[4, 1, 4, 2], [2, 3, 2, 4], [3, 3, 3, 4], [4, 3, 4, 4],
			[5, 3, 5, 4], [6, 3, 6, 4], [1, 4, 1, 5], [2, 4, 2, 5],
			[3, 4, 3, 5], [4, 4, 4, 5], [5, 4, 5, 5], [1, 5, 1, 6],
			[2, 5, 2, 6], [3, 5, 3, 6], [4, 5, 4, 6], [5, 5, 5, 6],
			[2, 6, 2, 7], [3, 6, 3, 7], [4, 6, 4, 7], [5, 6, 5, 7],
			[6, 6, 6, 7], [0, 8, 0, 9], [1, 8, 1, 9], [2, 8, 2, 9],
			[3, 8, 3, 9], [4, 8, 4, 9],
		],
		note = "Every barrier here is waist-high: you can see and shoot the whole board from anywhere on it, and walk almost nowhere directly. Ranged units read this as an open field. Melee reads it as a maze.",
	},
	{
		id = &"the_labyrinth", name = "The Labyrinth", w = 9, h = 25, neutral = true,
		rows = [
			".........",
			".........",
			".........",
			"#.###.###",
			"#.#.....#",
			"#.###.###",
			"#...#...#",
			"###.#.#.#",
			"#.#.#.#.#",
			"#.#.###.#",
			"#.......#",
			"#.###.###",
			"#.###.###",
			"#.###.###",
			"#.......#",
			"#.#.###.#",
			"#.#.#.#.#",
			"###.#.#.#",
			"#...#...#",
			"#.###.###",
			"#.#.....#",
			"#.###.###",
			".........",
			".........",
			".........",
		],
		note = "A real maze. Each side musters in the open ground at its own end, and everything between is one tile wide — dead ends, blind corners, and two ways through the middle. Nothing sees anything until it turns the corner into it.",
	},
	{
		id = &"the_compound", name = "The Compound", w = 12, h = 21, neutral = true,
		rows = [
			"..#..#...#..",
			"^/...#..../^",
			"..#..#...#..",
			".###.##.###.",
			"..#......#..",
			"..#..#/^.#..",
			".....#......",
			"#.#.####.#.#",
			"..#......#..",
			"#.##.##.##.#",
			"............",
			"#.##.##.##.#",
			"..#......#..",
			"#.#.####.#.#",
			".....#......",
			"..#..#/^.#..",
			"..#......#..",
			".###.##.###.",
			"..#..#...#..",
			"^/...#..../^",
			"..#..#...#..",
		],
		note = "The biggest board there is: 81 tiles a side, cut into a warren of two- and three-tile rooms. Four gates cross the middle, so a fight here is never one fight — it is six little ones in separate rooms that cannot see each other.",
	},
	{
		id = &"the_terrace", name = "The Terrace", w = 9, h = 15, neutral = true,
		rows = [
			".........",
			".^^^^^^^.",
			".^^^^^^^.",
			"..//.//..",
			".........",
			".........",
			".........",
			".........",
			".........",
			".........",
			".........",
			"..//.//..",
			".^^^^^^^.",
			".^^^^^^^.",
			".........",
		],
		note = "A second layer, and each side gets one. Put your shooters on the terrace and they cannot be touched by any melee unit standing on the ground — not at a penalty, at all — while anything shooting up at them loses a band of range, so a Long-ranged Archer has to walk to Medium to reach. The four staircases in front of each terrace are the only way up, and they are wide enough for two. Everything about this map is the question of whether the assault gets up the stairs before the shooters on top of them win.",
	},
	{
		id = &"the_defile", name = "The Defile", w = 9, h = 13, neutral = true,
		rows = [
			".........",
			".//...//.",
			".^^...^^.",
			".^^...^^.",
			".^^...^^.",
			".^^...^^.",
			".^^#.#^^.",
			".^^...^^.",
			".^^...^^.",
			".^^...^^.",
			".^^...^^.",
			".//...//.",
			".........",
		],
		note = "One tile wide in the middle, and two raised roads either side of it. Everything on the ground has to come through that single gap; everything on the causeways walks the length of the board untouched by any melee unit below. Taking the low road means a queue. Taking the high road means being seen the whole way and having only two staircases to get off at. There is no third option.",
	},
	{
		id = &"the_crown", name = "The Crown", w = 9, h = 13, neutral = true,
		rows = [
			".........",
			".........",
			".........",
			".........",
			"...///...",
			"..^^^^^..",
			"..^^^^^..",
			"..^^^^^..",
			"...///...",
			".........",
			".........",
			".........",
			".........",
		],
		note = "One hill, in the middle, and it is nobody's. You may deploy onto your own row of it and so may they, which leaves the crown of it — the middle row — empty and worth more than anything else on the board. Melee cannot reach anyone standing on it from the ground, so taking it means the stairs, and holding it means holding the stairs behind you.",
	},
]

const UNIT_TABLE := [


	{
		id = &"warden", name = "Warden", hp = 220.0, dmg = 34.0, spd = 0.30,
		move = 0.88, range = "MELEE", sight = 3, type = "MELEE",
		accent = Color(0.38, 0.47, 0.60),
		ability = &"bulwark_shield", mana = 16.0, opens = true,
		note = "Slow to swing and slower to walk, but hits like a truck behind a shield bigger than itself.",
	},
	{
		id = &"archer", name = "Archer", hp = 55.0, dmg = 19.0, spd = 1.05,
		move = 0.50, range = "LONG", sight = 5, type = "RANGED",
		accent = Color(0.55, 0.62, 0.32),
		ability = &"quickdraw", mana = 25.0,
		note = "Charges fastest of anyone and never stops speeding up. Fold if reached.",
	},
	{
		id = &"lancer", name = "Lancer", hp = 95.0, dmg = 16.0, spd = 1.1,
		move = 0.36, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.72, 0.35, 0.28),
		ability = &"impale", mana = 25.0, pierce = 2,
		note = "Every swing already cuts through two. The ability makes it three, harder.",
	},
	{
		id = &"reaver", name = "Reaver", hp = 95.0, dmg = 34.0, spd = 1.15,
		move = 0.34, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.74, 0.26, 0.30),
		ability = &"execute", mana = 20.0,
		note = "The hardest, fastest swing in the game, and the fastest legs, behind less health than a Lancer. Everything it does is on the front foot: it wins any exchange it starts and loses any exchange it is caught in.",
	},
	{
		id = &"vexer", name = "Vexer", hp = 85.0, dmg = 6.0, spd = 2.4,
		move = 0.45, range = "MEDIUM", sight = 4, type = "RANGED",
		accent = Color(0.45, 0.40, 0.66),
		ability = &"blight", mana = 12.0,
		note = "Weak hits, but the fastest attack rate means the bar fills constantly.",
	},
	{
		id = &"stasis", name = "Stasis", hp = 160.0, dmg = 8.0, spd = 1.8,
		move = 0.48, range = "MEDIUM", sight = 4, type = "SPELL",
		accent = Color(0.52, 0.72, 0.82),
		ability = &"arrest", mana = 14.0,
		note = "The Vexer's colder cousin, and the only unit whose ability is worth more to everyone else than to itself. It hits for very little and fills its bar quickly, and every bar it fills takes one enemy out of the fight for a few seconds and makes it softer for everything you own while it is out. Kill something while it is frozen and it leaves nothing behind: no revival, no corpse to raise, nothing for the other side's scavengers. Against an army built on dying well, that is the whole game.",
	},
	{
		id = &"pyre", name = "Pyre", hp = 90.0, dmg = 7.0, spd = 0.7,
		move = 0.55, range = "MEDIUM", sight = 4, type = "SPELL",
		accent = Color(0.78, 0.55, 0.22),
		ability = &"cinder_lance", mana = 34.0,
		note = "Ordinary attacks are feeble. Everything rides on landing the burst.",
	},
	{
		id = &"aegis", name = "Aegis", hp = 210.0, dmg = 20.0, spd = 0.45,
		move = 0.80, range = "MELEE", sight = 3, type = "MELEE",
		accent = Color(0.48, 0.52, 0.66),
		ability = &"retribution", mana = 22.0, resist = 0.15,
		note = "Shrugs off 15% of everything before anything else is counted, and answers whatever is standing next to it with twice what it was given. It does not out-damage anything; it makes hitting it a bad idea.",
	},
	{
		id = &"tyrant", name = "Tyrant", hp = 240.0, dmg = 40.0, spd = 0.9,
		move = 0.55, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.55, 0.16, 0.22),
		mana = 0.0, burden_radius = 2, burden = 0.30,
		note = "Plainly stronger than anything else you can field, and every one of your own units standing within two tiles of it takes 30% more damage. It wants to be alone, which is also where a single strong unit is easiest to surround.",
	},
	{
		id = &"seraph", name = "Seraph", hp = 95.0, dmg = 8.0, spd = 0.95,
		move = 0.48, range = "MEDIUM", sight = 4, type = "RANGED",
		accent = Color(0.55, 0.80, 0.75),
		ability = &"benediction", mana = 34.0,
		note = "Fills its bar fast and dumps it all into whoever is closest to dying, lifting whatever is on them first. The only cleanse in the game, which makes it the answer to a Vexer or a Stasis.",
	},
	{
		id = &"herald", name = "Herald", hp = 110.0, dmg = 7.0, spd = 0.8,
		move = 0.52, range = "MELEE", sight = 4, type = "RANGED",
		accent = Color(0.85, 0.78, 0.42),
		ability = &"war_horn", mana = 30.0, opens = true,
		note = "Weak alone. Its whole value is who you park it next to.",
	},
	{
		id = &"revenant", name = "Revenant", hp = 105.0, dmg = 13.0, spd = 0.85,
		move = 0.46, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.50, 0.55, 0.50),
		ability = &"second_wind", mana = 25.0,
		note = "A coin flip on every death, and it comes back whole. Kill it twice, or thrice.",
	},
	{
		id = &"assassin", name = "Assassin", hp = 60.0, dmg = 12.0, spd = 1.2,
		move = 0.34, range = "MELEE", sight = 6, type = "MELEE",
		accent = Color(0.42, 0.30, 0.48),
		ability = &"shadowstep", mana = 25.0, opens = true,
		note = "Opens behind someone, hits once for a fortune, then nobody can find it.",
	},
	{
		id = &"wellspring", name = "Wellspring", hp = 120.0, dmg = 9.0, spd = 0.75,
		move = 0.52, range = "MEDIUM", sight = 4, type = "SPELL",
		accent = Color(0.40, 0.68, 0.72),
		ability = &"overflow", mana = 0.0, regen = 6.0, opens = true,
		note = "Opens a pool of mana around itself on the first beat. Everyone standing in it casts sooner.",
	},
	{
		id = &"amalgam", name = "Amalgam", hp = 190.0, dmg = 15.0, spd = 0.8,
		move = 0.50, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.46, 0.52, 0.38),
		mana = 0.0, wild = true,
		note = "Merges with anything you own, whatever it is. Thick, steady, and never quite the same twice.",
	},
	{
		id = &"transcendence", name = "Transcendence", hp = 165.0, dmg = 22.0, spd = 0.45,
		move = 0.62, range = "UNLIMITED", sight = 6, type = "RANGED",
		accent = Color(0.58, 0.56, 0.44),
		mana = 0.0, magnet = true, beam = true,
		apex = {hp = 4.0, dmg = 4.0, range = "UNLIMITED", pierce = 100,
			endless = true, wash = 0.5, spd = 0.35},
		note = "No ability, no tricks, and slower to swing than anything else on the board — but its range has no limit at any tier, so it opens fire the instant the bell rings, from wherever you left it, over any wall in the way. Every merge it touches comes out Transcendence, and at tier 6 the shot becomes a beam that takes the rank behind the target with it — once every six seconds or so, which makes what it is aimed at matter far more than how often it fires.",
	},
	{
		id = &"conjurer", name = "Conjurer", hp = 190.0, dmg = 7.0, spd = 0.6,
		move = 0.50, range = "MEDIUM", sight = 4, type = "SPELL",
		accent = Color(0.62, 0.48, 0.78),
		ability = &"call_wisp", mana = 26.0, opens = true,
		note = "Tanky and feeble on its own. Its wisps match its tier and do the work.",
	},
	{
		id = &"culverin", name = "Culverin", hp = 105.0, dmg = 42.0, spd = 0.4,
		move = 0.58, range = "SNIPER", sight = 5, type = "RANGED",
		accent = Color(0.70, 0.58, 0.36),
		ability = &"bombardment", mana = 30.0,
		note = "The heaviest single shot on the board and the slowest hands holding it — four tiles of reach and one swing every two and a half seconds. Its shell is aimed at whichever enemy has the most company, lands a second and a half later on the tile rather than the unit, and leaves the ground burning behind it. It wants a target that cannot afford to move and hates one that can.",
	},
	{
		id = &"leech", name = "Leech", hp = 90.0, dmg = 17.0, spd = 1.4,
		move = 0.48, range = "LONG", sight = 5, type = "RANGED",
		accent = Color(0.48, 0.30, 0.44),
		ability = &"siphon", mana = 18.0, lifesteal = 0.25,
		note = "Drinks a quarter of everything it deals, from range, quickly. Its bar reaches across the whole board and fastens onto the single biggest thing the other side has — and then takes a fixed slice of that maximum every second whatever happens to it. It is the answer to a tier 6 Transcendence, and it is nearly useless against eight small ones.",
	},
	{
		id = &"breaker", name = "Breaker", hp = 150.0, dmg = 26.0, spd = 0.55,
		move = 0.60, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.82, 0.52, 0.24),
		ability = &"onslaught", mana = 0.0, opens = true,
		note = "Everything it is worth happens in the first second of the round. At the bell it runs straight down the column you left it in and slams into the first enemy in the lane, for a great deal of damage and a stun that scales with its tier. Nothing else about it is special: an ordinary melee body with a slow swing, standing wherever the charge left it. Where you PUT it is the whole unit — an empty lane is a wasted charge and a walk to the wrong end of the board.",
	},
	{
		id = &"colossus", name = "Colossus", hp = 250.0, dmg = 95.0, spd = 0.25,
		move = 0.90, range = "MELEE", sight = 3, type = "MELEE",
		accent = Color(0.54, 0.56, 0.62),
		mana = 0.0, plate = 0.03, plate_cap = 1.0,
		note = "The slowest thing on the board in both senses — one swing every four seconds, and the longest stride of anyone — for the heaviest ordinary attack in the game. Every single hit it takes adds 3% of its maximum health to its shield, and that is per HIT rather than per point of damage, so a dozen small attacks arm it faster than one enormous one. Feed it a Vexer and it will stand there all day. Hit it once with a Culverin and the shield is gone.",
	},
	{
		id = &"pariah", name = "Pariah", hp = 230.0, dmg = 5.0, spd = 0.85,
		move = 0.50, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.44, 0.42, 0.50),
		mana = 0.0, alone_hp = 0.07, alone_hp_step = 0.025,
		note = "Thick, and it hits like a wet rope — five damage a swing, less than a Wisp. No ability, no mana bar, nothing. What it has is this: give it room. If no ally of yours is in any of the eight tiles around it when the bell rings, every hit it lands also tears out 12% of whatever it is hitting, however enormous that thing is — and it stays switched on for the whole round whatever happens next. Crowd it and you have wasted a tile. It is the only unit in the game whose damage is decided before anyone has moved.",
	},
	{
		id = &"vigil", name = "Vigil", hp = 130.0, dmg = 10.0, spd = 0.7,
		move = 0.72, range = "MEDIUM", sight = 4, type = "SPELL",
		accent = Color(0.56, 0.60, 0.70),
		ability = &"lament", mana = 0.0, grief = 25.0,
		note = "Its bar does not move when it swings and does not move when it kills. It fills only when your own side loses someone, four deaths to a cast — so it is dead weight in a fight you are winning and the reason you win the one you are losing. Every tier is one more body it hands back.",
	},
	{
		id = &"paragon", name = "Paragon", hp = 150.0, dmg = 20.0, spd = 0.75,
		move = 0.52, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.86, 0.74, 0.36),
		ability = &"last_stand", mana = 30.0,
		solo = true, solo_hp = 2.5, solo_dmg = 4.0, solo_splash = 1, solo_spd = 0.35,
		note = "Field exactly one and it arrives empowered — and empowered it stops being a soldier and becomes a siege engine. Two and a half times the health, four times the damage, and every swing lands on the whole square around what it hit, but it winds up for nearly four seconds between blows. Almost anything out-trades it over ten seconds; almost nothing survives being in the wrong square when it lands. Field two and you get two ordinary Paragons, swinging at ordinary speed. Nothing summoned or merged into one after the bell is ever empowered.",
	},
	{
		id = &"sapper", name = "Sapper", hp = 150.0, dmg = 26.0, spd = 0.9,
		move = 0.46, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.66, 0.52, 0.34),
		ability = &"undermine", mana = 0.0, regen = 8.0, wall_mult = 6.0,
		note = "Goes at stone the way everything else goes at flesh: six times its own attack damage a swing, so a tier 6 Sapper puts a hole in a map wall almost as fast as it walks to it. It is the only unit that would rather dig than walk round. Once the walls are down that utility is spent, which is why its ordinary combat stats are genuinely good — it has to still be worth its tile in round six.",
	},
		{
		id = &"mason", name = "Mason", hp = 165.0, dmg = 20.0, spd = 0.7,
		move = 0.50, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.58, 0.62, 0.56),
		ability = &"bulwark_raise", mana = 0.0, regen = 7.0, opens = true,
		note = "Puts its first wall up on the opening bell, before anyone has moved, then another every time its bar fills. The wall blocks movement and sight for both armies — yours included — so where it goes matters far more than how often. Nothing is sealed in forever: anything can chew through stone given long enough, and a Sapper does it in a handful of swings.",
	},
		{
		id = &"devourer", name = "Devourer", hp = 120.0, dmg = 20.0, spd = 0.9,
		move = 0.44, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.52, 0.24, 0.34),
		ability = &"gorge", mana = 0.0, grief = 25.0,
		note = "Ordinary until your side starts dying. Five of your own buys the change, and after that it is a different unit: far more health, faster hands, faster legs, and every bar it fills from then on arms a swing that deletes whatever it touches, however much health that thing has. It cannot start this itself — something of yours has to fall first.",
	},
	{
		id = &"spire", name = "Spire", hp = 200.0, dmg = 0.0, spd = 0.5,
		move = 0.60, range = "MELEE", sight = 3, type = "MELEE",
		accent = Color(0.66, 0.60, 0.50),
		ability = &"raise_host", mana = 0.0, regen = 8.0, banks = true,
		rooted = true, harmless = true, mechanical = true,
		note = "Cannot move, cannot swing, and never loses the progress it made last round. When it finally raises its host, that is the end of it.",
	},
	{
		id = &"engineer", name = "Engineer", hp = 130.0, dmg = 8.0, spd = 0.7,
		move = 0.50, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.72, 0.62, 0.30),
		ability = &"assemble", mana = 0.0, regen = 4.0, opens = true,
		repair = 5.0,
		note = "Opens every round building a Sentry where it stands, exposed while it works, then steps off and leaves it standing there. Barely fights. It repairs an adjacent friendly Mechanical unit every second, and it will go to a damaged one rather than advance — so it tends its turret instead of dying on someone's spear.",
	},
	{
		id = &"wisp", name = "Wisp", hp = 38.0, dmg = 5.0, spd = 1.3,
		move = 0.40, range = "MELEE", sight = 3, type = "MELEE",
		accent = Color(0.70, 0.62, 0.86),
		mana = 0.0, hidden = true,
		note = "Summoned only. Never drawn, never merged, gone when the round ends.",
	},
	{
		id = &"sentry", name = "Sentry", hp = 110.0, dmg = 80.0, spd = 0.3,
		move = 0.60, range = "UNLIMITED", sight = 6, type = "RANGED",
		accent = Color(0.48, 0.55, 0.62),
		mana = 0.0, rooted = true, mechanical = true, hidden = true,
		note = "Built, not drawn, and the ten seconds it costs to raise are paid for here. It cannot move and it cannot be moved, it sees the whole board, and it fires rarely and enormously. Its range has no limit of any kind — it shoots over walls, over stone, over anything, from wherever it was bolted down.",
	},
]

const ABILITY_TABLE := [
	{
		id = &"bulwark_shield", name = "Bulwark", kind = "SHIELD", cast_time = 0.3,
		desc = "Raises a shield worth more than its own health. Soaks damage first, never healed.",
		shield_percent = 1.25, shield_cap_percent = 1.25,
	},
	{
		id = &"impale", name = "Impale", kind = "PIERCE", cast_time = 0.5,
		desc = "A driving thrust through up to three enemies.",
		pierce_targets = 3, pierce_damage_mult = 2.1,
	},
	{
		id = &"quickdraw", name = "Quickdraw", kind = "HASTE", cast_time = 0.35,
		desc = "Permanently quickens the draw. Stacks all battle.",
		haste_percent = 0.16, haste_max_stacks = 6,
	},
	{
		id = &"blight", name = "Blight", kind = "DOT", cast_time = 0.4,
		desc = "Poisons one enemy and takes a quarter of the health it has left, immediately. Every half second after that it takes half as much again — a quarter, an eighth, a sixteenth — so it cripples on landing and is spent by the sixth tick. Because it is always a share of what remains, it can never actually kill: the Vexer opens things up and somebody else closes them. While it is on, everything that hits the target lands 5% harder per tier of the Vexer, and the target gains nothing at all — no healing, no shields, no new haste, nothing from its own allies' auras. Keeps working while the Vexer shoots someone else.",
		dot_damage = 0.0, dot_ticks = 6, dot_interval = 0.5,
		dot_current_hp_percent = 0.25, dot_falloff = 0.5, dot_suppresses = true,
		dot_vulnerability_per_tier = 0.05,
	},
	{
		id = &"arrest", name = "Arrest", kind = "FREEZE", cast_time = 0.5,
		desc = "Stops one enemy dead. It cannot move, swing or cast for 0.9s per tier, it takes 15% more damage per tier from absolutely everything while it stands there, and if it dies frozen then nothing it would have done on death happens at all — no revival, no body to raise, no mana for whatever was waiting to feed on it. Whatever it was in the middle of is dropped, including a cast it had already paid for.",
		freeze_seconds_per_tier = 0.9, freeze_amp_per_tier = 0.15,
	},
	{
		id = &"cinder_lance", name = "Cinder Lance", kind = "FOCUS_BURST", cast_time = 0.7,
		desc = "A lance of fire: heavy on the target, scorching everything beside it.",
		burst_damage = 78.0, splash_damage = 16.0, splash_radius = 1,
	},
	{
		id = &"shadowstep", name = "Shadowstep", kind = "BLINK_STRIKE", cast_time = 0.35,
		desc = "Blinks behind a target, strikes for damage that doubles every tier, then cannot be found.",
		blink_base_damage = 46.0, stealth_time = 3.5,
	},
	{
		id = &"war_horn", name = "War Horn", kind = "SPEED_AURA", cast_time = 0.3,
		desc = "The four units directly beside the Herald swing faster for the whole battle.",
		aura_percent_per_tier = 0.12, aura_radius = 1,
	},
	{
		id = &"second_wind", name = "Second Wind", kind = "REVIVE", cast_time = 0.3,
		desc = "A coin flip on every death: back up a second later at full health, as good as new.",
		revive_chance = 0.5, revive_delay = 1.0, revive_hp_percent = 1.0,
	},
	{
		id = &"benediction", name = "Benediction", kind = "BURST_HEAL", cast_time = 0.28,
		desc = "A heavy burst of healing on whoever nearby is hurt worst, and every debuff on them is lifted first — poison, and the freeze that goes with it. Bigger every tier. Cleansing before healing is what makes it an answer to a Vexer: a poisoned unit cannot be healed at all until the poison is off it.",
		heal_percent = 0.45, heal_percent_per_tier = 0.20, heal_radius = 3,
		cleanses = true,
	},
	{
		id = &"call_wisp", name = "Call Wisp", kind = "SUMMON", cast_time = 0.5,
		desc = "Fills its retinue back up to strength with wisps on the tiles beside it — one more for every tier it has, up to six. Every cast tops it back up, so a wisp that dies is replaced the next time the bar is full.",
		summon = &"wisp", summon_max = 6, summon_retinue = true,
		summon_per_tier = 1.0,
	},
	{
		id = &"raise_host", name = "Raise Host", kind = "SUMMON", cast_time = 1.4,
		desc = "Pours everything it has gathered into two new units, drawn at random from your own roster at its own tier and placed as close to it as the board allows. Never another Spire. Each arrives already casting its own ability. They are yours for the rest of the match, and raising them uses the Spire up. If your half has no room for both, nothing is raised at all.",
		summon_count = 2, summon_random = true, summon_cap_by_tier = false,
		summon_max = 100, summon_persists = true, consumes_caster = true,
		guards_caster = true, summon_instacasts = true,
	},
	{
		id = &"execute", name = "Execute", kind = "FOCUS_BURST", cast_time = 0.35,
		desc = "A single committed swing at whatever it is already fighting, for four times its own attack damage. Because it is a multiple of its attack rather than a fixed number, it grows with every tier and with everything that sharpens the blade.",
		burst_attack_multiple = 4.0, splash_damage = 0.0, splash_radius = 0,
	},
	{
		id = &"onslaught", name = "Onslaught", kind = "CHARGE", cast_time = 0.2,
		desc = "At the opening bell it runs straight forward down its own column until something stops it. The first ENEMY in the lane takes 1.2 times its attack damage per tier and is stunned for 0.45 seconds per tier — no moving, no swinging, no casting. An ally in the way blocks the charge and takes nothing; so does a wall. It moves whether or not it connects, so a charge into an empty lane leaves it standing at the far end having done nothing at all.",
		charge_damage_per_tier = 1.2, stun_seconds_per_tier = 0.45,
		charge_distance = 11,
	},
	{
		id = &"retribution", name = "Retribution", kind = "REFLECT", cast_time = 0.5,
		desc = "Sets itself and waits. For five seconds it shrugs off half again of everything that lands, and anything striking it from an adjacent tile — a swing or an ability — takes 200% of that damage straight back. A bow across the board is untouched by it.",
		reflect_resist = 0.50, reflect_percent = 2.0, reflect_duration = 5.0,
	},
	{
		id = &"last_stand", name = "Last Stand", kind = "TAUNT", cast_time = 0.6,
		desc = "Plants itself and roars. Every enemy within three tiles drops whatever it was doing and comes for it, and for four seconds it takes 90% less damage — but it cannot move and cannot swing while it holds. Only an empowered Paragon can do it.",
		taunt_radius = 3, taunt_duration = 4.0, taunt_damage_taken = 0.10,
		requires_empowered = true,
	},
	{
		id = &"assemble", name = "Assemble", kind = "SUMMON", cast_time = 10.0,
		desc = "Spends the opening of the round bolting a Sentry together on the tile it is standing on, then steps aside and leaves it there. It keeps one at tiers 1-2, two at 3-4 and three at 5-6, and builds them one at a time. It is head-down while it works and takes double damage the whole time. If a Sentry is destroyed it will build another once its bar is full, and it will not start a build it has no room to finish.",
		summon = &"sentry", summon_max = 3, summon_retinue = true,
		summon_at_caster = true,
		opener_takes_time = true, exposes_caster = 1.0, holds_when_capped = true,
	},
	{
		id = &"lament", name = "Lament", kind = "RAISE", cast_time = 0.8,
		desc = "Calls your dead back onto the field — one for every tier it has, chosen at random from everyone who has fallen, each standing up on its own grave at 85% health. It gathers the charge for this from those deaths themselves, so it can only give an army back after it has watched one die.",
		raise_per_tier = 1, raise_hp_percent = 0.85,
	},
	{
		id = &"gorge", name = "Gorge", kind = "ASCEND", cast_time = 0.4,
		desc = "The first full bar splits it open: two and a half times the health, half again the attack speed, and a third quicker on its feet. Every bar it fills after that arms the next swing to kill outright, whatever it hits and however much health that thing has left.",
		ascend_hp_mult = 2.5, ascend_attack_speed_mult = 1.5,
		ascend_move_mult = 0.66, ascend_mana_per_attack = 20.0,
	},
	{
		id = &"undermine", name = "Undermine", kind = "SAP", cast_time = 1.2,
		desc = "A shaped charge against the wall beside it, favouring the stone between its army and the enemy — worth four of its own swings, and its swings are already six times what anyone else does to stone. Every unit on the board re-paths the moment a hole appears. Permanent stone is beyond it.",
		terrain_reach = 1, terrain_tiles = 1, sap_burst_multiple = 4.0,
	},
	{
		id = &"bulwark_raise", name = "Emplace", kind = "BUILD", cast_time = 1.0,
		desc = "Raises a wall on the tile it is standing on and steps off it, up at the opening bell and again on every full bar — so where you place the Mason is where the wall goes. It blocks movement and sight for both sides equally — including yours — so where it goes matters more than how often. It is stone like any other: a Sapper goes through it quickly, anything else slowly.",
		terrain_reach = 1, terrain_tiles = 1, wall_hp = 240.0,
		terrain_at_caster = true,
	},
	{
		id = &"bombardment", name = "Bombardment", kind = "SHELL", cast_time = 0.8,
		desc = "Picks whichever enemy has the most company and lobs a shell at the ground it is standing on. Three times its own attack, 150% to the tile itself and 100% down each arm of the cross, and the ground burns for six seconds afterwards. It takes a second and a half to come down, and it is aimed at the tile rather than the unit — anything that walks off in the meantime is simply not there when it lands.",
		shell_attack_multiple = 3.0, shell_direct = 1.5, shell_splash = 1.0,
		shell_flight = 1.5, shell_arm = 1,
		field_damage = 0.35, field_seconds = 6.0,
	},
	{
		id = &"siphon", name = "Siphon", kind = "DRAIN", cast_time = 0.5,
		desc = "Reaches across the whole board — no range limit at all — and fastens onto whichever enemy has the largest maximum health. From then until that unit dies it loses 2.5% of that maximum every second. Shields are not counted, so nothing hides behind one, and the bite does not shrink as the victim wears down. Several Siphons stack on the same victim, and the Leech heals off every tick of it.",
		drain_percent = 0.025, drain_interval = 1.0,
	},
	{
		id = &"overflow", name = "Overflow", kind = "MANA_AURA", cast_time = 0.4,
		desc = "Floods the three-by-three around it. Allies standing inside gain extra mana every second, for the rest of the battle.",
		mana_aura_radius = 1,
	},
]

const BUFF_TABLE = [
	{id = &"mending_wind", name = "Mending Wind", kind = "REGEN", weight = 1.0,
		b = Vector2(0.01, 0.0), s = Vector2(0.02, 0.0), g = Vector2(0.04, 0.0)},
	{id = &"aegis_wall", name = "Aegis Wall", kind = "ROUND_SHIELD", weight = 1.0,
		b = Vector2(1000.0, 0.0), s = Vector2(2000.0, 0.0), g = Vector2(3000.0, 0.0)},
	{id = &"forced_march", name = "Forced March", kind = "STAT", weight = 1.0,
		stat_a = "MOVE_TIME",
		b = Vector2(0.50, 0.0), s = Vector2(0.75, 0.0), g = Vector2(1.00, 0.0)},
	{id = &"militia", name = "Militia", kind = "STAT", weight = 1.0,
		stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true, max_tier = 3,
		b = Vector2(0.50, 0.50), s = Vector2(0.75, 0.75), g = Vector2(1.00, 1.00)},
	{id = &"avalanche", name = "Avalanche", kind = "STAT", weight = 1.0,
		unit = &"breaker", stat_a = "MAX_HP",
		stun_bonus = Vector3(1.0, 2.0, 3.0),
		charge_bonus = Vector3(0.50, 0.75, 1.00),
		b = Vector2(0.0, 0.0), s = Vector2(0.0, 0.0), g = Vector2(0.0, 0.0)},
	{id = &"rupture", name = "Rupture", kind = "PERCENT_HP_DAMAGE", weight = 1.0,
		b = Vector2(0.01, 0.0), s = Vector2(0.02, 0.0), g = Vector2(0.03, 0.0)},
	{id = &"windfall", name = "Windfall", kind = "MERGE_EXTRA_UNIT", weight = 1.0,
		b = Vector2(0.10, 0.0), s = Vector2(0.20, 0.0), g = Vector2(0.3, 0.0)},
	{id = &"promotion", name = "Promotion", kind = "MERGE_EXTRA_TIER", weight = 1.0,
		b = Vector2(0.04, 0.0), s = Vector2(0.08, 0.0), g = Vector2(0.12, 0.0)},
	{id = &"full_muster", name = "Full Muster", kind = "FULL_ROSTER", weight = 1.0,
		stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.30, 0.30), s = Vector2(0.60, 0.60), g = Vector2(0.9, 0.9)},
	{id = &"war_drums", name = "War Drums", kind = "STAT", weight = 1.0,
		stat_a = "ATTACK_SPEED",
		b = Vector2(0.20, 0.0), s = Vector2(0.40, 0.0), g = Vector2(0.60, 0.0)},

	{id = &"ironwall", name = "Ironwall", kind = "STAT", weight = 1.0,
		unit = &"warden", stat_a = "MAX_HP",
		b = Vector2(1.00, 0.0), s = Vector2(1.50, 0.0), g = Vector2(2.0, 0.0)},
	{id = &"marksmanship", name = "Marksmanship", kind = "STAT", weight = 1.0,
		unit = &"archer", stat_a = "ATTACK_DAMAGE", stat_b = "ATTACK_SPEED", two = true,
		b = Vector2(0.25, 0.15), s = Vector2(0.50, 0.30), g = Vector2(0.75, 0.45)},
	{id = &"vigor", name = "Vigor", kind = "STAT", weight = 1.0,
		unit = &"lancer", stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.30, 0.20), s = Vector2(0.60, 0.40), g = Vector2(0.9, 0.6)},
	{id = &"conflagration", name = "Conflagration", kind = "STAT", weight = 1.0,
		unit = &"pyre", stat_a = "ATTACK_DAMAGE", stat_b = "ATTACK_SPEED", two = true,
		b = Vector2(0.40, 0.10), s = Vector2(0.80, 0.20), g = Vector2(1.2, 0.3)},
	{id = &"swarm", name = "Swarm", kind = "STAT", weight = 1.0,
		unit = &"vexer", stat_a = "ATTACK_SPEED",
		b = Vector2(0.50, 0.0), s = Vector2(1.00, 0.0), g = Vector2(1.5, 0.0)},

	{id = &"shadowcraft", name = "Shadowcraft", kind = "STAT", weight = 1.0,
		unit = &"assassin", stat_a = "ATTACK_SPEED", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.10, 0.15), s = Vector2(0.20, 0.30), g = Vector2(0.3, 0.45)},
	{id = &"fanfare", name = "Fanfare", kind = "STAT", weight = 1.0,
		unit = &"herald", stat_a = "ATTACK_DAMAGE", stat_b = "MAX_HP", two = true,
		stat_c = "AURA_POWER", three = Vector3(0.25, 0.50, 1.00),
		b = Vector2(0.20, 0.25), s = Vector2(0.40, 0.50), g = Vector2(0.6, 0.75)},
	{id = &"undying", name = "Undying", kind = "STAT", weight = 1.0,
		unit = &"revenant", stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.50, 0.50), s = Vector2(1.00, 1.00), g = Vector2(1.5, 1.5)},
	{id = &"grace", name = "Grace", kind = "STAT", weight = 1.0,
		unit = &"seraph", stat_a = "MAX_HP", stat_b = "HEAL_POWER", two = true,
		b = Vector2(0.35, 0.10), s = Vector2(0.70, 0.20), g = Vector2(1.05, 0.3)},
	{id = &"covenant", name = "Covenant", kind = "STAT", weight = 1.0,
		unit = &"conjurer", also = [&"wisp"],
		stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.50, 0.30), s = Vector2(1.00, 0.60), g = Vector2(1.5, 0.9)},
	{id = &"cohesion", name = "Cohesion", kind = "STAT", weight = 1.0,
		unit = &"amalgam", stat_a = "MAX_HP",
		b = Vector2(1.00, 0.0), s = Vector2(2.00, 0.0), g = Vector2(3.00, 0.0)},
	{id = &"incubation", name = "Incubation", kind = "STAT", weight = 1.0,
		unit = &"spire", stat_a = "MANA_REGEN", flat = true,
		extra_summons = Vector3(1, 2, 3),
		b = Vector2(3.0, 0.0), s = Vector2(6.0, 0.0), g = Vector2(9.0, 0.0)},
	{id = &"confluence", name = "Confluence", kind = "STAT", weight = 1.0,
		unit = &"wellspring", stat_a = "MANA_REGEN", stat_b = "MAX_HP", two = true,
		flat = true,
		b = Vector2(3.0, 0.30), s = Vector2(6.0, 0.60), g = Vector2(9.0, 0.90)},
	{id = &"dominion", name = "Dominion", kind = "STAT", weight = 1.0,
		unit = &"tyrant", stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.40, 0.40), s = Vector2(0.80, 0.80), g = Vector2(1.2, 1.2)},
	{id = &"fabrication", name = "Fabrication", kind = "STAT", weight = 1.0,
		unit = &"engineer", also = [&"sentry"],
		stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.50, 0.40), s = Vector2(1.00, 0.80), g = Vector2(1.5, 1.2)},
	{id = &"retaliation", name = "Retaliation", kind = "STAT", weight = 1.0,
		unit = &"aegis", stat_a = "MAX_HP", stat_b = "RESIST", two = true,
		flat_b = true,
		b = Vector2(0.25, 0.15), s = Vector2(0.50, 0.30), g = Vector2(0.75, 0.45)},
	{id = &"whetstone", name = "Whetstone", kind = "STAT", weight = 1.0,
		unit = &"reaver", stat_a = "ATTACK_DAMAGE", stat_b = "ATTACK_SPEED",
		two = true,
		b = Vector2(0.50, 0.25), s = Vector2(1.00, 0.50), g = Vector2(1.5, 0.75)},
	{id = &"solitude", name = "Solitude", kind = "STAT", weight = 1.0,
		unit = &"paragon", stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		empowered_cap_at_gold = 2,
		b = Vector2(0.50, 0.50), s = Vector2(1.00, 1.00), g = Vector2(1.50, 1.50)},
	{id = &"remembrance", name = "Remembrance", kind = "STAT", weight = 1.0,
		unit = &"vigil", stat_a = "MAX_HP",
		extra_raises = Vector3(1, 2, 3),
		b = Vector2(0.50, 0.0), s = Vector2(1.00, 0.0), g = Vector2(1.50, 0.0)},
	{id = &"gluttony", name = "Gluttony", kind = "STAT", weight = 1.0,
		unit = &"devourer", stat_a = "MAX_HP", stat_b = "ATTACK_SPEED", two = true,
		b = Vector2(0.50, 0.20), s = Vector2(1.00, 0.40), g = Vector2(1.50, 0.60)},
	{id = &"demolition", name = "Demolition", kind = "STAT", weight = 1.0,
		unit = &"sapper", stat_a = "ATTACK_SPEED", stat_b = "ATTACK_DAMAGE",
		two = true,
		b = Vector2(0.15, 0.75), s = Vector2(0.30, 1.50), g = Vector2(0.45, 2.25)},
	{id = &"bastion", name = "Bastion", kind = "STAT", weight = 1.0,
		unit = &"mason", stat_a = "MAX_HP",
		wall_toughness = Vector3(1.0, 2.0, 3.0),
		b = Vector2(0.50, 0.0), s = Vector2(1.00, 0.0), g = Vector2(1.50, 0.0)},
	{id = &"enfilade", name = "Enfilade", kind = "STAT", weight = 1.0,
		unit = &"culverin", stat_a = "ATTACK_SPEED", stat_b = "ATTACK_DAMAGE",
		two = true,
		b = Vector2(0.20, 0.75), s = Vector2(0.40, 1.50), g = Vector2(0.60, 2.25)},
	{id = &"hunger", name = "Hunger", kind = "STAT", weight = 1.0,
		unit = &"leech", stat_a = "ATTACK_SPEED", stat_b = "ATTACK_RANGE",
		two = true, flat_b = true,
		b = Vector2(0.25, 1.0), s = Vector2(0.50, 2.0), g = Vector2(0.75, 3.0)},
	{id = &"tempering", name = "Tempering", kind = "STAT", weight = 1.0,
		unit = &"colossus", stat_a = "MAX_HP",
		shield_on_hit = Vector3(0.025, 0.05, 0.075),
		b = Vector2(0.75, 0.0), s = Vector2(1.50, 0.0), g = Vector2(2.25, 0.0)},
	{id = &"permafrost", name = "Permafrost", kind = "STAT", weight = 1.0,
		unit = &"stasis", stat_a = "FREEZE_POWER", stat_b = "FREEZE_AMP", two = true,
		b = Vector2(0.50, 0.25), s = Vector2(0.75, 0.50), g = Vector2(1.00, 1.00)},
	{id = &"spite", name = "Spite", kind = "STAT", weight = 1.0,
		unit = &"pariah", stat_a = "ATTACK_SPEED", stat_b = "MAX_HP", two = true,
		b = Vector2(0.25, 0.50), s = Vector2(0.50, 1.00), g = Vector2(0.75, 1.50)},
	{id = &"ascension", name = "Ascension", kind = "STAT", weight = 1.0,
		unit = &"transcendence", stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.50, 0.50), s = Vector2(1.00, 1.00), g = Vector2(1.50, 1.50)},

	{id = &"far_sight", name = "Far Sight", kind = "STAT", weight = 1.0,
		only = "GOLD", stat_a = "ATTACK_RANGE", flat = true,
		b = Vector2(1.0, 0.0), s = Vector2(1.0, 0.0), g = Vector2(1.0, 0.0)},
	{id = &"levy", name = "Levy", kind = "BOARD_FILL", weight = 0.8,
		only = "GOLD",
		b = Vector2(30.0, 0.0), s = Vector2(30.0, 0.0), g = Vector2(30.0, 0.0)},
	{id = &"alchemy", name = "Alchemy", kind = "WILD_MERGE", weight = 0.9,
		only = "GOLD",
		b = Vector2(1.0, 0.0), s = Vector2(1.0, 0.0), g = Vector2(1.0, 0.0)},
	{id = &"conscription", name = "Conscription", kind = "EXTRA_DRAW", weight = 1.0,
		b = Vector2(1.0, 0.0), s = Vector2(2.0, 0.0), g = Vector2(3.0, 0.0)},
	{id = &"reckless", name = "Reckless", kind = "STAT", weight = 1.0,
		stat_a = "ATTACK_DAMAGE", stat_b = "DAMAGE_TAKEN", two = true,
		b = Vector2(0.60, 0.20), s = Vector2(0.90, 0.15), g = Vector2(1.20, 0.10)},
	{id = &"bloodletting", name = "Bloodletting", kind = "STAT", weight = 1.0,
		stat_a = "LIFESTEAL", flat = true,
		b = Vector2(0.20, 0.0), s = Vector2(0.40, 0.0), g = Vector2(0.60, 0.0)},
	{id = &"conclave", name = "Conclave", kind = "TIER_GIFT", weight = 0.9,
		only = "SILVER",
		b = Vector2(3.0, 3.0), s = Vector2(3.0, 3.0), g = Vector2(3.0, 3.0)},
	{id = &"oblation", name = "Oblation", kind = "SACRIFICE", weight = 0.9,
		only = "SILVER",
		b = Vector2(1.0, 0.0), s = Vector2(1.0, 0.0), g = Vector2(1.0, 0.0)},
	{id = &"mimic", name = "Mimic", kind = "MIMIC", weight = 0.9,
		only = "GOLD",
		b = Vector2(2.0, 0.0), s = Vector2(2.0, 0.0), g = Vector2(2.0, 0.0)},
]


func build() -> String:
	print("Generating data for Six by Eleven...")
	var clash := _duplicate_ids()
	if clash != "":
		push_error(clash)
		return "FAILED — " + clash
	var stranded := _unreachable_high()
	if stranded != "":
		push_error(stranded)
		return "FAILED — " + stranded
	_prune_stale()
	_make_maps()
	var abilities := _make_abilities()
	var loadout := _make_units(abilities)
	_link_summons(abilities)
	_make_buffs()
	if not loadout.is_valid():
		push_error("Generated loadout is invalid.")
		return "FAILED — the generated loadout is invalid."
	return "Done. %d units (%d types x %d tiers), %d abilities, %d buffs, %d maps." % [
		UNIT_TABLE.size() * TIERS, UNIT_TABLE.size(), TIERS,
		ABILITY_TABLE.size(), BUFF_TABLE.size(), MAP_TABLE.size()]


func _duplicate_ids() -> String:
	# Every id is a FILE NAME, so two rows sharing one means the second silently
	# overwrites the first and the count printed at the end is a lie: the build
	# says "36 maps" and writes 35. It has happened once, and it cost an
	# afternoon of wondering why a new map never turned up. Cheap to check.
	for pair in [["unit", UNIT_TABLE], ["ability", ABILITY_TABLE],
			["buff", BUFF_TABLE], ["map", MAP_TABLE]]:
		var seen := {}
		for row in pair[1]:
			var id := String(row.id)
			if seen.has(id):
				return "two %s rows share the id '%s' — one would overwrite the other" % [
					pair[0], id]
			seen[id] = true
	return ""


func _unreachable_high() -> String:
	# High ground is a second layer, and the only way onto one is a staircase. So
	# every connected patch of "^" needs at least one "/" touching it, or it is a
	# plateau nothing can ever stand on: melee cannot attack into it, nothing can
	# walk up to it, and it is scenery that looks like terrain.
	#
	# Checked here rather than trusted, because it is invisible in the map source
	# — you have to trace the patch by eye to notice — and because a map is edited
	# by hand as ASCII, which is exactly the sort of thing that loses a stair to a
	# stray keystroke.
	for row in MAP_TABLE:
		if not row.has("rows"):
			continue
		var rows: Array = row.rows
		var seen := {}
		for y in rows.size():
			var line: String = rows[y]
			for x in line.length():
				if line[x] != "^" or seen.has(Vector2i(x, y)):
					continue
				# Flood the patch, and look for a staircase beside any of it.
				var patch: Array[Vector2i] = [Vector2i(x, y)]
				var open_list: Array[Vector2i] = [Vector2i(x, y)]
				seen[Vector2i(x, y)] = true
				var reachable := false
				while not open_list.is_empty():
					var c: Vector2i = open_list.pop_back()
					for dy in [-1, 0, 1]:
						for dx in [-1, 0, 1]:
							var n := c + Vector2i(dx, dy)
							if n.y < 0 or n.y >= rows.size():
								continue
							var nline: String = rows[n.y]
							if n.x < 0 or n.x >= nline.length():
								continue
							if nline[n.x] == "/":
								reachable = true
							elif nline[n.x] == "^" and not seen.has(n):
								seen[n] = true
								patch.append(n)
								open_list.append(n)
				if not reachable:
					return "map '%s' has %d high tiles around %s with no stairs touching them" % [
						row.id, patch.size(), Vector2i(x, y)]
	return ""


func _prune_stale() -> void:
	_prune_tiers()
	_prune_retired_units()
	_prune_by_id(ABILITY_DIR, ABILITY_TABLE)
	_prune_by_id(BUFF_DIR, BUFF_TABLE)
	_prune_by_id(MAP_DIR, MAP_TABLE)


func _prune_retired_units() -> void:
	var live := {}
	for row in UNIT_TABLE:
		live[String(row.id)] = true
	var dir := DirAccess.open(UNITS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var marker := file_name.rfind("_t")
		if marker < 0:
			continue
		if not live.has(file_name.substr(0, marker)):
			dir.remove(file_name)
			print("  pruned retired unit: ", file_name)


func _prune_tiers() -> void:
	var dir := DirAccess.open(UNITS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var marker := file_name.rfind("_t")
		if marker < 0:
			continue
		var tier := file_name.substr(marker + 2).trim_suffix(".tres").to_int()
		if tier > TIERS:
			dir.remove(file_name)
			print("  pruned stale tier: ", file_name)


func _prune_by_id(folder: String, table: Array) -> void:
	var keep := {}
	for row in table:
		keep[String(row.id)] = true
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		if not keep.has(file_name.trim_suffix(".tres")):
			dir.remove(file_name)
			print("  pruned orphan: %s/%s" % [folder, file_name])


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	res.take_over_path(path)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [path, err])
	else:
		print("  ", path)


func _make_maps() -> void:
	for i in MAP_TABLE.size():
		var row: Dictionary = MAP_TABLE[i]
		var m := MapData.new()
		m.id = row.id
		m.rank = i
		m.display_name = row.name
		m.width = row.w
		m.height = row.h
		m.has_neutral = row.neutral
		m.note = row.get("note", "")
		var shape: PackedStringArray = []
		for line in row.get("rows", []):
			shape.append(line)
		m.rows = shape
		var barriers: Array[Vector4i] = []
		for e in row.get("lines", []):
			barriers.append(Vector4i(e[0], e[1], e[2], e[3]))
		m.lines = barriers
		var why := m.invalid_reason()
		if not why.is_empty():
			push_error("Map '%s' is unusable: %s" % [row.id, why])
		_save(m, "%s/%s.tres" % [MAP_DIR, row.id])


func _make_abilities() -> Dictionary:
	var out := {}
	for row in ABILITY_TABLE:
		var a := AbilityData.new()
		a.id = row.id
		a.display_name = row.name
		a.description = row.desc
		a.kind = AbilityData.Kind[row.kind]
		a.cast_time = row.cast_time
		for key in ["haste_percent", "haste_max_stacks",
			"shield_percent", "shield_cap_percent",
			"blink_base_damage", "stealth_time", "aura_percent_per_tier",
			"aura_radius", "revive_chance", "revive_delay", "revive_hp_percent",
			"heal_percent", "heal_percent_per_tier", "heal_radius", "cleanses",
				"charge_damage_per_tier", "stun_seconds_per_tier", "charge_distance",
				"summon_max",
				"summon_count", "summon_random", "summon_cap_by_tier", "summon_per_tier", "mana_aura_radius",
				"summon_persists", "consumes_caster", "summon_adjacent",
				"guards_caster", "summon_instacasts", "summon_retinue",
				"opener_takes_time", "exposes_caster", "summon_at_caster",
				"terrain_reach", "terrain_tiles", "sap_burst_multiple", "wall_hp",
				"terrain_at_caster",
				"shell_attack_multiple", "shell_direct", "shell_splash",
				"shell_flight", "shell_arm", "field_damage", "field_seconds",
				"drain_percent", "drain_interval",
				"freeze_seconds_per_tier", "freeze_amp_per_tier",
				"raise_per_tier", "raise_hp_percent",
				"ascend_hp_mult", "ascend_attack_speed_mult", "ascend_move_mult",
				"ascend_mana_per_attack",
				"holds_when_capped", "taunt_radius", "taunt_duration",
				"taunt_damage_taken", "requires_empowered",
				"reflect_resist", "reflect_percent", "reflect_duration",
				"dot_damage", "dot_ticks", "dot_interval", "dot_vulnerability_per_tier",
				"dot_current_hp_percent", "dot_falloff", "dot_suppresses",
				"burst_damage",
				"burst_attack_multiple",
				"splash_damage", "splash_radius", "pierce_targets", "pierce_damage_mult"]:
			if row.has(key):
				a.set(key, row[key])
		_save(a, "%s/%s.tres" % [ABILITY_DIR, row.id])
		out[row.id] = a
	return out


var _tier_ones: Dictionary = {}


func _link_summons(abilities: Dictionary) -> void:
	for row in ABILITY_TABLE:
		if not row.has("summon"):
			continue
		var a: AbilityData = abilities[row.id]
		a.summon_unit = _tier_ones.get(row.summon, null)
		if a.summon_unit == null:
			push_error("Ability %s wants to summon '%s', which no unit row builds." % [
				row.id, row.summon])
		var path := "%s/%s.tres" % [ABILITY_DIR, row.id]
		_save(a, path)
		# Read it straight back. This is the one field in the whole build that is
		# a reference to another generated file rather than a plain value, so it
		# is the one that can be written as nothing at all without any error
		# being raised — and a summoner whose summon quietly went null is a unit
		# that simply stops working, several tests deep, for no visible reason.
		# It has happened once. Cheap to check, expensive to debug.
		var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if back != null and (back as AbilityData).summon_unit == null:
			push_error("%s saved without its summon link. Run the generator again." % path)


func _make_units(abilities: Dictionary) -> LoadoutData:
	var loadout := LoadoutData.new()
	loadout.id = &"starter"
	loadout.display_name = "Starter Five"
	var roster := LoadoutData.new()
	roster.id = &"roster"
	roster.display_name = "Full Roster"
	var tier_ones: Array[UnitData] = []
	var all_playable: Array[UnitData] = []
	_tier_ones.clear()

	for row in UNIT_TABLE:
		var built: Array[UnitData] = []
		for t in range(TIERS, 0, -1):
			var u := UnitData.new()
			var mult_hp: float = pow(HP_SCALE, t - 1)
			var mult_dmg: float = pow(DMG_SCALE, t - 1)
			u.id = row.id
			u.display_name = row.name if t == 1 else "%s %s" % [row.name, _numeral(t)]
			u.tier = t
			u.max_hp = snappedf(row.hp * mult_hp, 1.0)
			u.attack_damage = snappedf(row.dmg * mult_dmg, 0.5)
			u.attack_speed = row.spd
			u.move_time = row.move
			u.attack_range = UnitData.RangeBand[row.range]
			u.sight_range = row.sight
			u.attack_type = UnitData.AttackType[row.type]
			u.accent = row.accent
			u.note = row.get("note", "")
			u.mana_per_attack = row.get("mana", 25.0)
			u.mana_per_ally_death = row.get("grief", 0.0)
			u.wall_damage_mult = row.get("wall_mult", 0.15)
			# Written per tier rather than scaled at runtime, because the whole
			# point of the tier ladder is that the .tres files say what a unit
			# actually does. A flat step, not the doubling every other stat gets:
			# this is already a fraction of the VICTIM's maximum health, so the
			# damage it deals doubles per tier on its own, and doubling the
			# fraction on top of that would compound into four swings again.
			u.alone_hp_damage = snappedf(row.get("alone_hp", 0.0) + row.get(
				"alone_hp_step", 0.0) * float(t - 1), 0.001)
			u.shield_on_hit = row.get("plate", 0.0)
			u.shield_cap = row.get("plate_cap", 1.0)
			u.lifesteal = row.get("lifesteal", 0.0)
			u.mana_per_charge = row.get("regen", 0.0)
			u.mana_charge_time = row.get("charge", 1.0)
			u.keeps_mana = row.get("banks", false)
			u.casts_at_battle_start = row.get("opens", false)
			u.pierce_targets = row.get("pierce", 1)
			u.merge_magnet = row.get("magnet", false)
			u.beam_attack = row.get("beam", false)
			u.wild_merge = row.get("wild", false)
			# Two separate facts. The Spire is both; the Sentry is rooted but very
			# much able to shoot, which is the whole of what it is for.
			u.can_move = not row.get("rooted", false)
			u.can_attack = not row.get("harmless", false)
			u.chassis = (UnitData.Chassis.MECHANICAL
				if row.get("mechanical", false) else UnitData.Chassis.BIOLOGICAL)
			u.repair_per_second = snappedf(
				float(row.get("repair", 0.0)) * mult_hp, 0.5)
			u.burden_radius = row.get("burden_radius", 0)
			u.burden_percent = row.get("burden", 0.0)
			u.damage_resist = row.get("resist", 0.0)
			u.solo_empower = row.get("solo", false)
			u.empower_hp_mult = row.get("solo_hp", 1.0)
			u.empower_damage_mult = row.get("solo_dmg", 1.0)
			u.empower_splash_radius = row.get("solo_splash", 0)
			u.empower_attack_speed_mult = row.get("solo_spd", 1.0)
			if t == TIERS and row.has("apex"):
				var apex: Dictionary = row.apex
				u.max_hp = snappedf(u.max_hp * float(apex.get("hp", 1.0)), 1.0)
				u.attack_damage = snappedf(
					u.attack_damage * float(apex.get("dmg", 1.0)), 0.5)
				# A multiplier, not a replacement: the apex beam is a siege engine,
				# and its reload is the only thing standing between it and the
				# whole board at once.
				u.attack_speed = snappedf(
					u.attack_speed * float(apex.get("spd", 1.0)), 0.01)
				u.pierce_targets = apex.get("pierce", u.pierce_targets)
				u.beam_endless = apex.get("endless", false)
				u.beam_splash = apex.get("wash", 0.0)
				if apex.has("range"):
					u.attack_range = UnitData.RangeBand[apex.range]
			if row.has("ability"):
				u.ability = abilities[row.ability]
			u.sprite = _portrait_for(row.id)
			u.next_tier = built[0] if not built.is_empty() else null
			_save(u, "%s/%s_t%d.tres" % [UNITS_DIR, row.id, t])
			built.push_front(u)
		_tier_ones[row.id] = built[0]
		if not row.get("hidden", false):
			all_playable.append(built[0])
			if tier_ones.size() < LoadoutData.DEFAULT_SIZE:
				tier_ones.append(built[0])
		if built[0].chain_length() != TIERS:
			push_error("Merge chain for %s is %d long, expected %d" % [
				row.id, built[0].chain_length(), TIERS])

	loadout.units = tier_ones
	_save(loadout, "%s/starter.tres" % LOADOUT_DIR)
	roster.units = all_playable
	_save(roster, "%s/roster.tres" % LOADOUT_DIR)
	return loadout


func _make_buffs() -> void:
	for row in BUFF_TABLE:
		var b := BuffData.new()
		b.id = row.id
		b.display_name = row.name
		b.kind = BuffData.Kind[row.kind]
		b.unit_id = row.get("unit", &"")
		var extra: Array[StringName] = []
		for id in row.get("also", []):
			extra.append(id)
		b.also_units = extra
		b.weight = row.weight
		b.bronze = row.b
		b.silver = row.s
		b.gold = row.g
		if row.has("stat_a"):
			b.stat_a = StatModifier.Stat[row.stat_a]
		if row.has("stat_b"):
			b.stat_b = StatModifier.Stat[row.stat_b]
		b.uses_second_stat = row.get("two", false)
		b.flat = row.get("flat", false)
		b.flat_b = row.get("flat_b", false)
		if row.has("only"):
			b.exclusive_rarity = int(BuffData.Rarity[row.only])
		if row.has("stat_c"):
			b.stat_c = StatModifier.Stat[row.stat_c]
		if row.has("three"):
			b.third = row.three
			b.uses_third_stat = true
		b.empowered_cap_at_gold = row.get("empowered_cap_at_gold", 0)
		b.extra_raises = row.get("extra_raises", Vector3.ZERO)
		b.wall_toughness = row.get("wall_toughness", Vector3.ZERO)
		b.shield_on_hit = row.get("shield_on_hit", Vector3.ZERO)
		b.extra_summons = row.get("extra_summons", Vector3.ZERO)
		b.max_tier = row.get("max_tier", 0)
		b.stun_bonus = row.get("stun_bonus", Vector3.ZERO)
		b.charge_bonus = row.get("charge_bonus", Vector3.ZERO)
		_save(b, "%s/%s.tres" % [BUFF_DIR, row.id])


const PORTRAIT_DIR := "res://assets/portraits"


func _portrait_for(id: StringName) -> Texture2D:
	# Its own art if there is any, otherwise the shared placeholder, otherwise
	# nothing at all — and nothing at all is fine, because UnitView falls back to
	# drawing the unit's letter when `sprite` is null. Adding art for one unit is
	# dropping one PNG in; it needs no code change and no table edit.
	var own := "%s/%s.png" % [PORTRAIT_DIR, id]
	if ResourceLoader.exists(own):
		return load(own) as Texture2D
	var stand_in := "%s/placeholder.png" % PORTRAIT_DIR
	if ResourceLoader.exists(stand_in):
		return load(stand_in) as Texture2D
	return null


func _numeral(t: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII"][clampi(t, 0, 8)]
