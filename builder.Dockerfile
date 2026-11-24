# CI builder image for C64 projects: ACME assembler, cc65, Oscar64, cc1541 (writes
# the .d64 of a disk release) + make, so
# the pipeline's build step does not run apt-get on every run. The tools' own
# checks (`make check`, WarpEngine's shared check step) find gcc, python3 and a
# pinned clang-format 18.1.8 (the DOSLIB style) here too. The VICE
# emulator is a local-dev tool only and is intentionally not included.
#
# It is also the base of a project's dev container (.devcontainer/Dockerfile),
# so it is built for amd64 (the CI runner) and arm64 (Apple Silicon) alike;
# both carry the same Debian packages. Oscar64 is compiled from a pinned
# commit by a cross compiler on the build machine (no emulated C++ build),
# its runtime and headers next to it (/usr/local/share/oscar64), the oscar64
# command a small wrapper in /usr/local/bin.
#
# Build & push (a docker-container buildx builder):
#   docker buildx build --platform linux/amd64,linux/arm64 -f builder.Dockerfile \
#     -t git.teletypegames.org/build/c64-builder:latest --push .

FROM --platform=$BUILDPLATFORM debian:stable-slim AS oscar64

# Oscar64's main branch: the v1.32.273 release miscompiles return values
# (TTG Gate 64's tests on its emulator); bump with the tests run again.
ARG OSCAR64_COMMIT=f194f93908dace0cce8af1d7ae6eef1830e71f78
ARG TARGETARCH
ARG BUILDARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends make curl ca-certificates g++ g++-x86-64-linux-gnu g++-aarch64-linux-gnu \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://github.com/drmortalwombat/oscar64/archive/${OSCAR64_COMMIT}.tar.gz" | tar -xz -C /tmp \
 && mv /tmp/oscar64-${OSCAR64_COMMIT} /oscar64 \
 && case "$TARGETARCH" in amd64) CXX=x86_64-linux-gnu-g++ ;; arm64) CXX=aarch64-linux-gnu-g++ ;; *) exit 1 ;; esac \
 && if [ "$TARGETARCH" = "$BUILDARCH" ]; then CXX=g++; fi \
 && make -C /oscar64/make -j"$(nproc)" CXX="$CXX" CC="$CXX" \
      CPPFLAGS="-O2 -std=c++11 -Wno-switch -static-libstdc++ -static-libgcc" compiler \
 && mkdir -p /out/bin \
 && cp /oscar64/bin/oscar64 /out/bin/ \
 && cp -r /oscar64/include /out/include

FROM debian:stable-slim

ARG CLANG_FORMAT_VERSION=18.1.8

RUN apt-get update \
 && apt-get install -y --no-install-recommends make acme cc65 cc1541 zip curl ca-certificates \
      gcc libc6-dev python3 python3-venv \
 && rm -rf /var/lib/apt/lists/* \
 && python3 -m venv /opt/clang-format \
 && /opt/clang-format/bin/pip install -q --no-cache-dir "clang-format==${CLANG_FORMAT_VERSION}" \
 && ln -s /opt/clang-format/bin/clang-format /usr/local/bin/clang-format

COPY --from=oscar64 /out /usr/local/share/oscar64
RUN printf '#!/bin/sh\nexec /usr/local/share/oscar64/bin/oscar64 "$@"\n' > /usr/local/bin/oscar64 \
 && chmod +x /usr/local/bin/oscar64

WORKDIR /workspace

CMD ["/bin/bash"]
