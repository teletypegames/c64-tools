# Player image for C64 and Plus/4 projects: packages a built .prg as a
# browser player (EmulatorJS + the VICE libretro core) and as native
# linux/windows/mac bundles (yapeSDL). Shared by the c64 and plus4
# pipelines; the update server hands it to them as the `exporter` image.
#
# Build & push (the CI runner is linux/amd64):
#   docker build --platform linux/amd64 -f player.Dockerfile \
#     -t git.teletypegames.org/build/commodore-player:latest .
#   docker push git.teletypegames.org/build/commodore-player:latest

FROM debian:stable-slim

ARG EMULATORJS_VERSION=4.2.3
ARG YAPESDL_VERSION=0.81.1

ENV PLAYER_HOME=/opt/commodore-player \
    EMULATORJS_VERSION=${EMULATORJS_VERSION} \
    YAPESDL_VERSION=${YAPESDL_VERSION}

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates zip unzip binutils zstd libsdl2-2.0-0 \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    base="https://cdn.emulatorjs.org/${EMULATORJS_VERSION}/data"; \
    dest="${PLAYER_HOME}/emulatorjs"; \
    mkdir -p "$dest/compression" "$dest/cores/reports"; \
    for f in loader.js emulator.min.js emulator.min.css version.json compression/extract7z.js; do \
      curl -fsSL "$base/$f" -o "$dest/$f"; \
    done; \
    for core in vice_x64sc vice_xplus4; do \
      curl -fsSL "$base/cores/${core}-wasm.data" -o "$dest/cores/${core}-wasm.data"; \
      curl -fsSL "$base/cores/${core}-legacy-wasm.data" -o "$dest/cores/${core}-legacy-wasm.data"; \
      curl -fsSL "$base/cores/reports/${core}.json" -o "$dest/cores/reports/${core}.json"; \
    done; \
    ls -la "$dest" "$dest/cores"

RUN set -eux; \
    base="https://github.com/calmopyrin/yapesdl/releases/download/v${YAPESDL_VERSION}"; \
    dest="${PLAYER_HOME}/yapesdl"; \
    tmp="$(mktemp -d)"; cd "$tmp"; \
    curl -fsSL "$base/yapesdl_${YAPESDL_VERSION}-1_amd64.deb" -o yapesdl.deb; \
    ar x yapesdl.deb; tar -xf data.tar.*; \
    mkdir -p "$dest/linux-x64/lib"; \
    install -m 0755 usr/local/bin/yapesdl "$dest/linux-x64/yapesdl"; \
    cp -L /usr/lib/x86_64-linux-gnu/libSDL2-2.0.so.0 "$dest/linux-x64/lib/"; \
    curl -fsSL "$base/yapeSDL_${YAPESDL_VERSION}_x64.zip" -o win.zip; \
    mkdir -p "$dest/win-x64"; unzip -q win.zip -d "$dest/win-x64"; \
    curl -fsSL "$base/yapeSDL_${YAPESDL_VERSION}_Mac.zip" -o mac.zip; \
    mkdir -p "$dest/mac-universal"; unzip -q mac.zip -d "$dest/mac-universal"; \
    cd /; rm -rf "$tmp"; \
    objdump -p "$dest/linux-x64/lib/libSDL2-2.0.so.0" | grep NEEDED; \
    find "$dest" -maxdepth 2 -ls

COPY player/index.html player/LICENSES.txt ${PLAYER_HOME}/
COPY player/commodore-pack /usr/local/bin/commodore-pack
RUN chmod 0755 /usr/local/bin/commodore-pack

WORKDIR /workspace

CMD ["/bin/bash"]
