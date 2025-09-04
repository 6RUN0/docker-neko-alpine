##################
# Do build stage
FROM alpine:latest AS do-build

ARG NEKO_SRC="https://github.com/m1k1o/neko.git"
ARG NEKO_TAG="v3.0.7"

WORKDIR /src

RUN \
  set -eux; \
  apk add --upgrade --no-cache --virtual .dobuild-dependencies \
  ca-certificates \
  git \
  ; \
  git clone --depth 1 --branch ${NEKO_TAG} ${NEKO_SRC} .; \
  GIT_COMMIT=$(git rev-parse --short HEAD); \
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD); \
  GIT_TAG=$(git tag --points-at "${GIT_COMMIT}" | head -n1); \
  printf "GIT_COMMIT=%s\nGIT_BRANCH=%s\nGIT_TAG=%s\n" "${GIT_COMMIT}" "${GIT_BRANCH}" "${GIT_TAG}" > meta.env; \
  # Prepare artifacts
  install -D -m 644 config.yml /rootfs/etc/neko/neko.yaml; \
  install -D -m 644 runtime/.Xresources /rootfs/etc/skel/.Xresources; \
  install -D -m 644 runtime/default.pa /rootfs/etc/pulse/default.pa;

################
# Build server
FROM golang:1.24-alpine AS server-build

ARG TARGETOS=linux
ARG TARGETARCH=amd64
ARG CGO_ENABLED=1
ENV CGO_ENABLED=${CGO_ENABLED}

WORKDIR /src

COPY --from=do-build /src/server /src
COPY --from=do-build /src/meta.env /src/meta.env

RUN \
  set -eux; \
  apk add --upgrade --no-cache --virtual .serverbuild-dependencies \
  bash \
  build-base \
  git \
  gst-plugins-base-dev \
  gstreamer-dev \
  gtk+3.0-dev \
  libx11-dev \
  libxcvt-dev \
  libxrandr-dev \
  libxtst-dev \
  pkgconfig \
  ;
# Build server
RUN \
  set -a; \
  . meta.env; \
  set +a; \
  ./build;
# Prepare artifacts
RUN \
  set -eux; \
  install -D -m 755 bin/neko /rootfs/usr/bin/neko; \
  mkdir -p /rootfs/etc/neko; \
  mv bin/plugins /rootfs/etc/neko/plugins;

################
# Build client
FROM node:18-alpine AS client-build

WORKDIR /src

COPY --from=do-build /src/client /src

RUN \
  set -eux; \
  npm install; \
  npm run build; \
  # Prepare artifacts
  mkdir -p /rootfs/var; \
  mv dist /rootfs/var/www;

#########################
# Build xorg input neko
FROM alpine:latest AS xorg-input-neko

WORKDIR /src

COPY --from=do-build /src/utils/xorg-deps/xf86-input-neko /src

RUN \
  set -eux; \
  apk add --upgrade --no-cache --virtual .xorginputneko-dependencies \
  autoconf \
  automake \
  build-base \
  libtool \
  pkgconfig \
  util-macros \
  xorg-server-dev \
  xorgproto \
  ;

RUN \
  set -eux; \
  ./autogen.sh --prefix=/usr; \
  ./configure; \
  make -j$(nproc); \
  make install; \
  # Prepare artifacts
  install -D -m 755 /usr/local/lib/xorg/modules/input/neko_drv.so /rootfs/usr/lib/xorg/modules/input/neko_drv.so;

#######################
# Build runtime image
FROM alpine:latest AS runtime

ARG S6_OVERLAY_VERSION=3.2.1.0
ARG TARGETARCH="amd64"
ARG TARGETVARIANT=""

RUN \
  set -eux; \
  # Install s6-overlay
  apk add --no-cache --update --virtual .s6-overlay-dependencies \
  tar \
  xz \
  ; \
  # Warning! This case not tested with multi-arch build
  # See https://github.com/just-containers/s6-overlay?tab=readme-ov-file#which-architecture-to-use-depending-on-your-targetarch
  case "${TARGETARCH}${TARGETVARIANT:+/${TARGETVARIANT}}" in \
  386) S6_ARCH="i686" ;; \
  amd64) S6_ARCH="x86_64" ;; \
  arm) S6_ARCH="armhf" ;; \
  arm/v6) S6_ARCH="armhf" ;; \
  arm/v7) S6_ARCH="arm" ;; \
  arm64) S6_ARCH="aarch64" ;; \
  riscv64) S6_ARCH="riscv64" ;; \
  s390x) S6_ARCH="s390x" ;; \
  *) echo "Unsupported arch: ${TARGETARCH} ${TARGETVARIANT:-}"; exit 1 ;; \
  esac; \
  S6_BASE_URL="https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}"; \
  S6_TEMP_DIR="$(mktemp -d)"; \
  cd "$S6_TEMP_DIR"; \
  wget -qO "s6-overlay-noarch.tar.xz" "${S6_BASE_URL}/s6-overlay-noarch.tar.xz"; \
  wget -qO "s6-overlay-${S6_ARCH}.tar.xz" "${S6_BASE_URL}/s6-overlay-${S6_ARCH}.tar.xz"; \
  wget -qO "s6-overlay-noarch.tar.xz.sha256" "${S6_BASE_URL}/s6-overlay-noarch.tar.xz.sha256"; \
  wget -qO "s6-overlay-${S6_ARCH}.tar.xz.sha256" "${S6_BASE_URL}/s6-overlay-${S6_ARCH}.tar.xz.sha256"; \
  sha256sum -c "s6-overlay-noarch.tar.xz.sha256"; \
  sha256sum -c "s6-overlay-${S6_ARCH}.tar.xz.sha256"; \
  tar -xJf "s6-overlay-noarch.tar.xz" -C /; \
  tar -xJf "s6-overlay-${S6_ARCH}.tar.xz" -C /; \
  cd /; \
  rm -rf "$S6_TEMP_DIR"; \
  apk del --purge --no-network .s6-overlay-dependencies; \
  # Install main dependencies
  apk add --upgrade --no-cache --virtual .runtime-dependencies \
  bash \
  ca-certificates \
  cairo \
  dbus-x11 \
  font-noto \
  font-noto-arabic \
  font-noto-cjk \
  font-noto-devanagari \
  font-noto-emoji \
  font-noto-hebrew \
  gst-plugins-bad \
  gst-plugins-base \
  gst-plugins-good \
  gst-plugins-ugly \
  gstreamer \
  gtk+3.0 \
  libvpx \
  libx11 \
  libxcb \
  libxcvt \
  libxrandr \
  libxtst \
  libxv \
  musl-locales \
  opus \
  pulseaudio \
  rofi \
  setxkbmap \
  sxhkd \
  tzdata \
  xclip \
  xdotool \
  xf86-input-libinput \
  xf86-video-dummy \
  xorg-server \
  xterm \
  ;

LABEL net.m1k1o.neko.api-version=3

COPY --from=client-build /rootfs/ /
COPY --from=do-build /rootfs/ /
COPY --from=server-build /rootfs/ /
COPY --from=xorg-input-neko /rootfs/ /
COPY rootfs/ /

RUN \
  set -eux; \
  chmod 755 /etc/s6-overlay/s6-rc.d/*/finish; \
  chmod 755 /etc/s6-overlay/s6-rc.d/*/run; \
  chmod 755 /etc/s6-overlay/s6-rc.d/*/up; \
  chmod 755 /usr/local/bin/*;

ENTRYPOINT ["/init"]
CMD []
