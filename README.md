# SkillchainsPlus

**Skillchain display and automation for Windower 4.**
Based on Ivaar's *SkillChains*, extended by Cypan, and maintained by Linktri @ Asura.

SkillchainsPlus tracks skillchain properties on your target and shows the open window, the burst elements, and every weapon skill you have that can close the chain. You can also let it run skillchains, magic bursts and Chain Affinity for you.

---

## Installation

1. Copy the whole folder to `Windower/addons/SkillchainsPlus/`. You need every file: `SkillchainsPlus.lua`, `display.lua`, `nukes.lua`, `skills.lua`, `images/`, and `data/`.
2. `//lua load skillchainsplus`
3. On first load, the addon creates `<YourCharacter>.lua` in the addon folder from `data/auto.lua`. Edit that file to set each job's weapon skills (see [Job configuration](#job-configuration)).

---

## The display

The display uses the same look as EnemyBar2: bold stroked text, no background box, and a coloured timer bar.

```
Step 2  →  Ruthless Stroke
[■■■■■■■■■■■■■■■□□□□□]  Go!  5.2s
Liquefaction   MB Fire
» Ruthless Stroke         Lv.2 Fusion
   Savage Blade           Lv.1 Scission

SC+  AUTO  BUDDY  MB
```

| Part | What it shows |
|---|---|
| **Header** | Current step and the action that made it |
| **Timer bar** | Red **Wait** until the window opens, green **Go!** while you can close, blue **Burst** after a closing skillchain |
| **Properties** | Active skillchain properties, plus magic-burst elements from step 2 on |
| **Closers** | Every weapon skill, Blue Magic spell or pet skill that continues the chain, highest level first. **»** in gold marks the one automation will use |
| **Mode line** | `SC+` followed by every automation mode that is on |

### Display commands

| Command | Effect |
|---|---|
| `//sc move` | Toggles move mode. Drag the display and the mode line, then run `//sc move` again to save |
| `//sc modes` | Shows or hides the mode line |
| `//sc font <name>` | Font (default `Arial`) |
| `//sc size <n>` | Font size (default `10`) |
| `//sc width <n>` | Timer bar width (default `220`) |
| `//sc burst` · `props` · `step` · `timer` | Toggles that part of the display (saved per job) |
| `//sc weapon` · `spell` · `pet` | Toggles listing weapon skills, SCH/BLU spells, or SMN/BST pet skills (saved per job) |
| `//sc aeonic` | Assumes other players' aeonic weapons are active |
| `//sc save [all]` | Saves settings for this character, or for all characters |

---

## Automation

### Main modes

| Command | Effect |
|---|---|
| `//sc auto` | Auto skillchain: closes when it can, otherwise opens with `defaultws` (or `tpws` above 2000 TP) |
| `//sc spam` | Uses `spamws` whenever you have 1000 TP |
| `//sc cleave` | Spam mode using `cleavews` |
| `//sc autonuke` | Casts a magic burst during the burst window |
| `//sc status` | Lists active modes in chat |
| `//sc reload` | Reloads the addon and resets all modes |

### Modifiers

| Command | Effect |
|---|---|
| `//sc buddy` | Waits for the engaged party member with the highest TP to weapon skill |
| `//sc ignore <name>` / `watch <name>` | Leaves a party member out of buddy mode / puts them back in |
| `//sc prefer` | Closes with `preferws` when it's an option |
| `//sc strict` | Closes **only** with `preferws` |
| `//sc open` | Only opens skillchains |
| `//sc close` | Only closes skillchains |
| `//sc endless` | Uses a Lv.1 or Lv.2 closer when available, so the chain keeps going |
| `//sc ultimate` | Only closes when the result is a Lv.4 skillchain |
| `//sc starter` | Opens each fight once with `starterws` |
| `//sc melee` / `ranged` | Uses only melee / only ranged weapon skills |
| `//sc light` / `dark` | Closes only light-based / dark-based skillchains |
| `//sc am` | Keeps Aftermath Lv.3 up with `amws` |
| `//sc mb` | Holds the close until the end of the window, to leave room for magic bursts |
| `//sc chaff` | **BLU:** uses Chain Affinity with whichever `chainaffws` spell closes the highest-level skillchain |
| `//sc ongo` | Only bursts Scission, Gravitation, Darkness and Umbra, with earth nukes |
| `//sc innin` / `yonin` | Turns to stay behind / in front of the mob while in range |
| `//sc whilecasting` / `whilereadies` | Spam mode that fires when the mob starts casting / readies a TP move |

### Combos

| Command | Same as |
|---|---|
| `//sc party` | `auto` + `buddy` |
| `//sc partyam` | `auto` + `buddy` + `am` |
| `//sc partymb` | `auto` + `buddy` + `mb` |

### Magic burst element toggles

`//sc fire` · `ice` · `wind` · `earth` · `thunder` · `water` · `lightness` · `darkness`

Each command turns that element off for autonuke, or back on.

### In-game macros

```
/console sc autoskill   -- uses the chosen closer (or the opener)
/console sc autoburst   -- casts the magic burst for the current chain
/console sc spamskill   -- uses spamws
```

### Buddy mode across your characters

When buddy mode is on, each of your characters tells the others when its Aftermath wears off or when a debuff stops it from weapon skilling. The others then skip it until it can go again. This works between characters on the **same PC** through Windower IPC.

---

## Job configuration

Your `<YourCharacter>.lua` defines the following for each job:

| Setting | Used for |
|---|---|
| `defaultws` | Opening a new skillchain |
| `tpws` | Opening when you have more than 2000 TP |
| `spamws` | Spam mode |
| `cleavews` | Cleave mode |
| `starterws` | The first weapon skill of each fight (starter mode) |
| `preferws` | Preferred closers (prefer / strict modes) |
| `amws` | Keeping Aftermath Lv.3 up |
| `chainaffws` | **BLU:** spells to use with Chain Affinity |
| `petws` | **BST/SMN:** pet skills used to open |

Each list is checked in order, and the first one you can use right now is picked. You can list several weapon skills to cover different weapons.

The bottom of the file also sets `fastcast` (the delay before an autonuke), `bursttime`, `tagdelay` and `nukeswap`, a GearSwap command to send before a magic burst.

---

## Troubleshooting

| Command | Shows |
|---|---|
| `//sc chaffdebug` | Chain Affinity recast, and which `chainaffws` spells are set |
| `//sc chaffcoverage` | Skillchain properties your set Chain Affinity spells cover |
| `//sc allrecasts` | Every active ability recast ID |

---

## Credits

- **Ivaar**: SkillChains (BSD 3-Clause)
- **Cypan**: SkillChains Plus automation
- **Linktri @ Asura**: Chain Affinity, prime weapon skills, EnemyBar2-style display, v3 rewrite
- Element colours by **Sammeh**
