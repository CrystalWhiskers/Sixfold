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
			".............",
			".............",
			".............",
			".............",
			".............",
			".............",
			".............",
			"^^^^^^^^^^^^^",
		],
		note = "Thirteen wide and shallow, with a firing step along both backs. Almost everything is in range of almost everything from the opening tick.",
	},
	{
		id = &"the_steppes", name = "The Steppes", w = 11, h = 13, neutral = true,
		rows = [
			"^^^^^^^^^^^",
			"...........",
			"..^^^^^^^..",
			"...........",
			"....^^^....",
			"...........",
			"...........",
			"...........",
			"....^^^....",
			"...........",
			"..^^^^^^^..",
			"...........",
			"^^^^^^^^^^^",
		],
		note = "Wide open ground in terraces. Every ridge is a range band for whoever gets to it, and the back rank of each side is the highest ground on the board.",
	},
	{
		id = &"the_cauldron", name = "The Cauldron", w = 11, h = 11, neutral = true,
		rows = [
			"...........",
			".^^^^^^^^^.",
			".^.......^.",
			".^.......^.",
			".^.......^.",
			".^.......^.",
			".^.......^.",
			".^.......^.",
			".^.......^.",
			".^^^^^^^^^.",
			"...........",
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
			"...#...#...",
			"...#...#...",
			"...#...#...",
			"...#...#...",
			"...#...#...",
			"...#...#...",
			"...#...#...",
			"...........",
			"...........",
		],
		note = "Three lanes, walled off from each other the whole way, meeting only behind each side's own lines. You are not fighting one battle here, you are funding three.",
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
			"......",
			"..##..",
			"......",
			"......",
			"..##..",
			"......",
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
			"...^^^...",
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
			"....^....",
			"...X.X...",
			"..X^^^X..",
			"..X^^^X..",
			"..X^^^X..",
			"...X.X...",
			"....^....",
			".........",
			".........",
		],
		note = "A high plateau ringed by a dry moat, with one ramp on each side. Holding it means every archer you own gains a range band and shoots over the moat at everything below.",
	},
	{
		id = &"ramparts", name = "Ramparts", w = 7, h = 11, neutral = true,
		rows = [
			".^^^^^.",
			".......",
			".......",
			".......",
			".......",
			".......",
			".......",
			".......",
			".......",
			".......",
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
			".......",
			".^...^.",
			"XX...XX",
			"XX...XX",
			"XX...XX",
			"XX...XX",
			"XX...XX",
			".^...^.",
			".......",
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
			"XX..^..XX",
			"XXX...XXX",
			"XXX...XXX",
			"XXX...XXX",
			"XX..^..XX",
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
			".........",
			".XXXXXXX.",
			".XXXXXXX.",
			".XXXXXXX.",
			".........",
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
			"^....#.....^",
			"..#..#...#..",
			".###.##.###.",
			"..#......#..",
			"..#..#.^.#..",
			".....#......",
			"#.#.####.#.#",
			"..#......#..",
			"#.##.##.##.#",
			"............",
			"#.##.##.##.#",
			"..#......#..",
			"#.#.####.#.#",
			".....#......",
			"..#..#.^.#..",
			"..#......#..",
			".###.##.###.",
			"..#..#...#..",
			"^....#.....^",
			"..#..#...#..",
		],
		note = "The biggest board there is: 81 tiles a side, cut into a warren of two- and three-tile rooms. Four gates cross the middle, so a fight here is never one fight — it is six little ones in separate rooms that cannot see each other.",
	},
]

const UNIT_TABLE := [
	{
		id = &"warden", name = "Warden", hp = 220.0, dmg = 34.0, spd = 0.35,
		move = 0.85, range = "MELEE", sight = 3, type = "MELEE",
		accent = Color(0.38, 0.47, 0.60),
		ability = &"bulwark_shield", mana = 20.0, opens = true,
		note = "Slow to swing and slower to walk, but hits like a truck behind a shield bigger than itself.",
	},
	{
		id = &"lancer", name = "Lancer", hp = 95.0, dmg = 16.0, spd = 1.1,
		move = 0.36, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.72, 0.35, 0.28),
		ability = &"impale", mana = 25.0, pierce = 2,
		note = "Every swing already cuts through two. The ability makes it three, harder.",
	},
	{
		id = &"archer", name = "Archer", hp = 55.0, dmg = 19.0, spd = 1.05,
		move = 0.50, range = "LONG", sight = 5, type = "RANGED",
		accent = Color(0.55, 0.62, 0.32),
		ability = &"quickdraw", mana = 25.0,
		note = "Charges fastest of anyone and never stops speeding up. Fold if reached.",
	},
	{
		id = &"vexer", name = "Vexer", hp = 85.0, dmg = 6.0, spd = 2.4,
		move = 0.45, range = "MEDIUM", sight = 4, type = "RANGED",
		accent = Color(0.45, 0.40, 0.66),
		ability = &"blight", mana = 12.0,
		note = "Weak hits, but the fastest attack rate means the bar fills constantly.",
	},
	{
		id = &"pyre", name = "Pyre", hp = 90.0, dmg = 7.0, spd = 0.7,
		move = 0.55, range = "MEDIUM", sight = 4, type = "SPELL",
		accent = Color(0.78, 0.55, 0.22),
		ability = &"cinder_lance", mana = 34.0,
		note = "Ordinary attacks are feeble. Everything rides on landing the burst.",
	},
	{
		id = &"assassin", name = "Assassin", hp = 60.0, dmg = 12.0, spd = 1.2,
		move = 0.34, range = "MELEE", sight = 6, type = "MELEE",
		accent = Color(0.42, 0.30, 0.48),
		ability = &"shadowstep", mana = 25.0, opens = true,
		note = "Opens behind someone, hits once for a fortune, then nobody can find it.",
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
		id = &"seraph", name = "Seraph", hp = 95.0, dmg = 8.0, spd = 0.95,
		move = 0.48, range = "MEDIUM", sight = 4, type = "RANGED",
		accent = Color(0.55, 0.80, 0.75),
		ability = &"benediction", mana = 34.0,
		note = "Fills its bar fast and dumps it all into whoever is closest to dying.",
	},
	{
		id = &"conjurer", name = "Conjurer", hp = 150.0, dmg = 5.0, spd = 0.6,
		move = 0.50, range = "MEDIUM", sight = 4, type = "SPELL",
		accent = Color(0.62, 0.48, 0.78),
		ability = &"call_wisp", mana = 26.0, opens = true,
		note = "Tanky and feeble on its own. Its wisps match its tier and do the work.",
	},
	{
		id = &"transcendence", name = "Transcendence", hp = 165.0, dmg = 22.0, spd = 0.45,
		move = 0.62, range = "MEDIUM", sight = 4, type = "RANGED",
		accent = Color(0.58, 0.56, 0.44),
		mana = 0.0, magnet = true, beam = true,
		apex = {hp = 4.0, dmg = 4.0, range = "UNLIMITED", pierce = 100,
			endless = true, wash = 0.5, spd = 0.5},
		note = "No ability, no tricks, and slower to swing than anything else on the board. Every merge it touches comes out Transcendence, and at tier 6 it fires a beam across the whole board that takes the rank behind the target with it — once every four seconds, so what it is aimed at matters more than how often.",
	},
	{
		id = &"amalgam", name = "Amalgam", hp = 190.0, dmg = 15.0, spd = 0.8,
		move = 0.50, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.46, 0.52, 0.38),
		mana = 0.0, wild = true,
		note = "Merges with anything you own, whatever it is. Thick, steady, and never quite the same twice.",
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
		id = &"wellspring", name = "Wellspring", hp = 120.0, dmg = 9.0, spd = 0.75,
		move = 0.52, range = "MEDIUM", sight = 4, type = "SPELL",
		accent = Color(0.40, 0.68, 0.72),
		ability = &"overflow", mana = 0.0, regen = 6.0, opens = true,
		note = "Opens a pool of mana around itself on the first beat. Everyone standing in it casts sooner.",
	},
	{
		id = &"tyrant", name = "Tyrant", hp = 240.0, dmg = 40.0, spd = 0.9,
		move = 0.55, range = "MELEE", sight = 4, type = "MELEE",
		accent = Color(0.55, 0.16, 0.22),
		mana = 0.0, burden_radius = 2, burden = 0.30,
		note = "Plainly stronger than anything else you can field, and every one of your own units standing within two tiles of it takes 30% more damage. It wants to be alone, which is also where a single strong unit is easiest to surround.",
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
		id = &"sentry", name = "Sentry", hp = 90.0, dmg = 45.0, spd = 0.3,
		move = 0.60, range = "UNLIMITED", sight = 6, type = "RANGED",
		accent = Color(0.48, 0.55, 0.62),
		mana = 0.0, rooted = true, mechanical = true, hidden = true,
		note = "Built, not drawn. It cannot move and it cannot be moved, it sees the whole board, and it fires rarely and enormously. Stone still stops its shot like anyone else's.",
	},
	{
		id = &"wisp", name = "Wisp", hp = 34.0, dmg = 7.0, spd = 1.3,
		move = 0.40, range = "MELEE", sight = 3, type = "MELEE",
		accent = Color(0.70, 0.62, 0.86),
		mana = 0.0, hidden = true,
		note = "Summoned only. Never drawn, never merged, gone when the round ends.",
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
		desc = "Poisons one enemy. Keeps working while the Vexer shoots someone else.",
		dot_damage = 11.0, dot_ticks = 6, dot_interval = 0.5,
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
		desc = "A heavy burst of healing on whoever nearby is hurt worst. Bigger every tier.",
		heal_percent = 0.45, heal_percent_per_tier = 0.20, heal_radius = 3,
	},
	{
		id = &"call_wisp", name = "Call Wisp", kind = "SUMMON", cast_time = 0.5,
		desc = "Fills its retinue back up to strength with wisps on the tiles beside it — one at the lowest tiers, three at the highest. Every cast tops it back up, so a wisp that dies is replaced the next time the bar is full.",
		summon = &"wisp", summon_max = 3, summon_retinue = true,
	},
	{
		id = &"raise_host", name = "Raise Host", kind = "SUMMON", cast_time = 1.4,
		desc = "Pours everything it has gathered into two new units, drawn at random from your own roster at its own tier and placed as close to it as the board allows. Never another Spire. Each arrives already casting its own ability. They are yours for the rest of the match, and raising them uses the Spire up. If your half has no room for both, nothing is raised at all.",
		summon_count = 2, summon_random = true, summon_cap_by_tier = false,
		summon_max = 100, summon_persists = true, consumes_caster = true,
		guards_caster = true, summon_instacasts = true,
	},
	{
		id = &"assemble", name = "Assemble", kind = "SUMMON", cast_time = 2.5,
		desc = "Spends the opening of the round bolting a Sentry together on the tile it is standing on, then steps aside and leaves it there. It is head-down while it works and takes double damage the whole time. If its Sentry is destroyed it will build another once its bar is full, and it will not start a build it has no room to finish.",
		summon = &"sentry", summon_max = 1, summon_cap_by_tier = false,
		summon_retinue = true, summon_at_caster = true,
		opener_takes_time = true, exposes_caster = 1.0, holds_when_capped = true,
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
	{id = &"rupture", name = "Rupture", kind = "PERCENT_HP_DAMAGE", weight = 1.0,
		b = Vector2(0.01, 0.0), s = Vector2(0.02, 0.0), g = Vector2(0.04, 0.0)},
	{id = &"windfall", name = "Windfall", kind = "MERGE_EXTRA_UNIT", weight = 1.0,
		b = Vector2(0.10, 0.0), s = Vector2(0.20, 0.0), g = Vector2(0.40, 0.0)},
	{id = &"promotion", name = "Promotion", kind = "MERGE_EXTRA_TIER", weight = 1.0,
		b = Vector2(0.04, 0.0), s = Vector2(0.08, 0.0), g = Vector2(0.16, 0.0)},
	{id = &"full_muster", name = "Full Muster", kind = "FULL_ROSTER", weight = 1.0,
		stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.30, 0.30), s = Vector2(0.60, 0.60), g = Vector2(1.20, 1.20)},
	{id = &"war_drums", name = "War Drums", kind = "STAT", weight = 1.0,
		stat_a = "ATTACK_SPEED",
		b = Vector2(0.15, 0.0), s = Vector2(0.30, 0.0), g = Vector2(0.60, 0.0)},

	{id = &"ironwall", name = "Ironwall", kind = "STAT", weight = 1.0,
		unit = &"warden", stat_a = "MAX_HP",
		b = Vector2(0.50, 0.0), s = Vector2(1.00, 0.0), g = Vector2(2.00, 0.0)},
	{id = &"marksmanship", name = "Marksmanship", kind = "STAT", weight = 1.0,
		unit = &"archer", stat_a = "ATTACK_DAMAGE", stat_b = "ATTACK_SPEED", two = true,
		b = Vector2(0.25, 0.15), s = Vector2(0.50, 0.30), g = Vector2(1.00, 0.60)},
	{id = &"vigor", name = "Vigor", kind = "STAT", weight = 1.0,
		unit = &"lancer", stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.30, 0.20), s = Vector2(0.60, 0.40), g = Vector2(1.20, 0.80)},
	{id = &"conflagration", name = "Conflagration", kind = "STAT", weight = 1.0,
		unit = &"pyre", stat_a = "ATTACK_DAMAGE", stat_b = "ATTACK_SPEED", two = true,
		b = Vector2(0.40, 0.10), s = Vector2(0.80, 0.20), g = Vector2(1.60, 0.40)},
	{id = &"swarm", name = "Swarm", kind = "STAT", weight = 1.0,
		unit = &"vexer", stat_a = "ATTACK_SPEED",
		b = Vector2(0.50, 0.0), s = Vector2(1.00, 0.0), g = Vector2(2.00, 0.0)},

	{id = &"shadowcraft", name = "Shadowcraft", kind = "STAT", weight = 1.0,
		unit = &"assassin", stat_a = "ATTACK_SPEED", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.10, 0.15), s = Vector2(0.20, 0.30), g = Vector2(0.40, 0.60)},
	{id = &"fanfare", name = "Fanfare", kind = "STAT", weight = 1.0,
		unit = &"herald", stat_a = "ATTACK_DAMAGE", stat_b = "MAX_HP", two = true,
		stat_c = "AURA_POWER", three = Vector3(0.25, 0.50, 1.00),
		b = Vector2(0.20, 0.25), s = Vector2(0.40, 0.50), g = Vector2(0.80, 1.00)},
	{id = &"undying", name = "Undying", kind = "STAT", weight = 1.0,
		unit = &"revenant", stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.50, 0.50), s = Vector2(1.00, 1.00), g = Vector2(2.00, 2.00)},
	{id = &"grace", name = "Grace", kind = "STAT", weight = 1.0,
		unit = &"seraph", stat_a = "MAX_HP", stat_b = "HEAL_POWER", two = true,
		b = Vector2(0.35, 0.10), s = Vector2(0.70, 0.20), g = Vector2(1.40, 0.40)},
	{id = &"covenant", name = "Covenant", kind = "STAT", weight = 1.0,
		unit = &"conjurer", also = [&"wisp"],
		stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.50, 0.30), s = Vector2(1.00, 0.60), g = Vector2(2.00, 1.20)},
	{id = &"cohesion", name = "Cohesion", kind = "STAT", weight = 1.0,
		unit = &"amalgam", stat_a = "MAX_HP",
		b = Vector2(1.00, 0.0), s = Vector2(2.00, 0.0), g = Vector2(3.00, 0.0)},
	{id = &"incubation", name = "Incubation", kind = "STAT", weight = 1.0,
		unit = &"spire", stat_a = "MANA_REGEN", stat_b = "MAX_HP", two = true,
		flat = true,
		b = Vector2(3.0, 0.50), s = Vector2(6.0, 1.00), g = Vector2(9.0, 2.00)},
	{id = &"confluence", name = "Confluence", kind = "STAT", weight = 1.0,
		unit = &"wellspring", stat_a = "MANA_REGEN", stat_b = "MAX_HP", two = true,
		flat = true,
		b = Vector2(3.0, 0.30), s = Vector2(6.0, 0.60), g = Vector2(9.0, 0.90)},
	{id = &"dominion", name = "Dominion", kind = "STAT", weight = 1.0,
		unit = &"tyrant", stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.40, 0.40), s = Vector2(0.80, 0.80), g = Vector2(1.60, 1.60)},
	{id = &"fabrication", name = "Fabrication", kind = "STAT", weight = 1.0,
		unit = &"engineer", also = [&"sentry"],
		stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.50, 0.40), s = Vector2(1.00, 0.80), g = Vector2(2.00, 1.60)},
	{id = &"ascension", name = "Ascension", kind = "STAT", weight = 1.0,
		unit = &"transcendence", stat_a = "MAX_HP", stat_b = "ATTACK_DAMAGE", two = true,
		b = Vector2(0.50, 0.50), s = Vector2(1.00, 1.00), g = Vector2(1.50, 1.50)},

	{id = &"far_sight", name = "Far Sight", kind = "STAT", weight = 1.0,
		only = "GOLD", stat_a = "ATTACK_RANGE", flat = true,
		b = Vector2(1.0, 0.0), s = Vector2(1.0, 0.0), g = Vector2(1.0, 0.0)},
	{id = &"levy", name = "Levy", kind = "BOARD_FILL", weight = 0.8,
		only = "GOLD",
		b = Vector2(1.0, 0.0), s = Vector2(1.0, 0.0), g = Vector2(1.0, 0.0)},
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
		b = Vector2(1.0, 0.0), s = Vector2(1.0, 0.0), g = Vector2(2.0, 0.0)},
]


func build() -> String:
	print("Generating data for Six by Eleven...")
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
			"heal_percent", "heal_percent_per_tier", "heal_radius", "summon_max",
				"summon_count", "summon_random", "summon_cap_by_tier", "mana_aura_radius",
				"summon_persists", "consumes_caster", "summon_adjacent",
				"guards_caster", "summon_instacasts", "summon_retinue",
				"opener_takes_time", "exposes_caster", "summon_at_caster",
				"holds_when_capped",
				"dot_damage", "dot_ticks", "dot_interval", "burst_damage",
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
		_save(a, "%s/%s.tres" % [ABILITY_DIR, row.id])


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
		_save(b, "%s/%s.tres" % [BUFF_DIR, row.id])


func _numeral(t: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII"][clampi(t, 0, 8)]
