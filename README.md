# BETTER FOCUS

Better Focus improves Focus Mode behavior in Monster Hunter Wilds, especially for KB+M users. Everything is configurable in-game and documented via tooltips.

Primary features:
- Draw weapon into Focus Mode
- Sprint/Dash can disable Focus Mode
- Sprint/Dash can sheathe your weapon
- Restores Focus Mode after shortcut-bar actions like whetstone or ammo use if Focus Mode was active beforehand
- Modify focus behavior when mounting Seikret
- Allows Seikret call from unarmed Focus Mode
- Fixes focus loss when MHWilds stops being the foreground window.
- Disable focus/target camera snapping (useful for some HunterPie configurations)
- Blocking turns your hunter toward the targeted monster

This mod was inspired by excellent mods like AutoFocus, which were out of date when this was created. It is a full rewrite with a broader scope than similar mods.
This is my first MHWilds mod. It took much longer than originally planned, and I tested it as thoroughly as I know how. I hope you find it helpful. Feel free to report issues, and please be kind. ^_^

# INSTALLATION

PREREQUISITES:
- [REFramework](https://github.com/praydog/REFramework)
- A legally acquired copy of Monster Hunter Wilds
- Ability to read

OPTION A:  
Install via Vortex or a mod manager of your choice. [Nexus Mods Link](https://www.nexusmods.com/monsterhunterwilds/mods/4173)

OPTION B:
- Download the [latest release](https://github.com/Drexl/MHWilds-Better-Focus/releases/latest)
- Unzip it into your game root folder, the one that contains `MonsterHunterWilds.exe`

# CONFIGURATION
Configure using the REFramework UI (Insert key by default).
- Expand the Script Generated UI header at the bottom.
- Expand "Better Focus".
- Toggle settings on/off as desired.

# KNOWN LIMITATIONS

- This mod was primarily developed and tested for KB+M play. Controller testing was more limited, but the features should work. Report issues if you find any.
- If you keep dash and dash-strike on the same key (default) you may run into issues with some weapons, possibly just bow.
- Unarmed focus is not restored after alt-tab or other window focus loss. Drawn-weapon refocus restore works, but unarmed focus restore is still not solved.
- There is a very narrow edge case where attempting to sheathe extremely rapidly after movement can disable focus without fully sheathing. Almost no one will encounter this.
- If you use the mod "Keyboard Shortcut Setting", do not set Shortcut Display Time below 0.8. Lower values can cause jarring camera behavior on some weapons.
- Most behaviors depend on the game's action and camera states, so edge cases may still exist. Report them if you find them.
- If another mod changes the same focus mode, camera, dash, or Seikret behavior, conflicts are possible.

# REPORTING ISSUES

If you report a bug, include:
- KB+M or controller
- weapon type
- your BetterFocus_config.json found at \MonsterHunterWilds\reframework\data
- what you expected to happen
- what actually happened
- what other mods you have installed, if any
