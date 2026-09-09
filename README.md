# c64-tools

CI/CD templates for Commodore 64 (ACME + VICE) game projects, in the same
spirit as [tic80-tools](../tic80-tools).

- `example-makefile.make` — project Makefile: local dev targets
  (`deps`, `build`, `run`, `clear`, `rebuild`, `rebuildrun`).
- `example-woodpecker.yaml` — a one-line marker (`platform: c64`): the
  full pipeline (version → build → package → artifact → publish) is served by the update server's Woodpecker
  configuration extension — preview it with
  `curl "https://teletypegames.org/build/config?platform=c64"`.
- `example-metadata.json` — catalog metadata; the `version` field drives
  the pipeline's version step, the rest (`name`, `title`, `author`, `desc`, `site`,
  `repo`, `license`) is what `SoftwareUpdater::C64Service` writes into
  the DB (`site` becomes the "Source Code", `repo` the "Repository"
  external link).
- `example-tasks.json` — VS Code `.vscode/tasks.json` wrapping the local
  make targets.

## Usage in a game repo

1. Copy `example-makefile.make` to `Makefile`, set `PROJECT` (and
   `TARGET` if the .prg name differs from `$(PROJECT).prg`).
2. Copy `example-metadata.json` to `metadata.json` and fill it in;
   `name` must match `PROJECT`.
3. Copy `example-woodpecker.yaml` to `.woodpecker.yaml` (a one-line marker — the
   pipeline itself is served by the update server; add `name:` when the
   software name differs from the repo name) and add the
   `application_token` secret in Woodpecker (an ApplicationToken with
   the `update` + `upload` scopes, created in the admin).
4. Copy `example-tasks.json` to `.vscode/tasks.json`.

## Builder image

`builder.Dockerfile` bakes the pipeline's build-step dependencies
(ACME assembler + make) into `git.teletypegames.org/build/c64-builder`,
so the build step no longer runs `apt-get` on every run (VICE is a
local-dev tool only and is not included):

```sh
docker build --platform linux/amd64 -f builder.Dockerfile \
  -t git.teletypegames.org/build/c64-builder:latest .
docker push git.teletypegames.org/build/c64-builder:latest
```

## Player image

`player.Dockerfile` bakes the emulators the pipeline's `package` step wraps
around the built `.prg` into `git.teletypegames.org/build/commodore-player`,
shared by the c64 and plus4 pipelines (the update server hands it to them
as the `exporter` image):

- **EmulatorJS** (`player/index.html` + the self-hosted `data/` folder with
  the `vice_x64sc` and `vice_xplus4` libretro cores) — the browser player
  behind the catalog's "Play in browser" button. Everything is served from
  the release's own `/file/<name>-<version>/` folder with relative paths,
  nothing is loaded from the EmulatorJS CDN. The keyboard goes straight to
  the emulated machine (EmulatorJS's *Direct Keyboard Input* is on and no key
  is mapped to the RetroPad), so a game reads real C64 / Plus/4 keys; a
  gamepad still drives the joystick through the default RetroPad mapping.
- **yapeSDL** (upstream release binaries: the Debian `.deb` plus a copy of
  `libSDL2`, the Windows `x64.zip`, the universal macOS `.app`) — the native
  players. yapeSDL has no command line switch for the machine type, so each
  bundle ships a launcher (`<game>`, `<game>.bat`, `<game>.command`) that
  writes `EmulationLevel` into the user's `yape.conf` (2 = C64, 0 = Plus/4)
  and autostarts `<game>.prg`. `<game>` is the `name` in `metadata.json`: the
  catalog registers the software under it, and the store clients pick the
  program named after the software, so the launcher has to carry that name
  even when the pipeline's `<name>` (the repo slug or the marker's `name:`)
  differs from it.

`player/commodore-pack <c64|plus4> <name> <version>` is the entry point the
pipeline calls; it expects `<name>-<version>.prg` (and `metadata.json` for
the title and the game name) in the working directory and writes
`<name>-<version>.html.zip`, `-linux-x64.zip`, `-win-x64.zip` and
`-mac-universal.zip` next to it.
`player/LICENSES.txt` goes into every bundle (yapeSDL and the VICE core are
GPL-2, EmulatorJS is GPL-3).

```sh
docker build --platform linux/amd64 -f player.Dockerfile \
  -t git.teletypegames.org/build/commodore-player:latest .
docker push git.teletypegames.org/build/commodore-player:latest
```

Try it locally on a built project:

```sh
docker run --rm -v "$PWD:/workspace" git.teletypegames.org/build/commodore-player:latest \
  commodore-pack c64 mygame 1.0.0
```

The served pipeline builds the `.prg`, runs `commodore-pack`, uploads
`$(PROJECT)-$(VERSION).prg`, `.metadata.json`, `.html.zip`, `-linux-x64.zip`,
`-win-x64.zip` and `-mac-universal.zip` via `/build/upload`, then triggers
`/build/publish?platform=c64&name=$(PROJECT)&version=$(VERSION)`, which
creates/updates the Software row and a Release with the `cartridge`, `html`,
`win_x64`, `linux_x64` and `mac_universal` assets.
