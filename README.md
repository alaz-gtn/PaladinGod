# PaladinGod

Addon de mejoras para paladines en WoW Forever, hermano de HunterGod y MageGod, con la misma ventana de opciones en rosa de paladín (#F48CBA). Comandos `/paladingod` y `/paladin`. De momento hace esto:

- Encima del personaje, en una fila con el diseño de la de HunterGod (iconos de 40, marquito negro de un píxel, quietos, siempre centrados), lo que falta:
  - el aura (también en combate);
  - tu bendición sobre ti (fuera de combate; en Forever dura una hora y vale la Mayor);
  - Furia recta: si tanqueas, te la recuerda; si no, avisa cuando la llevas puesta en grupo y un clic la quita;
  - el sello, en combate o con un enemigo seleccionado (en Forever la Sentencia no gasta el sello: dura sus 30 segundos);
  - el rastreo de recolección si eres herborista o minero y no lo llevas, solo en el mundo abierto (`Gathering.lua`, el mismo archivo en toda la familia).
  En gris si falta; en color con su tiempo en sus últimos minutos. Un aura o una bendición de otro paladín no cuentan como tuyas. Un clic lo lanza sobre ti, fuera de combate.
- Mientras llevas sello, su icono con los segundos que le quedan, en un sitio propio: lo dibuja un contenedor de auras del juego, porque en combate los bufos son secretos.
- Las bendiciones del grupo, fuera de combate: una fila por jugador sin tu bendición (primero los que no la llevan, luego a los que se les acaba; en gris si está lejos). Un clic lo bendice con la de su clase (Poderío, Sabiduría, Reyes o ninguna, por clase). La del mismo tipo de otro paladín cuenta.
- Procs con contenedores de auras, como los de HunterGod (40 %, 60 % al saltar y 20 % mientras duran), cada uno con su forma y su sitio para que los de una misma build no se tapen:
  - Sagrado: luz que cae a los lados con Infusión de Luz (437063) y un halo sobre la cabeza con Favor divino (20216, dura hasta la siguiente cura).
  - Reprensión: un círculo dorado a los pies con Venganza (20050).
  - Protección: un círculo azul a los pies con Redoubt (20128), un anillo mayor que gira al revés con Shieldsworn (1328551), luz que sube a los lados con Reckoning (20178; Forever no le da texto de bufo, puede que no salga) y un escudo delante con Iron Creed (1311033).
  Unsealed Wrath no va: no se encontró el ID de su bufo.
- Barra de escudos, la de MageGod: Baluarte del templario (1311015) y cualquier escudo de otra clase que pueda caerte (Palabra de poder: escudo, Égida divina, el de los gnomos...), más las pociones de protección, cada uno en su color, con las mismas claves y colores que el resto de la familia.
- Equipo gastado y bolsas casi llenas (`Repair.lua`, común): junto al chat, con la comida, por debajo del 25 % y con 2 huecos o menos (los dos se cambian en las opciones). Un vendedor que repara dice en el chat cómo está tu equipo.
- `GroupBuffs.lua` (común) está conectado a la fila (`GroupRow.lua`), pero no trae datos para el paladín: sus bufos de grupo son las bendiciones, que van por jugador en `Blessings.lua`.
- Reactivos bajos (`Reagents.lua`, el mismo archivo en toda la familia): Símbolo de divinidad (Intervención divina) y Símbolo de reyes (Bendiciones mayores), solo de lo que sabes y no si llevas Reagent Economy. Salen junto al chat con el aviso de comida, y un vendedor que los tiene lo dice en el chat.
- Barra de golpe de la mano derecha (`PLAYER_SWING`), la minimalista de HunterGod. Puede ocultar la del juego (`showSwingTimer`).
- Martillo de cólera con el objetivo al 20 % o menos (en combate lo decide el juego con una curva sobre `UnitHealthPercent`) y Exorcismo contra no-muertos y demonios. En medio, el Martillo de justicia cuando el objetivo lanza algo y lo tienes listo y a 10 yardas: el paladín no tiene interrupción, pero el aturdimiento corta el lanzamiento. En combate no se sabe qué lanza, pero sí que lanza: `isTradeskill` (sexta devolución de `UnitCastingInfo` y `UnitChannelInfo`) nunca es secreto. No salen mientras el hechizo se enfría.
- Cooldowns gordos que vuelven (`Cooldowns.lua`, el aviso de `Pulse.lua` de MageGod ampliado a una lista): Escudo divino, Protección divina, Imposición de manos, Bendición de protección, Baluarte del templario, Favor divino, Arrepentimiento, Martillo de justicia, Voz de la verdad e Intervención divina, cada uno con su interruptor y solo los que sabes. Si vuelven dos a la vez, salen uno tras otro.
- Tus efectos sobre los enemigos (`Debuffs.lua`): un contenedor de auras por placa (`HARMFUL|PLAYER`, como el contador de Trampa congelante de HunterGod) con tres huecos: tu Sentencia, tus aturdimientos (Martillo de justicia, Arrepentimiento, Expulsar no-muertos, Sello de justicia) y Vindicación. Solo de lo que sabes, con `SetAuraSlotCandidateFilters`.
- Postura o forma equivocada: el paladín no tiene posturas; lo más parecido, Furia recta sin tanquear, ya va en la fila de avisos.
- La distancia: "Melee", y luego el número en amarillo (10 yd: Sentencia y Martillo de justicia), azul (30 yd: Exorcismo) o gris; con un aliado, rosa dentro de las 40 yd de tus curas.
- El aviso de agro en grupo; si tanqueas (Furia recta puesta), avisa cuando tu objetivo se va a por otro.
- Un aviso pequeño de Bien alimentado junto al chat, con la lista de tu comida de exp.
- En el instructor, cuándo baja el precio de reiniciar talentos (`Respec.lua`, el mismo archivo que HunterGod y MageGod).

## Carpetas

- `PaladinGod/`: el addon tal como se instala en `_forever_\Interface\AddOns`. En este PC esa carpeta es una unión (junction) a esta, así que los cambios llegan al juego sin copiar nada: con `/reload` basta, salvo los archivos nuevos, que piden reiniciar el juego.
- `tools/`: `test_addon.py` (pruebas con lupa), `make_procs.py` (las texturas de los procs: luz que cae y que sube, círculo, círculo al revés y escudo; necesita pillow), `build_zip.py` (el zip) y `publish.py` (la subida a CurseForge).
- `curseforge/`: el logo, la descripción de la página y las notas de cada versión.
- `release/`: los zips, que no van al repositorio.

El logo y el icono salen de `..\ClassGods\make_logos.py`.

## Probar

`python -I tools/test_addon.py PaladinGod enUS` y lo mismo con `esES`.

## Sacar una versión nueva

1. Cambia `## Version:` en `PaladinGod/PaladinGod.toc` y añade su entrada en `curseforge/changelog.md`.
2. Pasa las pruebas en los dos idiomas.
3. Haz commit, crea la etiqueta `v<versión>` y súbela (`git push origin main v<versión>`). GitHub Actions (`.github/workflows/release.yml`) prueba el addon y lo sube a CurseForge con su nota de cambios (`tools/publish.py`, con la clave de CurseForge en el secreto `CF_API_KEY` del repositorio y el proyecto en `## X-Curse-Project-ID` del TOC, el 1832579). Para ver el zip sin subirlo: `python -I tools/build_zip.py` o `python -I tools/publish.py --dry-run`.

La descripción de la página de CurseForge (`curseforge/description.md`) no la sube `publish.py`: se pega a mano.

## En Forever

Forever esconde a los addons en combate los bufos, la vida del objetivo y los tiempos de reutilización. Por eso los tiempos se leen fuera de combate y en combate se siguen por lo que lanzas, y lo que tiene que ser exacto (el sello, los procs, el Martillo) lo dibuja el propio juego.

En el juego, `/paladingod bufos` dice lo que el addon ve, `/paladingod rango` qué dice cada comprobación de distancia y `/paladingod procs` qué hechizos vigila cada proc.
