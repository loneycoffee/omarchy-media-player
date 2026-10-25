# Media Player

What is playing, on the Omarchy bar: the logo of the app playing it, the
track, and previous / play-pause / next. One click takes you to the app.

- **The logo** is the real service: Spotify, YouTube, YouTube Music,
  SoundCloud, Twitch, Netflix, Apple Music, TIDAL. A browser playing YouTube
  shows YouTube, not the browser. Anything else uses its own desktop icon.
- **Left click** on the logo or the track goes to the window playing it, on
  its workspace. For browsers the playing tab is raised first.
- **Right click** opens the panel: cover art, a seekable progress bar, the
  controls, and every player that has something loaded, to switch between.
- **Middle click** plays or pauses; **scroll** skips tracks.
- Long titles are elided; hover them to scroll.

Works with any MPRIS player (Spotify, Chromium/Brave/Firefox, mpv, VLC, ...).
The player that started playing last wins; one picked in the panel sticks.

## Install

```bash
omarchy plugin add https://github.com/loneycoffee/omarchy-media-player.git --enable
```

Open the panel from a keybinding with `omarchy-shell shell toggle media-player`.

## Settings

In `~/.config/omarchy/shell.json`, on the `media-player` bar entry:

| Key            | Default | Meaning                                  |
|----------------|---------|------------------------------------------|
| `maxWidth`     | `220`   | Track label width in pixels (0 hides it) |
| `showArtist`   | `true`  | Show the artist after the title          |
| `showControls` | `true`  | Show previous / play-pause / next        |
| `hideWhenIdle` | `true`  | Hide the widget when nothing is loaded   |

## Keys in the panel

`space` play/pause · `←`/`→` previous/next · `↑`/`↓` switch player ·
`enter` go to the app · `esc` close

## Command line

```
omarchy-shell media-player status      JSON: app, track, player, workspace
omarchy-shell media-player playPause
omarchy-shell media-player next
omarchy-shell media-player previous
omarchy-shell media-player jump        go to the app's window and workspace

bin/media-window find|focus BUS_NAME [TITLE] [IDENTITY] [DESKTOP_ENTRY] [URL]
```

`bin/media-window` finds a player's window through the process that owns its
D-Bus name (or a parent, so mpv in a terminal finds the terminal), then the
window title for browsers with several windows. Logos are from
[Simple Icons](https://simpleicons.org) (CC0).
