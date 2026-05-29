# Stage 1: Build
FROM debian:bullseye AS builder

ARG LDC_VERSION=1.26.0

RUN set -eux;                                                          \
    apt-get update;                                                    \
    apt-get install -y                                                 \
        gcc libevent-dev libssl-dev zlib1g-dev python3 curl xz-utils  \
        libxml2;                                                        \
    rm -rf /var/lib/apt/lists/*

# Install LDC2 from official releases (matches native arch: x86_64 or aarch64)
RUN set -eux;                                                                              \
    ARCH=$(uname -m);                                                                      \
    curl -fsSL "https://github.com/ldc-developers/ldc/releases/download/v${LDC_VERSION}/ldc2-${LDC_VERSION}-linux-${ARCH}.tar.xz" \
        | tar -xJ -C /usr/local --strip-components=1

WORKDIR /gvrepsrv

COPY dub.sdl dub.selections.json ./
COPY src/ src/
COPY views/ views/
COPY static/ static/

# -link-defaultlib-shared=false links Phobos/D-runtime statically
# Keep bounds checks in production to avoid turning parser bugs into segfaults.
RUN DFLAGS="-link-defaultlib-shared=false" dub build --compiler=ldc2 -brelease


# Stage 2: Runtime
FROM debian:bullseye-slim

RUN set -eux;                                              \
    apt-get update;                                        \
    apt-get install -y                                     \
        libevent-2.1-7 libssl1.1 supervisor;               \
    rm -rf /var/lib/apt/lists/*

WORKDIR /gvrepsrv

COPY --from=builder /gvrepsrv/gvrepsrv ./
COPY --from=builder /gvrepsrv/static/ static/
COPY --from=builder /gvrepsrv/views/ views/
COPY supervisord.conf gvrepsrv.conf ./

RUN mkdir -p logs

CMD ["supervisord", "--nodaemon", "-c", "/gvrepsrv/supervisord.conf"]
