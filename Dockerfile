# syntax=docker/dockerfile:1
FROM scratch AS builder

# Automatically supplied by Docker
ARG TARGETARCH

# Comes from ./scripts/fetch-gentoo.sh
ADD ./.gentoo-sources/$TARGETARCH.tar /

# https://gitlab.torproject.org/tpo/core/tor/-/tags
ARG TOR_VERSION

SHELL ["/usr/bin/bash", "-euo", "pipefail", "-c"]

# Download latest portage sources
RUN <<EOF
  mkdir -p /var/db/repos/gentoo
  emerge-webrsync
EOF

RUN <<EOF  
  export MAKEOPTS="-j$(nproc)"
  export EMERGE_DEFAULT_OPTS="--jobs 2"
  export USE="${USE:-""} hardened zstd static-libs"

  # Allows us to install any version of tor (we specify it anyways)
  echo 'net-vpn/tor **' >/etc/portage/package.accept_keywords/tor

  # Use static libs for tor
  mkdir -p /etc/portage/env
  echo 'EXTRA_ECONF="--enable-static-tor --with-libevent-dir=/usr/lib64 --with-openssl-dir=/usr/lib64 --with-zlib-dir=/usr/lib64"' >/etc/portage/env/torstatic.conf
  echo 'net-vpn/tor torstatic.conf' >>/etc/portage/package.env

  # Build tor dependencies first (this ensures they're updated and built
  # with static-libs)
  emerge dev-libs/libevent dev-libs/openssl sys-libs/libcap sys-libs/libseccomp \
    sys-libs/zlib app-arch/xz-utils app-arch/zstd

  emerge "=net-vpn/tor-${TOR_VERSION}"
  strip /usr/bin/tor
EOF

FROM scratch
COPY --from=builder /usr/bin/tor /usr/bin/tor
ENTRYPOINT ["/usr/bin/tor"]