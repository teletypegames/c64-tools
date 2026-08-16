# c64-tools

CI/CD templates for Commodore 64 (ACME + VICE) game projects, in the same
spirit as [tic80-tools](../tic80-tools).

- `example-makefile.make` — project Makefile: local dev targets
  (`deps`, `build`, `run`, `clear`, `rebuild`, `rebuildrun`).
- `example-woodpecker.yaml` — a one-line marker (`platform: c64`): the
  full pipeline (version → build → artifact → publish) is served by the update server's Woodpecker
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

The served pipeline uploads `$(PROJECT)-$(VERSION).prg` and
`$(PROJECT)-$(VERSION).metadata.json` via `/build/upload`, then triggers
`/build/publish?platform=c64&name=$(PROJECT)&version=$(VERSION)`, which
creates/updates the Software row and a Release with `cartridge_path`.
