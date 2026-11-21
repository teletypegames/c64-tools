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
- `example-tasks.json` — VS Code `.vscode/tasks.json`: the make targets as
  `warpengine` tasks (`build`, `clear`, `rebuild`, and `run (VICE)`, which
  runs the build in a local VICE — it does not run in the dev container).
- `example-devcontainer.json`, `example-devcontainer.Dockerfile` — the dev
  container a new project gets (`.devcontainer/`): the builder image below
  plus git and a `dev` user, so a computer with Docker only builds with the
  same toolchain as the pipeline. `example-devcontainer-tasks.json` holds the
  tasks merged into `.vscode/tasks.json` with it: `dev image` (builds the
  container image) and `play` (builds and plays the game in the host's
  EmulatorJS runtime).
- `hello/main.asm` — a Hello World: clears the screen and prints `HELLO WORLD`.
- `warp-template.json` — what *WarpEngine: New Game* in the WarpEngine Toolbox
  copies from this repo: the Makefile, the VS Code tasks and `hello/main.asm` as
  `main.asm`, and under its `devcontainer` key the dev container (its files
  filled with `{title}` and `{builderImage}`, its tasks merged), so a new project builds (`make build`, or the served pipeline's
  `acme -f cbm -o <name>.prg main.asm`) and runs (`make run`, x64sc) right away.
  The toolbox writes the marker, `metadata.json` and `README.md` itself.

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
5. For the dev container run *WarpEngine: Add Dev Container* in the WarpEngine
   Toolbox: it adds `.devcontainer/` and merges the tasks, keeping yours.

## Builder image

`builder.Dockerfile` bakes the pipeline's build-step dependencies
(ACME assembler, cc65 + make) into `git.teletypegames.org/build/c64-builder`,
so the build step no longer runs `apt-get` on every run (VICE is a
local-dev tool only and is not included). It is the base of the dev
container too, so it is built for amd64 (the CI runner) and arm64 (Apple
Silicon); both get the same Debian packages:

```sh
docker buildx build --platform linux/amd64,linux/arm64 -f builder.Dockerfile \
  -t git.teletypegames.org/build/c64-builder:latest --push .
```

## Player image

`player.Dockerfile` bakes the emulators the pipeline's `package` step wraps
around the built `.prg` into `git.teletypegames.org/build/commodore-player`,
shared by the c64 and plus4 pipelines (the update server hands it to them
as the `exporter` image):

- **yapeSDL** (upstream release binaries: the Debian `.deb` plus a copy of
  `libSDL2`, the Windows `x64.zip`, the macOS `.app` cut down to its arm64
  slice with `player/thin-arm64`, so it runs on Apple Silicon only) — the
  native players. yapeSDL has no command line switch for the machine type, so
  each bundle ships a launcher (`<game>`, `<game>.bat`, `<game>.command`) that
  writes `EmulationLevel` into the user's `yape.conf` (2 = C64, 0 = Plus/4),
  turns the speed/frame counter off (`DisplayFrameRate = 0`) and autostarts
  `<game>.prg`. `<game>` is the `name` in `metadata.json`: the
  catalog registers the software under it, and the store clients pick the
  program named after the software, so the launcher has to carry that name
  even when the pipeline's `<name>` (the repo slug or the marker's `name:`)
  differs from it.

`player/commodore-pack <c64|plus4> <name> <version>` is the entry point the
pipeline calls; it expects `<name>-<version>.prg` (and `metadata.json` for
the title and the game name) in the working directory and writes
`<name>-<version>-linux-x64.zip`, `-win-x64.zip` and `-mac-arm64.zip` next to it.
`player/LICENSES.txt` goes into every bundle (yapeSDL is GPL-2).

The browser player is not built here: on the web a C64 or Plus/4 release plays
in the update server's EmulatorJS runtime (WarpEngine 3.1+, `/play/<name>/<version>`),
which keeps EmulatorJS and the VICE cores once for every release.

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
`$(PROJECT)-$(VERSION).prg`, `.metadata.json`, `-linux-x64.zip`,
`-win-x64.zip` and `-mac-arm64.zip` via `/build/upload`, then triggers
`/build/publish?platform=c64&name=$(PROJECT)&version=$(VERSION)`, which
creates/updates the Software row and a Release with the `cartridge`,
`win_x64`, `linux_x64` and `mac_arm64` assets; the release plays in the browser
from its `cartridge`.
