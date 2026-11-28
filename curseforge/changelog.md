# 1.3.3

- **No more Lua errors in a group** ("Auras cannot be accessed when secret"): when a party member was fighting and you weren't, the game hides their buffs, and asking for them is an error in Forever. Now the addon checks first and leaves that member out until the fight is over.

# 1.3.2

- **No false "cooldown ready" pulse after a silence or a stun**: while a mob silences or stuns you, the game shows every spell cooling down, and when it ended the pulse took that for your big cooldowns coming back. Now that time doesn't count; a cooldown that was already running before the silence still pulses when it's back.

# 1.3.1

- **No more false "cooldown ready" pulses in combat**: casting instant spells one after another chains global cooldowns for longer than any one, and the game hides whose cooldown it is in a fight; the pulse took that for a big cooldown coming back. Now the global cooldown's time doesn't count, and a spell only pulses once it's been seen cooling down with the global cooldown over.

# 1.3.0

- **Missing buffs row** in dungeons and raids: a small row with the buffs your group can give you and you don't have (Arcane Intellect with a mage in the group, Fortitude with a priest, Mark of the Wild with a druid, a blessing per paladin). Click one to ask for it in the group chat ("Missing Arcane Intellect"); the paladin's lets you pick the blessing to ask for, and remembers it. Your own class's buffs are left out, and nothing in combat. Drag it with Move displays; an option turns it off, another shows it outside dungeons too.

# 1.2.0

- **Reagent vendors on the world map**: the vendors who sell the reagents of the spells you know (Symbols of Divinity and of Kings), only your faction's, each pin with the reagent's icon. Hover one for what it has of yours and how many you carry; click it for a waypoint (TomTom's if you have it). None with Reagent Economy. An option in the reagents section turns it off. Data from QuestieDB. If you update with the game open, restart it: the addon brings a new Libs folder.

# 1.1.0

- **Repair at a merchant** (an option, off by default): talking to a merchant who repairs fixes everything you wear and carry with your money, and says in the chat what it cost; without enough money it says so. Only this class's addon does it, so with every ...God addon on you pay once.
- **Buy your reagents at a merchant** (an option, off by default): a merchant who sells one you spend tops you up to a handful (10 runes, 20 powders, candles or feathers, 5 seeds...), only for the spells you know and not with Reagent Economy; it buys only what your money pays for and says in the chat what it bought and spent. Works with the low reagent reminder off too.

# 1.0.2

- With all the ...God addons installed, PaladinGod shows nothing on characters of other classes: no samples when you move the displays, no tries from its buttons, nothing left over. Only its options and its minimap button.
- Nor in the chat: on other classes it no longer repeats the lines about vendors, repairs and the trainer. Its commands still answer.

# 1.0.1

- Fixed an "action blocked" error in combat: the game doesn't let addons close the XP food list during a fight. It's closed as the fight starts, so it no longer tries again.

# 1.0.0

- First release, in English and Spanish:
  - **Clickable reminders** above your character, small with a thin black edge: your aura, your blessing on you, Righteous Fury (for tanks; if you don't tank, a warning when it's on in a group, and a click takes it off), your seal when you fight without one, and your Herbalism or Mining tracking. Your seal's seconds in combat too.
  - **Group blessings**: who in your group lacks your blessing, with one click to bless them and the blessing you choose for each class.
  - **Procs for every talent tree**, each with its own small animation and place: Infusion of Light, Divine Favor, Vengeance, Redoubt, Shieldsworn, Reckoning and Iron Creed.
  - **A pulse when each of your big cooldowns is ready again**, and your Judgement, stuns and Vindication on your enemies' nameplates with their seconds.
  - **Hammer of Wrath** at 20%, **Exorcism** against undead and demons, and **Hammer of Justice** when your target casts.
  - **A shield bar** for Templar's Bulwark, any other class's shield on you and the protection potions.
  - A swing timer, the range to your target and an aggro warning.
  - **Beside the chat**: Well Fed, your Symbols running low, worn gear and full bags.
  - At your trainer, when the talent reset price drops.
