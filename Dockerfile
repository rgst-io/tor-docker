# syntax=docker/dockerfile:1
FROM gentoo/portage:latest AS portage
FROM gentoo/stage3:latest AS builder

# https://gitlab.torproject.org/tpo/core/tor/-/tags
ARG TOR_VERSION

COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo

RUN <<EOF
  set -euo pipefail
  
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

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /usr/bin/tor /usr/bin/tor
ENTRYPOINT ["/usr/bin/tor"]