# ESO addons by @Nidhoeggr

Elder Scrolls Online addons by @Nidhoeggr. Each top-level folder is one addon, and each addon is released on its own.

| Addon | What it does |
|---|---|
| [NdgBuffsAndDebuffs](NdgBuffsAndDebuffs/) | Tracks and displays buffs, debuffs, and reminders in configurable display groups. |
| [NdgChatRouter](NdgChatRouter/) | Shows selected system messages (PvP kill feed, friend online/offline, keep attacks, group changes) in custom chat tabs. |
| [NdgCrown](NdgCrown/) | Beam and direction arrow for the group leader and for base-game target marks. |
| [NdgLibUsage](NdgLibUsage/) | Shows on every library in the Add-Ons screen which addons use it, so unused libraries are easy to spot. |
| [NdgUrge](NdgUrge/) | Extension for NdgCrown: a big "Stop Zerging" warning when you are too far from the group leader. |

## Installation

Download the addon's zip from [Releases](https://github.com/thisisths/eso-addons/releases) and extract it into your `AddOns` folder (`Documents\Elder Scrolls Online\live\AddOns`). The result should be `AddOns\<Name>\<Name>.txt`. Also install the libraries the addon lists under `DependsOn` in its manifest.

## Releasing

Push a tag `<Name>/v<Version>`, for example:

```
git tag NdgCrown/v1.0.1
git push origin NdgCrown/v1.0.1
```

The [release workflow](.github/workflows/release.yml) then:

1. Checks the tag against `## Version:` in `<Name>/<Name>.txt`.
2. Zips only that folder, leaving out the repo-only files listed in [.gitattributes](.gitattributes).
3. Publishes `<Name>-<Version>.zip` as a GitHub release, with notes starting at that addon's previous tag.

## Development

ESO only loads addons from `AddOns\<Name>\`, so this repo is linked into the game instead of copied. Clone it next to the `AddOns` folder, then create one link per addon (a directory junction on Windows, a symlink on macOS):

```powershell
cd "$env:USERPROFILE\Documents\Elder Scrolls Online\live"
git clone https://github.com/thisisths/eso-addons.git
powershell -ExecutionPolicy Bypass -File eso-addons\tools\link-addons.ps1
```

On macOS, with [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-macos) installed (`brew install powershell`):

```sh
cd ~/Documents/"Elder Scrolls Online"/live
git clone https://github.com/thisisths/eso-addons.git
pwsh -File eso-addons/tools/link-addons.ps1
```

- Use `-AddOnsPath <path>` if the repo is not next to `AddOns`.
- Re-run the script after adding an addon folder or moving the repo. It never touches real folders.
- Remove a link with `cmd /c rmdir AddOns\<Name>` on Windows or `rm AddOns/<Name>` on macOS (no `-r`, no trailing slash). In Windows PowerShell 5.1, `Remove-Item -Recurse` on a junction also deletes the files in this repo.
