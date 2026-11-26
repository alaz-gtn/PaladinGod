# PaladinGod

*Quality of life for paladins in WoW Forever · Mejoras para paladines en WoW Forever*

### At a glance

- 🛡️ **Clickable reminders**: your aura, your blessing on you (an hour in Forever), Righteous Fury, your seal when you fight without one and your Herbalism or Mining tracking. Click one to cast it. Plus Well Fed (+5% XP from kills in Forever)
- 🔨 **Your seal's seconds**, in combat too. In Forever a Judgement doesn't use your seal up
- 🙏 **Group blessings**: who in your group lacks your blessing, one click to bless them, with the blessing you choose for each class
- ✨ **Procs for every talent tree**, small and each in its own place: Infusion of Light and Divine Favor (Holy), Vengeance (Retribution), Redoubt, Shieldsworn, Reckoning and Iron Creed (Protection)
- 🔰 **Shield bar**: what's left of Templar's Bulwark, any other class's shield on you or a protection potion
- 🧾 **Reagents running low**: Symbol of Divinity and Symbol of Kings, unless you have Reagent Economy
- 🔧 **Gear and bags**: a reminder when your gear wears out or your bags fill up, and at a vendor who repairs, how worn it is
- ⚔️ **Swing timer** for your weapon
- ⚡ **Hammer of Wrath** with your target at 20% or under, **Exorcism** against undead and demons, and **Hammer of Justice** when your target casts
- ⏱️ **Big cooldowns ready**: Divine Shield, Lay on Hands, Blessing of Protection and more pop up in the middle when they're back
- 🎯 **On your enemies**: your Judgement, stuns and Vindication beside their nameplates, with their seconds
- 📏 **Range to your target**: melee, Judgement's 10 yards, Exorcism's 30, and your heals' 40 on a friend
- ⚠️ **Aggro warning** in a group: before you pull it off the tank, or when you tank and lose it
- 💰 **Talent reset price**: at your trainer, when the price of resetting your talents drops

### De un vistazo

- 🛡️ **Avisos clicables**: tu aura, tu bendición sobre ti (una hora en Forever), Furia recta, tu sello si peleas sin él y tu rastreo de Herboristería o Minería. Con un clic se lanza. Y Bien alimentado (+5% de experiencia por muerte en Forever)
- 🔨 **Los segundos de tu sello**, también en combate. En Forever la Sentencia no gasta el sello
- 🙏 **Bendiciones del grupo**: quién de tu grupo no lleva tu bendición, con un clic para ponérsela y la bendición que elijas para cada clase
- ✨ **Procs de cada rama de talentos**, pequeños y cada uno en su sitio: Infusión de Luz y Favor divino (Sagrado), Venganza (Reprensión), Redoubt, Shieldsworn, Reckoning e Iron Creed (Protección)
- 🔰 **Barra de escudos**: lo que le queda a Baluarte del templario, al escudo de cualquier otra clase que lleves o a una poción de protección
- 🧾 **Reactivos bajos**: Símbolo de divinidad y Símbolo de reyes, salvo si tienes Reagent Economy
- 🔧 **Equipo y bolsas**: un aviso cuando se te gasta el equipo o se te llenan las bolsas y, en un vendedor que repara, cómo está
- ⚔️ **Barra de golpe** de tu arma
- ⚡ **Martillo de cólera** con tu objetivo al 20% o menos, **Exorcismo** contra no-muertos y demonios, y **Martillo de justicia** cuando tu objetivo lanza algo
- ⏱️ **Reutilizaciones grandes listas**: Escudo divino, Imposición de manos, Bendición de protección y más salen en el centro cuando vuelven
- 🎯 **Sobre tus enemigos**: tu Sentencia, tus aturdimientos y Vindicación junto a su placa, con sus segundos
- 📏 **Distancia al objetivo**: cuerpo a cuerpo, las 10 yardas de la Sentencia, las 30 del Exorcismo y las 40 de tus curas con un aliado
- ⚠️ **Aviso de agro** en grupo: antes de quitárselo al tanque, o cuando tanqueas y lo pierdes
- 💰 **Precio de reiniciar talentos**: en tu instructor, cuándo baja el precio de reiniciar los talentos

Everything is set up from the **minimap button** or `/paladingod` (or `/paladin`). English and Spanish.
Todo se configura desde el **botón del minimapa** o con `/paladingod` (o `/paladin`). En inglés y en español.

---

## In combat too

Forever hides your buffs, your target's health, what it casts and your cooldowns from addons during a fight. PaladinGod has the game itself draw them: your seal and its seconds, the procs' light and their countdowns, your effects on your enemies, the shield bar and Hammer of Wrath all work in combat, and a cooldown coming back still sets off its pulse.

## In detail

- **Reminders**: a row above your character, all the same size with a thin black edge, always centred. Grey when something is missing, in colour with its time left in its last minutes. Your aura in combat too (the last one you had on, or the one you choose); your blessing on you out of combat (the last one you had, or the one you choose; a Greater Blessing counts); another paladin's aura or blessing isn't yours. Righteous Fury: if you tank, a reminder when it's missing or running out; if you don't, a warning when it's on in a group, and a click takes it off. Your seal, in a fight or with an enemy targeted, when you have none. Herbalism or Mining without its tracking on, out in the world. Clicking a reminder casts it on you, out of combat.
- **Seal's seconds**: while your seal is on, its icon with the seconds it has left, on its own spot.
- **Shield bar**: flat, with a one-pixel black edge and the shield's icon on its left, each shield in its colour (each potion in its school's).
- **Group blessings**: out of combat, a row for each player without your blessing (missing ones first, then the ones running out, greyed out when too far away). Click a row to bless that player. Another paladin's blessing of the same kind counts. Choose Might, Wisdom, Kings or none for each class.
- **Procs**: size, position, the space between the columns, how strong the burst and the calm light are, their colour and the countdown, in the Procs tab. `/paladingod procs` shows them.
- **Swing timer**: a flat bar that lights up as your swing comes, greyed out when your target is out of your weapon's reach. It can hide the game's own swing bar.
- **Hammer of Wrath, Exorcism and Hammer of Justice**: above your character while the spell is ready. A paladin has no interrupt in Classic, but Hammer of Justice's stun stops a cast: it shows while your target casts and you're within its 10 yards.
- **Big cooldowns**: Divine Shield, Divine Protection, Lay on Hands, Blessing of Protection, Templar's Bulwark, Divine Favor, Repentance, Hammer of Justice, Voice of Truth and Divine Intervention, each with its own switch. Only the ones you know; two back at once come one after the other.
- **On your enemies**: small icons left of each enemy's health bar (the enemy nameplates must be on), only yours and only of the spells you know: your Judgement, your stuns (Hammer of Justice, Repentance, Turn Undead, Seal of Justice) and Vindication.
- **Range**: in yards or metres, on the target's nameplate or where you put it.
- **Beside the chat, out of combat**: a small reminder when you're not Well Fed (not at max level; a click lists your XP food), your reagents running low (only for the spells you know; a vendor that sells one says so in the chat), your gear under 25% and your bags with 2 free slots or fewer (you set both lines; a vendor who repairs says how worn your gear is).
- **At your trainer**: when you last reset your talents, what it costs now, and when the price drops. The game doesn't tell addons, so PaladinGod writes down each reset you pay for from now on and counts from there, as players report it: a step up with each reset (1, 5, 10, then 5 g more up to 50 g) and a step down for each week. The price the trainer asks always wins.
- Drag any display where you want it with **Move displays** (or `/paladingod unlock`).

## Commands

- `/paladingod` (or `/paladin`): the options
- `/paladingod unlock` · `lock`: move the displays
- `/paladingod procs`: try the procs' light
- `/paladingod swing` · `golpe`: try the swing timer
- `/paladingod hammer` · `martillo`: try Hammer of Wrath, Exorcism and Hammer of Justice
- `/paladingod cooldowns` · `reutilizacion`: try the pulse for a cooldown ready
- `/paladingod buffs` · `bufos`: what the addon sees of your buffs
- `/paladingod range` · `rango`: what each range check says about your target
- `/paladingod respec` · `talentos`: when the talent reset price drops

## License

GPLv3. The Fredoka One and Changa fonts are SIL Open Font License 1.1.
