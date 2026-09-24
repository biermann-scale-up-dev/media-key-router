# Media Key Router

A small macOS utility that routes the F8 and keyboard play/pause keys to the
active media player. When macOS has no usable Now Playing session, it starts a
configurable fallback player instead of opening Music.app.

## What it does

- Toggles the current Now Playing session, including paused sessions.
- Starts the configured fallback player when no usable session is available.
- Ignores a stale Apple Music session when Music.app is not running.
- Handles both the F8 key and the dedicated play/pause media key through
  Karabiner-Elements.
- Backs up the existing Karabiner configuration before changing the selected
  profile.

The fallback defaults to Spotify. Other `.app` players can be selected with
the `default` command below.

## Requirements

- macOS
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/) installed at
  `/Applications/Karabiner-Elements.app`
- [Homebrew](https://brew.sh/)
- Spotify installed at `/Applications/Spotify.app` for the initial fallback

The installer uses Homebrew to install `nowplaying-cli` and `jq` when they are
missing. `nowplaying-cli` reads the system Now Playing session through Apple's
private MediaRemote framework; a macOS update may require a compatible update
to that dependency.

## Install

Clone this repository, then run:

```sh
./install.sh
```

On a fresh Karabiner-Elements setup, the installer may first install the router
and then stop with instructions to open Karabiner-Elements. Approve its
background components and Input Monitoring access in macOS, make sure a
Karabiner profile is selected, and run `./install.sh` again.

The installer is safe to rerun. It installs the command at
`~/.local/bin/media-key-router`, adds this rule to the selected Karabiner
profile, and saves a timestamped backup of the previous Karabiner configuration.
If `~/.local/bin` is not on your `PATH`, use the full command path.

## Commands

```sh
~/.local/bin/media-key-router status
~/.local/bin/media-key-router default
~/.local/bin/media-key-router default /Applications/VLC.app
```

To change the fallback, pass an absolute path to an installed `.app` bundle.
Players that support an AppleScript `play` command start immediately. For other
players, the router opens the app and then asks macOS Now Playing to start it
after a session appears.

The fallback is stored in
`~/.config/media-key-router/config.json`. Runtime messages are written to
`~/Library/Logs/MediaKeyRouter.log`.

## Uninstall

```sh
./uninstall.sh
```

The uninstaller removes this router's Karabiner rule, command, and configuration
and creates a backup before editing Karabiner's configuration. It leaves
`nowplaying-cli` and `jq` installed because other tools may use them.

## License

This project is licensed under the [MIT License](LICENSE).
