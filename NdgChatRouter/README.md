# NdgChatRouter

An Elder Scrolls Online addon that shows selected **system messages** (PvP kill feed, friends going online or offline, guild keep attacks, group changes) in **custom chat tabs** of your choice. For example, you can give the kill feed its own "PvP" tab, so it doesn't drown out the rest of your chat and you don't have to show all System messages there.

## Screenshots

*Coming soon*

## Features

- **Four message groups**, each can be sent to any number of chat tabs:
  - **PvP kill feed**: who killed whom in PvP.
  - **Friend online/offline**: friends logging in and out.
  - **Guild keep attack updates**: attacks on keeps claimed by your guilds.
  - **Group join/leave**: members joining or leaving your group, and group type changes.
- **Configured per tab name.** Reordering your tabs keeps the routing intact.
- **No duplicates.** A tab that already shows System messages gets these messages anyway, so it is skipped.
- **Looks like the rest of your chat.** Messages are copied exactly as the chat formats them, including **pChat**'s formatting (e.g. timestamps) if you use it. They still show up wherever they appeared before.

## Settings

Open the settings panel via **ESC > Settings > Addons > NdgChatRouter**. There is a submenu for every chat tab, with one checkbox per message group. Settings are account-wide.

- New or renamed tabs appear in the panel after a `/reloadui`. Because the routing is stored by tab name, a renamed tab has to be set up again.
- The kill feed only arrives if the game's own **PvP Kill Feed** notifications are turned on.
- Only the keyboard chat is supported (not the gamepad UI).

## Slash commands

| Command | Effect |
|---------|--------|
| `/ndgchat` | Lists in chat which message groups go to which tab |

## Installation

1. Download `NdgChatRouter-<version>.zip` from the [releases](https://github.com/thisisths/eso-addons/releases) and extract it into your `Elder Scrolls Online/live/AddOns/` directory, so you get `AddOns/NdgChatRouter/NdgChatRouter.txt`
2. Ensure the required library is installed (see below)
3. Enable the addon in the ESO addon manager

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) | >= 30 | Settings panel UI |
| [pChat](https://www.esoui.com/downloads/info93-pChat.html) | optional | Routed messages use pChat's formatting when it is active |
| [LibDebugLogger](https://www.esoui.com/downloads/info2275-LibDebugLogger.html) | optional | Debug logging of routed messages |

## License

This addon is provided as-is for personal use with The Elder Scrolls Online.
