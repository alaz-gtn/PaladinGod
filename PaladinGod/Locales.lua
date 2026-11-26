local _, ns = ...

-- English first; the Spanish client overwrites what it has
local L = {
	PREFIX = "|cfff48cbaPaladinGod:|r ",
	SUBTITLE = "Quality of life for paladins",
	YARDS = "yd",
	METERS = "m",
	NOT_IN_COMBAT = "not in combat: try again when the fight is over.",
	UNLOCKED = "displays unlocked: drag them where you want them. /paladingod lock when you're done.",
	LOCKED = "displays locked.",

	-- Reminders
	REMINDERS = "Reminders",
	CLICK_CAST = "Click: %s",
	CLICK_CANCEL = "Click: take off %s",
	FURY_WARN = "Not tanking?",
	FURY_WARN_TIP = "You're in a group with Righteous Fury on: it makes you pull the aggro off the tank. If you tank, set it in the options.",
	FOOD_NAME = "Food and reagents",
	FOOD_MISSING = "No XP from food",
	CLICK_FOOD = "Click: your XP food",
	CLICK_EAT = "Click: eat it",
	NO_XP_FOOD = "No XP food in your bags",
	WELL_FED = "Well Fed",
	FOOD_STOCK = "XP food in your bags: %s",
	BUFFS_REPORT = "aura: %s; blessing: %s; Righteous Fury: %s; seal: %s; food buff: %s.",
	BUFFS_SEEN = "buffs on you: %s",
	BUFFS_HIDDEN = "the game hides your buffs in combat: try again out of it.",
	BUFF_LEFT = "%s, %s left",
	BUFF_ON = "%s, no end",
	BUFF_NONE = "none",
	BUFF_UNKNOWN = "not seen yet",
	FOOD_MAX_LEVEL = "no (no XP to gain at your level)",
	SEAL_NAME = "Seal seconds",
	SEAL_MISSING = "No seal on",
	GATHER_OFF = "No gathering tracking on",

	-- Your group's blessings
	GROUP_NAME = "Group blessings",
	GROUP_MORE = "and %d more",
	GROUP_FAR = "Out of reach",

	-- Procs
	PROCS_NAME = "Procs",
	PROCS_WATCHING = "%s: watching spells %s.",
	PROCS_NOT_READY = "%s isn't set up yet: the addon builds it out of combat, once you know it.",
	PROCS_REFUSED = "the game didn't take the animations for %s, so it won't show.",

	-- Swing timer
	SWING_NAME = "Swing timer",

	-- Hammer of Wrath and Exorcism
	EXECUTE_NAME = "Hammer and Exorcism",
	INTERRUPT_WORD = "Stop it",
	COOLDOWNS_NAME = "Cooldown ready",
	HAMMER_WORD = "20%",

	-- Range
	RANGE = {
		melee = "Melee",
		judge = "10 yards",
		ranged = "30 yards",
		heal = "Heals reach",
		out = "Out of range",
	},
	RANGE_NO_TARGET = "no target.",
	RANGE_REPORT = "%s at %d-%d yd; %s.",
	RANGE_STEPS = "range checks: ",
	RANGE_LOADING = "(some range items not loaded yet)",
	RANGE_YES = "yes",
	RANGE_NO = "no",
	UNITS_SET = "range in %s.",
	THREAT = "AGGRO %d%%",
	THREAT_PULLED = "YOU HAVE AGGRO!",
	THREAT_LOST = "AGGRO LOST!",
	THREAT_NAME = "Aggro",

	-- Options
	TAB_BUFFS = "Reminders",
	TAB_GROUP = "Blessings",
	TAB_COMBAT = "Combat",
	TAB_PROCS = "Procs",
	TAB_RANGE = "Range",
	TAB_THREAT = "Aggro",
	SEC_BUFFS = "Your buffs",
	OPT_BUFFS_ON = "Remind me of the buffs I'm missing",
	OPT_AURA = "My aura",
	OPT_AURA_CHOICE = "Which aura",
	AURA_AUTO = "The last one you had on",
	OPT_BLESSING = "My blessing on me",
	OPT_BLESSING_CHOICE = "Which blessing",
	BLESSING_AUTO = "The last one you had",
	FURY = {
		warn = "I don't tank: warn me if it's on",
		tank = "I tank: remind me of it",
		off = "Nothing",
	},
	OPT_WARN_TIME = "Warn before it ends (minutes)",
	OPT_TEXT = "A word under the icons that need one",
	OPT_CLICK = "Click a reminder to cast it (out of combat)",
	BUFFS_HINT = "They show above your character: the aura in combat too, the blessing out of combat (in Forever it lasts an hour), Righteous Fury (30 minutes) as you set it. Grey: missing; in colour with its time: running out.",
	SEC_SEAL = "Seal",
	OPT_SEAL = "My seal: grey with the reminders if I fight without one, and its seconds while it's on",
	OPT_SEAL_CHOICE = "Which seal a click casts",
	SEAL_AUTO = "The last one you cast",
	OPT_SEAL_TARGET = "Remind me out of combat too, with an enemy targeted",
	OPT_SIZE = "Size",
	SEAL_HINT = "In Forever a Judgement doesn't use your seal up: it lasts its 30 seconds. Without one, it shows grey with the other reminders, and a click out of combat casts it. While it's on, its icon with the seconds it has left goes on a spot of its own: Forever hides them in combat, so the game itself draws it. Move both with the Move displays button.",
	SEC_GATHER = "Gathering tracking",
	OPT_GATHER = "Herbalism or Mining: remind me to turn on %s or %s out in the world",
	SEC_REAGENTS = "Reagents",
	OPT_REAGENTS = "Remind me when my reagents run low (Symbol of Divinity, Symbol of Kings), unless I have %s",
	REAGENTS_HINT = "Only for the spells you know: Divine Intervention, and the Greater Blessings from level 52. They show beside the chat with the food one, out of combat. A vendor that sells one you're low on says so in the chat.",
	SEC_REPAIR = "Gear and bags",
	OPT_REPAIR = "Remind me when my gear wears out or my bags fill up",
	OPT_REPAIR_LOW = "Gear under (%)",
	OPT_REPAIR_BAGS = "Free bag slots at most",
	REPAIR_HINT = "Beside the chat with the food one, out of combat. A vendor who repairs says in the chat how worn your gear is.",
	OPT_GROUP_BUFFS = "My class's buffs someone in my group lacks, in the reminders",
	SEC_FOOD = "Food",
	OPT_FOOD_ON = "A small reminder when I'm not Well Fed (+5% XP from kills)",
	SEC_GROUP = "Your group",
	OPT_GROUP = "Who in my group lacks my blessing, out of combat",
	OPT_GROUP_ROWS = "Rows at most",
	GROUP_HINT = "Missing first, then the ones running out. Click a row to bless that player. Another paladin's blessing of the same kind counts. Greyed out: too far away.",
	SEC_CLASSES = "The blessing for each class",
	GROUP_NONE = "None",
	CLASSES = {
		WARRIOR = "Warrior", ROGUE = "Rogue", PALADIN = "Paladin", HUNTER = "Hunter", SHAMAN = "Shaman",
		DRUID = "Druid", PRIEST = "Priest", MAGE = "Mage", WARLOCK = "Warlock",
	},
	SEC_SWING = "Swing timer",
	OPT_SWING = "A bar for my weapon's swing",
	OPT_WIDTH = "Width",
	OPT_HEIGHT = "Height",
	OPT_SWING_ICON = "My weapon's icon beside it",
	OPT_SWING_TIME = "The seconds to the next swing",
	OPT_SWING_BLIZZARD = "Hide the game's own swing bar",
	OPT_COLOR = "Colour",
	OPT_TEST = "See how it looks",
	TRY = "Try it",
	SWING_HINT = "It shows while you attack and lights up as the swing comes. Grey: your target is out of your weapon's reach. Move it with the Move displays button.",
	SEC_EXECUTE = "Hammer of Wrath and Exorcism",
	OPT_HAMMER = "%s when my target is at 20%% or under",
	OPT_EXORCISM = "%s against undead and demons",
	OPT_INTERRUPT = "%s while my target casts, to stop it (a paladin has no interrupt: the stun stops the cast)",
	SEC_COOLDOWNS = "Big cooldowns",
	OPT_COOLDOWNS = "Its icon big in the middle each time one of them is ready again",
	OPT_ALPHA = "Strength (%)",
	OPT_SHINE_COLOR = "Colour of the shine behind it",
	COOLDOWNS_HINT = "Only the ones you know. It pops up and fades in under a second; two at once come one after the other. In combat Forever hides how long a cooldown has left, but not whether it's running, so it shows in fights too, and the global cooldown doesn't set it off. Move it with the Move displays button.",
	SEC_DEBUFFS = "On your enemies",
	OPT_DEBUFFS = "My effects on my enemies, beside their nameplates, with the seconds left",
	OPT_DEBUFF = {
		judgement = "My Judgement (of the Crusader, Light, Wisdom or Justice)",
		control = "My stuns and the like: Hammer of Justice, Repentance, Turn Undead, Seal of Justice",
		vindication = "Vindication (Retribution talent)",
	},
	DEBUFFS_HINT = "Small icons left of the health bar of each enemy's nameplate (it needs the enemy nameplates on). Only yours, and only of the spells you know. The game itself shows them, so they work in combat too. A new size takes effect after /reload.",
	EXECUTE_HINT = "Above your character while the spell is ready. In combat Forever hides your target's health, so the game itself shows or hides the hammer. A target picked in combat may hide what kind of creature it is: then Exorcism doesn't show.",
	SEC_PROCS_LOOK = "Look",
	OPT_PROCS_SIZE = "Size (%)",
	OPT_PROCS_X = "Left or right",
	OPT_PROCS_Y = "Down or up",
	OPT_PROCS_GAP = "Space between the two columns of light",
	OPT_PROCS_ALPHA = "Strength of the burst as it procs (%)",
	OPT_PROCS_CALM = "Strength afterwards, while it lasts (%)",
	OPT_PROCS_TIMER = "The seconds it has left",
	OPT_PROCS_TIMER_SIZE = "Size of the number",
	OPT_PROC = {
		infusion = "Holy. Light falling at your sides while %s is up (your next Holy Light is 1 sec faster)",
		divinefavor = "Holy. A small halo over your head while %s waits for your next heal (it will crit)",
		vengeance = "Retribution. A holy circle at your feet while %s is up (more damage after a crit)",
		redoubt = "Protection. A blue circle at your feet while %s is up (30%% more block)",
		shieldsworn = "Protection. A wider ring turning the other way while %s is up (you block spells)",
		reckoning = "Protection. Light rising at your sides while %s is up (extra attacks stored)",
		ironcreed = "Protection. A small shield in front of you while %s is up (less damage taken)",
	},
	PROCS_HINT = "Each comes with its talent, so you only see your build's. Each has its own place, so the ones a build can have together don't cover each other. The game itself shows them, so they work in combat too; changes made in a fight wait until it's over. Forever's tooltips show no buff for Reckoning: it may never show. Drag them with the Move displays button.",
	SEC_BARRIER = "Shields",
	BARRIER_NAME = "Shield",
	OPT_BARRIER = "A bar with what's left of a shield on you: %s, a priest's or any other class's, or a protection potion",
	OPT_BARRIER_POTIONS = "The protection potions too (fire, frost, nature, shadow, arcane, holy)",
	OPT_BARRIER_TEXT = "Show how much it still absorbs",
	OPT_BARRIER_TIME = "Show the seconds it has left",
	OPT_BARRIER_ICON = "The shield's icon beside it",
	OPT_BARRIER_COLOR = "Colour for %s",
	OPT_BARRIER_OTHER = "Colour for a shield the addon can't tell",
	BARRIER_HINT = "In combat Forever hides how much a shield absorbs, but the game fills the bar in itself. It only gives the total of every shield on you: with two at once the bar shows both. Each potion in its school's colour. Move it with the Move displays button.",
	SEC_DISTANCE = "Distance",
	OPT_RANGE_ON = "Show the range to my target",
	OPT_FRIENDLY = "Also on friends: within my heals' 40 yards or not",
	OPT_ONLY_COMBAT = "Only in combat",
	OPT_WORDS = "\"Melee\" in words instead of a number",
	OPT_UNIT_LABEL = "yd or m after the number",
	SEC_LOOK = "Look",
	OPT_DISPLAY = "Show",
	DISPLAY = { number = "One number (32 yd)", bracket = "Between two checks (30-35 yd)" },
	OPT_UNITS = "Units",
	UNITS = { yards = "Yards", meters = "Metres" },
	OPT_FONT = "Font",
	FONTS = { fredoka = "Fredoka", changa = "Changa", game = "The game's" },
	OPT_STYLE = "Style",
	STYLE = { text = "Number", icon = "Colour square", both = "Both" },
	OPT_POSITION = "Where",
	POSITION = { plate = "On the target's nameplate", free = "Where I put it" },
	OPT_PLATE_SIDE = "Side of the nameplate",
	PLATE_SIDE = { top = "Above", bottom = "Below", left = "Left", right = "Right" },
	OPT_PLATE_GAP = "Distance from the nameplate",
	PREVIEW_HINT = "Click a state to change its colour",
	SEC_THREAT = "Aggro in groups",
	OPT_THREAT = "Warn me before I pull aggro off the tank",
	OPT_THREAT_PCT = "From (% of the tank's threat)",
	OPT_TANK_WARN = "When I tank (Righteous Fury on), warn me when my target turns away from me",
	THREAT_HINT = "Solo you always have the aggro, so this only shows in a group.",
	UNLOCK = "Move displays",
	LOCK = "Lock displays",
	OPT_MINIMAP_BUTTON = "Minimap button",

	-- Talent reset price, under the class trainer's window
	SEC_RESPEC = "Class trainer",
	OPT_RESPEC = "When the talent reset price drops, under your trainer's window",
	RESPEC_HINT = "Blizzard doesn't publish it: players report a step up with each reset (1, 5, 10, then 5 g more up to 50 g) and a step down for each week since the last one. The price the trainer asks is the real one.",
	RESPEC_TITLE = "Talent reset",
	RESPEC_CLASS = "Class talents",
	RESPEC_LEGACY = "Legacy talents",
	RESPEC_LAST = "Last one %s ago, for %s",
	RESPEC_NOW = "Now: %s",
	RESPEC_NOW_ABOUT = "Now: about %s",
	RESPEC_DROPS = "Drops to %s %s (in %s)",
	RESPEC_LOWEST = "It's at its lowest",
	RESPEC_ASKED = "The trainer asked %s, %s ago",
	RESPEC_UNKNOWN = "%s doesn't know when you last reset yet: it writes it down the next time you pay for one.",
	RESPEC_TODAY = "today at %s",
	RESPEC_TOMORROW = "tomorrow at %s",
	RESPEC_ON = "on %s at %s",
	RESPEC_WEEKDAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" },
	RESPEC_MINUTES = "%d min",
	RESPEC_HOURS = "%d h",
	RESPEC_DAYS = "%d days",

	-- Minimap button
	TIP_LEFT = "Left click: options",
	TIP_RIGHT_UNLOCK = "Right click: move the displays",
	TIP_RIGHT_LOCK = "Right click: lock the displays",
	TIP_DRAG = "Drag: move this button",
	TIP_REAGENT = "%s: %d",

	HELP = {
		"|cfff48cbaPaladinGod|r commands:",
		"  /paladingod  - options (or click the minimap button; /paladin works too)",
		"  /paladingod unlock | lock  - move the displays",
		"  /paladingod meters | yards  - the range in metres or yards",
		"  /paladingod range  - what each range check says about your target",
		"  /paladingod buffs  - what the addon sees of your buffs",
		"  /paladingod procs  - try the procs' light",
		"  /paladingod swing  - try the swing timer",
		"  /paladingod hammer  - try Hammer of Wrath, Exorcism and Hammer of Justice",
		"  /paladingod cooldowns  - try the pulse for a big cooldown ready",
		"  /paladingod respec  - when the talent reset price drops",
		"  /paladingod button  - show or hide the minimap button",
	},
}

if GetLocale() == "esES" or GetLocale() == "esMX" then
	L.SUBTITLE = "Mejoras para paladines"
	L.NOT_IN_COMBAT = "no en combate: vuelve a probar cuando acabe la pelea."
	L.UNLOCKED = "avisos desbloqueados: arrástralos donde quieras. /paladingod bloquear cuando acabes."
	L.LOCKED = "avisos bloqueados."

	L.REMINDERS = "Avisos"
	L.CLICK_CAST = "Clic: %s"
	L.CLICK_CANCEL = "Clic: quitar %s"
	L.FURY_WARN = "¿No tanqueas?"
	L.FURY_WARN_TIP = "Estás en grupo con Furia recta puesta: te hace quitarle el agro al tanque. Si tanqueas, dilo en las opciones."
	L.FOOD_NAME = "Comida y reactivos"
	L.FOOD_MISSING = "Sin exp de comida"
	L.CLICK_FOOD = "Clic: tu comida de exp"
	L.CLICK_EAT = "Clic: comerla"
	L.NO_XP_FOOD = "No llevas comida de exp"
	L.WELL_FED = "Bien alimentado"
	L.FOOD_STOCK = "comida de exp en tus bolsas: %s"
	L.BUFFS_REPORT = "aura: %s; bendición: %s; Furia recta: %s; sello: %s; bufo de comida: %s."
	L.BUFFS_SEEN = "bufos que llevas: %s"
	L.BUFFS_HIDDEN = "el juego esconde tus bufos en combate: vuelve a probar fuera de él."
	L.BUFF_LEFT = "%s, le quedan %s"
	L.BUFF_ON = "%s, sin final"
	L.BUFF_NONE = "sin poner"
	L.BUFF_UNKNOWN = "aún sin ver"
	L.FOOD_MAX_LEVEL = "no (a tu nivel ya no ganas experiencia)"
	L.SEAL_NAME = "Segundos del sello"
	L.SEAL_MISSING = "Sin sello"
	L.GATHER_OFF = "Sin rastreo de recolección"

	L.GROUP_NAME = "Bendiciones del grupo"
	L.GROUP_MORE = "y %d más"
	L.GROUP_FAR = "Fuera de alcance"

	L.PROCS_NAME = "Procs"
	L.PROCS_WATCHING = "%s: vigilando los hechizos %s."
	L.PROCS_NOT_READY = "%s aún no está montado: el addon lo monta fuera de combate, cuando lo sepas."
	L.PROCS_REFUSED = "el juego no aceptó las animaciones de %s, así que no saldrá."

	L.SWING_NAME = "Barra de golpe"

	L.EXECUTE_NAME = "Martillo y Exorcismo"
	L.INTERRUPT_WORD = "Córtalo"
	L.COOLDOWNS_NAME = "Reutilización lista"
	L.HAMMER_WORD = "20%"

	L.RANGE = {
		melee = "Melee",
		judge = "10 yardas",
		ranged = "30 yardas",
		heal = "Alcance de curas",
		out = "Fuera de alcance",
	}
	L.RANGE_NO_TARGET = "no tienes objetivo."
	L.RANGE_REPORT = "%s a %d-%d yd; %s."
	L.RANGE_STEPS = "comprobaciones: "
	L.RANGE_LOADING = "(faltan por cargar algunos objetos de distancia)"
	L.RANGE_YES = "sí"
	L.RANGE_NO = "no"
	L.UNITS_SET = "distancia en %s."
	L.THREAT = "AGRO %d%%"
	L.THREAT_PULLED = "¡TIENES EL AGRO!"
	L.THREAT_LOST = "¡PIERDES EL AGRO!"
	L.THREAT_NAME = "Agro"

	L.TAB_BUFFS = "Avisos"
	L.TAB_GROUP = "Bendiciones"
	L.TAB_COMBAT = "Combate"
	L.TAB_PROCS = "Procs"
	L.TAB_RANGE = "Distancia"
	L.TAB_THREAT = "Agro"
	L.SEC_BUFFS = "Tus bufos"
	L.OPT_BUFFS_ON = "Recordarme los bufos que me faltan"
	L.OPT_AURA = "Mi aura"
	L.OPT_AURA_CHOICE = "Qué aura"
	L.AURA_AUTO = "La última que llevabas"
	L.OPT_BLESSING = "Mi bendición sobre mí"
	L.OPT_BLESSING_CHOICE = "Qué bendición"
	L.BLESSING_AUTO = "La última que llevabas"
	L.FURY = {
		warn = "No tanqueo: avisarme si la llevo",
		tank = "Tanqueo: recordármela",
		off = "Nada",
	}
	L.OPT_WARN_TIME = "Avisar antes de que se acabe (minutos)"
	L.OPT_TEXT = "Una palabra bajo los iconos que la necesitan"
	L.OPT_CLICK = "Hacer clic en un aviso para lanzarlo (fuera de combate)"
	L.BUFFS_HINT = "Salen encima de tu personaje: el aura también en combate, la bendición fuera de combate (en Forever dura una hora), Furia recta (30 minutos) según lo que elijas. En gris: falta; en color con su tiempo: se está acabando."
	L.SEC_SEAL = "Sello"
	L.OPT_SEAL = "Mi sello: en gris con los avisos si peleo sin él, y sus segundos mientras lo llevo"
	L.OPT_SEAL_CHOICE = "Qué sello lanza un clic"
	L.SEAL_AUTO = "El último que lanzaste"
	L.OPT_SEAL_TARGET = "Avisarme también fuera de combate, con un enemigo seleccionado"
	L.OPT_SIZE = "Tamaño"
	L.SEAL_HINT = "En Forever la Sentencia no gasta el sello: dura sus 30 segundos. Sin sello sale en gris con los demás avisos, y un clic fuera de combate te lo pone. Mientras lo llevas, su icono con los segundos que le quedan va en un sitio propio: en combate Forever los esconde, así que lo dibuja el propio juego. Mueve los dos con el botón Mover avisos."
	L.SEC_GATHER = "Rastreo de recolección"
	L.OPT_GATHER = "Herboristería o Minería: recordarme poner %s o %s fuera de mazmorras"
	L.SEC_REAGENTS = "Reactivos"
	L.OPT_REAGENTS = "Avisarme cuando me queden pocos reactivos (Símbolo de divinidad, Símbolo de reyes), salvo si tengo %s"
	L.REAGENTS_HINT = "Solo de los hechizos que sabes: Intervención divina, y las Bendiciones mayores desde el nivel 52. Salen junto al chat con el de la comida, fuera de combate. Un vendedor que tiene uno que te falta lo dice en el chat."
	L.SEC_REPAIR = "Equipo y bolsas"
	L.OPT_REPAIR = "Avisarme cuando se me gaste el equipo o se me llenen las bolsas"
	L.OPT_REPAIR_LOW = "Equipo por debajo del (%)"
	L.OPT_REPAIR_BAGS = "Huecos libres en las bolsas, como mucho"
	L.REPAIR_HINT = "Junto al chat con el de la comida, fuera de combate. Un vendedor que repara dice en el chat cómo está tu equipo."
	L.OPT_GROUP_BUFFS = "Los bufos de mi clase que le faltan a alguien del grupo, en los avisos"
	L.SEC_FOOD = "Comida"
	L.OPT_FOOD_ON = "Un aviso pequeño cuando no llevo Bien alimentado (+5% de exp por muerte)"
	L.SEC_GROUP = "Tu grupo"
	L.OPT_GROUP = "Quién de mi grupo no lleva mi bendición, fuera de combate"
	L.OPT_GROUP_ROWS = "Filas como mucho"
	L.GROUP_HINT = "Primero los que no la llevan y luego a los que se les acaba. Haz clic en una fila para bendecir a ese jugador. La bendición del mismo tipo de otro paladín cuenta. En gris: está demasiado lejos."
	L.SEC_CLASSES = "La bendición de cada clase"
	L.GROUP_NONE = "Ninguna"
	L.CLASSES = {
		WARRIOR = "Guerrero", ROGUE = "Pícaro", PALADIN = "Paladín", HUNTER = "Cazador", SHAMAN = "Chamán",
		DRUID = "Druida", PRIEST = "Sacerdote", MAGE = "Mago", WARLOCK = "Brujo",
	}
	L.SEC_SWING = "Barra de golpe"
	L.OPT_SWING = "Una barra para el golpe de mi arma"
	L.OPT_WIDTH = "Ancho"
	L.OPT_HEIGHT = "Alto"
	L.OPT_SWING_ICON = "El icono de mi arma al lado"
	L.OPT_SWING_TIME = "Los segundos hasta el siguiente golpe"
	L.OPT_SWING_BLIZZARD = "Ocultar la barra de golpe del juego"
	L.OPT_COLOR = "Color"
	L.OPT_TEST = "Ver cómo queda"
	L.TRY = "Probar"
	L.SWING_HINT = "Sale mientras atacas y se enciende según llega el golpe. En gris: tu objetivo está fuera del alcance de tu arma. Muévela con el botón Mover avisos."
	L.SEC_EXECUTE = "Martillo de cólera y Exorcismo"
	L.OPT_HAMMER = "%s cuando mi objetivo está al 20%% o menos"
	L.OPT_EXORCISM = "%s contra no-muertos y demonios"
	L.OPT_INTERRUPT = "%s cuando mi objetivo lanza algo, para cortarlo (el paladín no tiene interrupción: el aturdimiento corta el lanzamiento)"
	L.SEC_COOLDOWNS = "Reutilizaciones grandes"
	L.OPT_COOLDOWNS = "Su icono en grande en el centro cada vez que una vuelve a estar lista"
	L.OPT_ALPHA = "Intensidad (%)"
	L.OPT_SHINE_COLOR = "Color del destello de detrás"
	L.COOLDOWNS_HINT = "Solo las que sabes. Aparece de golpe y se desvanece en menos de un segundo; si vuelven dos a la vez, salen una tras otra. En combate Forever esconde cuánto le falta a un hechizo, pero no si está en reutilización, así que también sale en las peleas, y la reutilización global no lo dispara. Muévelo con el botón Mover avisos."
	L.SEC_DEBUFFS = "Sobre tus enemigos"
	L.OPT_DEBUFFS = "Mis efectos sobre mis enemigos, junto a su placa, con los segundos que les quedan"
	L.OPT_DEBUFF = {
		judgement = "Mi Sentencia (del cruzado, de luz, de sabiduría o de justicia)",
		control = "Mis aturdimientos y similares: Martillo de justicia, Arrepentimiento, Expulsar no-muertos, Sello de justicia",
		vindication = "Vindicación (talento de Reprensión)",
	}
	L.DEBUFFS_HINT = "Iconos pequeños a la izquierda de la barra de vida de la placa de cada enemigo (hacen falta las placas de enemigos). Solo los tuyos, y solo de los hechizos que sabes. Los muestra el propio juego, así que también salen en combate. Un tamaño nuevo se aplica tras /reload."
	L.EXECUTE_HINT = "Encima de tu personaje mientras el hechizo está listo. En combate Forever esconde la vida de tu objetivo, así que el propio juego enseña u oculta el martillo. Un objetivo que eliges en combate puede esconder qué tipo de criatura es: entonces Exorcismo no sale."
	L.SEC_PROCS_LOOK = "Aspecto"
	L.OPT_PROCS_SIZE = "Tamaño (%)"
	L.OPT_PROCS_X = "Izquierda o derecha"
	L.OPT_PROCS_Y = "Abajo o arriba"
	L.OPT_PROCS_GAP = "Separación entre las dos columnas de luz"
	L.OPT_PROCS_ALPHA = "Intensidad del destello al salir (%)"
	L.OPT_PROCS_CALM = "Intensidad después, mientras dura (%)"
	L.OPT_PROCS_TIMER = "Los segundos que le quedan"
	L.OPT_PROCS_TIMER_SIZE = "Tamaño del número"
	L.OPT_PROC = {
		infusion = "Sagrado. Luz que cae a tus lados mientras dura %s (tu próxima Luz Sagrada va 1 s más rápida)",
		divinefavor = "Sagrado. Un halo pequeño sobre tu cabeza mientras %s espera tu próxima cura (será crítica)",
		vengeance = "Reprensión. Un círculo sagrado a tus pies mientras dura %s (más daño tras un crítico)",
		redoubt = "Protección. Un círculo azul a tus pies mientras dura %s (30 %% más de bloqueo)",
		shieldsworn = "Protección. Un anillo mayor que gira al revés mientras dura %s (bloqueas hechizos)",
		reckoning = "Protección. Luz que sube a tus lados mientras dura %s (ataques extra guardados)",
		ironcreed = "Protección. Un escudo pequeño delante de ti mientras dura %s (menos daño recibido)",
	}
	L.PROCS_HINT = "Cada uno sale con su talento, así que solo ves los de tu build. Cada uno tiene su sitio, para que los que una build puede tener a la vez no se tapen. Los muestra el propio juego, así que también salen en combate; lo que cambies en una pelea se aplica al acabar. Los textos de Forever no traen bufo para Reckoning: puede que no salga nunca. Arrástralos con el botón Mover avisos."
	L.SEC_BARRIER = "Escudos"
	L.BARRIER_NAME = "Escudo"
	L.OPT_BARRIER = "Una barra con lo que le queda al escudo que llevas: %s, el de un sacerdote o el de cualquier clase, o una poción de protección"
	L.OPT_BARRIER_POTIONS = "También las pociones de protección (fuego, escarcha, naturaleza, sombras, arcano, sagrado)"
	L.OPT_BARRIER_TEXT = "Mostrar cuánto absorbe todavía"
	L.OPT_BARRIER_TIME = "Mostrar los segundos que le quedan"
	L.OPT_BARRIER_ICON = "El icono del escudo al lado"
	L.OPT_BARRIER_COLOR = "Color de %s"
	L.OPT_BARRIER_OTHER = "Color de un escudo que el addon no reconoce"
	L.BARRIER_HINT = "En combate Forever esconde cuánto absorbe un escudo, pero el propio juego rellena la barra. Solo da el total de todos los escudos que llevas: con dos a la vez la barra los muestra juntos. Cada poción en el color de su escuela. Muévela con el botón Mover avisos."
	L.SEC_DISTANCE = "Distancia"
	L.OPT_RANGE_ON = "Mostrar la distancia a mi objetivo"
	L.OPT_FRIENDLY = "También a aliados: dentro o fuera de las 40 yardas de mis curas"
	L.OPT_ONLY_COMBAT = "Solo en combate"
	L.OPT_WORDS = "\"Melee\" en palabras en vez de un número"
	L.OPT_UNIT_LABEL = "yd o m después del número"
	L.SEC_LOOK = "Aspecto"
	L.OPT_DISPLAY = "Mostrar"
	L.DISPLAY = { number = "Un número (32 yd)", bracket = "Entre dos comprobaciones (30-35 yd)" }
	L.OPT_UNITS = "Unidades"
	L.UNITS = { yards = "Yardas", meters = "Metros" }
	L.OPT_FONT = "Letra"
	L.FONTS = { fredoka = "Fredoka", changa = "Changa", game = "La del juego" }
	L.OPT_STYLE = "Estilo"
	L.STYLE = { text = "Número", icon = "Cuadrado de color", both = "Los dos" }
	L.OPT_POSITION = "Dónde"
	L.POSITION = { plate = "En la placa del objetivo", free = "Donde yo la ponga" }
	L.OPT_PLATE_SIDE = "Lado de la placa"
	L.PLATE_SIDE = { top = "Encima", bottom = "Debajo", left = "Izquierda", right = "Derecha" }
	L.OPT_PLATE_GAP = "Separación de la placa"
	L.PREVIEW_HINT = "Haz clic en un estado para cambiar su color"
	L.SEC_THREAT = "Agro en grupo"
	L.OPT_THREAT = "Avisarme antes de quitarle el agro al tanque"
	L.OPT_THREAT_PCT = "Desde (% de la amenaza del tanque)"
	L.OPT_TANK_WARN = "Cuando tanqueo (con Furia recta), avisarme cuando mi objetivo se va a por otro"
	L.THREAT_HINT = "Solo siempre tienes tú el agro, así que esto solo sale en grupo."
	L.UNLOCK = "Mover avisos"
	L.LOCK = "Bloquear avisos"
	L.OPT_MINIMAP_BUTTON = "Botón del minimapa"

	L.SEC_RESPEC = "Instructor de clase"
	L.OPT_RESPEC = "Cuándo baja el precio de reiniciar talentos, bajo la ventana del instructor"
	L.RESPEC_HINT = "Blizzard no lo publica: los jugadores cuentan que sube un escalón con cada reinicio (1, 5, 10 y luego 5 g más hasta 50 g) y baja uno por cada semana desde el último. El precio que pide el instructor es el real."
	L.RESPEC_TITLE = "Reinicio de talentos"
	L.RESPEC_CLASS = "Talentos de clase"
	L.RESPEC_LEGACY = "Talentos de legado"
	L.RESPEC_LAST = "El último, hace %s, por %s"
	L.RESPEC_NOW = "Ahora: %s"
	L.RESPEC_NOW_ABOUT = "Ahora: unos %s"
	L.RESPEC_DROPS = "Baja a %s %s (en %s)"
	L.RESPEC_LOWEST = "Ya está en lo más bajo"
	L.RESPEC_ASKED = "El instructor te pidió %s hace %s"
	L.RESPEC_UNKNOWN = "%s aún no sabe cuándo reiniciaste por última vez: lo apunta la próxima vez que pagues uno."
	L.RESPEC_TODAY = "hoy a las %s"
	L.RESPEC_TOMORROW = "mañana a las %s"
	L.RESPEC_ON = "el %s a las %s"
	L.RESPEC_WEEKDAYS = { "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado" }
	L.RESPEC_MINUTES = "%d min"
	L.RESPEC_HOURS = "%d h"
	L.RESPEC_DAYS = "%d días"

	L.TIP_LEFT = "Clic izquierdo: opciones"
	L.TIP_RIGHT_UNLOCK = "Clic derecho: mover los avisos"
	L.TIP_RIGHT_LOCK = "Clic derecho: bloquear los avisos"
	L.TIP_DRAG = "Arrastrar: mover este botón"

	L.HELP = {
		"Comandos de |cfff48cbaPaladinGod|r:",
		"  /paladingod  - opciones (o clic en el botón del minimapa; también vale /paladin)",
		"  /paladingod desbloquear | bloquear  - mover los avisos",
		"  /paladingod metros | yardas  - la distancia en metros o en yardas",
		"  /paladingod rango  - qué dice cada comprobación de distancia de tu objetivo",
		"  /paladingod bufos  - lo que el addon ve de tus bufos",
		"  /paladingod procs  - probar la luz de los procs",
		"  /paladingod golpe  - probar la barra de golpe",
		"  /paladingod martillo  - probar Martillo de cólera, Exorcismo y Martillo de justicia",
		"  /paladingod reutilizacion  - probar el aviso de reutilización lista",
		"  /paladingod talentos  - cuándo baja el precio de reiniciar talentos",
		"  /paladingod boton  - mostrar u ocultar el botón del minimapa",
	}
end

ns.L = L
