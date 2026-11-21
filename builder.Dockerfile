# CI builder image for C64 projects: ACME assembler, cc65 + make, so the
# pipeline's build step does not run apt-get on every run. The VICE
# emulator is a local-dev tool only and is intentionally not included.
#
# It is also the base of a project's dev container (.devcontainer/Dockerfile),
# so it is built for amd64 (the CI runner) and arm64 (Apple Silicon) alike;
# both carry the same Debian packages.
#
# Build & push (a docker-container buildx builder):
#   docker buildx build --platform linux/amd64,linux/arm64 -f builder.Dockerfile \
#     -t git.teletypegames.org/build/c64-builder:latest --push .

FROM debian:stable-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends make acme cc65 zip curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["/bin/bash"]
