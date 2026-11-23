# Player image for C64 and Plus/4 projects: packages a built .prg (or .d64) as native
# linux/windows/mac bundles (yapeSDL; the mac app is cut down to its arm64
# slice, Apple Silicon only). On the web a release plays in the update
# server's EmulatorJS runtime, so the image builds no browser player. Shared by the c64 and plus4
# pipelines; the update server hands it to them as the `exporter` image.
#
# Build & push (the CI runner is linux/amd64):
#   docker build --platform linux/amd64 -f player.Dockerfile \
#     -t git.teletypegames.org/build/commodore-player:latest .
#   docker push git.teletypegames.org/build/commodore-player:latest

FROM debian:stable-slim

ARG YAPESDL_VERSION=0.81.1

ENV PLAYER_HOME=/opt/commodore-player \
    YAPESDL_VERSION=${YAPESDL_VERSION}

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates zip unzip binutils zstd libsdl2-2.0-0 \
 && rm -rf /var/lib/apt/lists/*

COPY player/thin-arm64 /usr/local/bin/thin-arm64
RUN chmod 0755 /usr/local/bin/thin-arm64

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
    mkdir -p "$dest/mac-arm64"; unzip -q mac.zip -d "$dest/mac-arm64"; \
    find "$dest/mac-arm64" -type f \( -name yapeSDL -o -name SDL2 \) -exec thin-arm64 {} \; ; \
    for f in $(find "$dest/mac-arm64" -type f \( -name yapeSDL -o -name SDL2 \)); do \
      [ "$(od -An -tx1 -N4 "$f" | tr -d ' ')" = "cffaedfe" ] || { echo "$f is not a thin 64-bit Mach-O" >&2; exit 1; }; \
    done; \
    cd /; rm -rf "$tmp"; \
    objdump -p "$dest/linux-x64/lib/libSDL2-2.0.so.0" | grep NEEDED; \
    find "$dest" -maxdepth 2 -ls

COPY player/LICENSES.txt ${PLAYER_HOME}/
COPY player/commodore-pack /usr/local/bin/commodore-pack
RUN chmod 0755 /usr/local/bin/commodore-pack

WORKDIR /workspace

CMD ["/bin/bash"]
