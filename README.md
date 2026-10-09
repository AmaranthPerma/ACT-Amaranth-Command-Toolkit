# ACT — Amaranth Command Toolkit

ACT is an unofficial in-game toolkit for *Mercenaries 2: World in Flames* on Windows. It uses Ess 0.6.1 and Lua Bridge DEV. This repository contains the **public edition** and the current compact ACT menu UI.

## Public edition

- Player tools, Support & Rewards, Fun, Quick Spawn, Vehicles, World, Native Dev Menu, and Settings.
- F4 opens or closes ACT. The optional controller companion maps L2 + L3 to F4.
- The public menu keeps Troops, War Creator, and Creator Camera locked. Their private modules and access file are not included.
- Menu palettes and other settings are saved through Lua Bridge.

The Lua scripts are readable and editable. Menu locks are a release choice, not a security boundary.

## Requirements

- A legally obtained Windows copy of *Mercenaries 2: World in Flames*.
- [mercs2-modkit](https://github.com/Mercenaries-Fan-Build/mercs2-modkit), Lua Bridge DEV, and Ess 0.6.1 already installed.
- PowerShell on Windows. Run the installer with administrator rights if the game is under `Program Files`.

ACT does not include the game executable, WAD files, Ess, or Lua Bridge. The installer builds the menu UI locally from the Ess movie in your existing `vz-patch.wad`.

## Install

Close the game, then run in PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install-ACT.ps1 -GameDirectory 'C:\Program Files (x86)\EA Games\Mercenaries 2 World in Flames'
```

The installer saves the original patch as `data\vz-patch.pre-ACT.wad` and backs up `scripts\lua_loader.ini` as `scripts\lua_loader.ini.pre-ACT`. It merges ACT entries into the loader configuration and also updates an existing VirtualStore copy. Existing saved games are not changed.

Start with `ACT-Controller\Avvia-Gioco-con-ACT.cmd`, or launch the game normally and use F4. The companion is needed only for controller shortcuts. In the menu, use the D-pad or left stick to navigate, A to select, B to go back, and left/right to change values.

## Files

- `scripts/OnKey/ACT.lua`: menu and F4 entry point.
- `scripts/OnLoad/`: ACT modules loaded after Ess.
- `ACT-Controller/`: optional controller companion and launcher.
- `tools/act_runtime.as` and `tools/act_action.tag`: source and compiled ACT UI action code.
- `tools/Patch-ACTUI.ps1`: builds the UI patch from the local Ess WAD.

## Credits

ACT uses Ess and Lua Bridge as external dependencies. The included `gfx_tool.exe` and codec files come from the community [mercs2-gfx-tool](https://github.com/loganw234/mercs2-tools-gfxtool) and [gfxforge](https://github.com/loganw234/mercs2-tools-gfxforge) projects. Their MIT license and notices are included in `tools/`.

ACT is an independent fan project and is not affiliated with Electronic Arts or Pandemic Studios. Game names and marks belong to their respective owners.
