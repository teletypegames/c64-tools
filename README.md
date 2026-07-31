# c64-tools

CI/CD templates for Commodore 64 (ACME + VICE) game projects, in the same
spirit as [tic80-tools](../tic80-tools).

- `example-makefile.make` — project Makefile: local dev targets
  (`deps`, `build`, `run`, `clear`, `rebuild`, `rebuildrun`) plus the
  Woodpecker pipeline targets (`ci-version`, `ci-build`, `ci-artifact`,
  `ci-update`).
- `example-woodpecker.yaml` — Woodpecker pipeline: version → build
  (Debian, `apt install acme`) → artifact (scp to the droparea) →
  update (calls the teletypegames `/update` endpoint with
  `platform=c64`).
- `example-metadata.json` — catalog metadata; the `version` field drives
  `ci-version`, the rest (`name`, `title`, `author`, `desc`, `site`,
  `license`) is what `SoftwareUpdater::C64Service` writes into the DB.
- `example-tasks.json` — VS Code `.vscode/tasks.json` wrapping the local
  make targets.

## Usage in a game repo

1. Copy `example-makefile.make` to `Makefile`, set `PROJECT` (and
   `TARGET` if the .prg name differs from `$(PROJECT).prg`).
2. Copy `example-metadata.json` to `metadata.json` and fill it in;
   `name` must match `PROJECT`.
3. Copy `example-woodpecker.yaml` to `.woodpecker.yaml` and add the
   `droparea_ssh_password` / `update_secret_key` secrets in Woodpecker.
4. Copy `example-tasks.json` to `.vscode/tasks.json`.

## Builder image

`builder.Dockerfile` bakes the pipeline's build-step dependencies
(ACME assembler + make) into `git.teletype.hu/internal/c64-builder`,
so the build step no longer runs `apt-get` on every run (VICE is a
local-dev tool only and is not included):

```sh
docker build --platform linux/amd64 -f builder.Dockerfile \
  -t git.teletype.hu/internal/c64-builder:latest .
docker push git.teletype.hu/internal/c64-builder:latest
```

The pipeline uploads `$(PROJECT)-$(VERSION).prg` and
`$(PROJECT)-$(VERSION).metadata.json` to the droparea, then triggers
`/update?platform=c64&name=$(PROJECT)&version=$(VERSION)`, which
creates/updates the Software row and a Release with `cartridge_path`.
