ARG BASE_IMAGE=cgr.dev/chainguard/wolfi-base:latest

#=============#
# Build Stage #
#=============#
FROM ${BASE_IMAGE} AS build_medusa
LABEL stage=build

ARG MEDUSA_VERSION

WORKDIR /build

RUN --mount=type=cache,target=/var/cache/apk,sharing=locked apk upgrade && apk add bash git patch

SHELL ["/bin/bash", "-c"]

RUN --mount=type=bind,source=patches,target=/mnt/patches <<ENDRUN
set -uex
umask 0022
clone_repo_version() { git -c advice.detachedHead=false clone --depth 1 --branch "$2" "https://github.com/$1" "${@:3}"; }
clone_repo_version "pymedusa/Medusa" "v${MEDUSA_VERSION}" medusa
cd medusa
patch -p1 < /mnt/patches/unix_socket.diff
ENDRUN

#===============#
# Runtime Stage #
#===============#
FROM ${BASE_IMAGE} AS medusa
ARG SOURCE_DATE_EPOCH=0

RUN --mount=type=cache,target=/var/cache/apk,sharing=locked \
    --mount=type=bind,from=build_medusa,source=/build/medusa,target=/mnt/medusa \
    --mount=type=bind,source=files,target=/mnt/files <<ENDRUN
set -uex
umask 0022
apk add --no-interactive bash ca-certificates coreutils ffmpeg libstdc++ mediainfo 7zip python-3.13 tzdata
mkdir -p /opt/medusa
cp -a /mnt/medusa/. /opt/medusa
cp -a /mnt/files/. /
find /docker-entrypoint.d -type f -regex '.*\.\(sh\|envsh\)$' -print0 | xargs -r0 chmod +x
chmod +x /docker-entrypoint.sh
rm -rf /var/cache/apk/* /var/cache/ldconfig /var/cache/misc
mkdir -p /ipc/medusa /config /media /downloads
chmod 755 /ipc
chmod 700 /ipc/medusa /config /media /downloads
chown nonroot:nonroot /ipc/medusa /config /media /downloads
find / -xdev -exec touch -hd "@${SOURCE_DATE_EPOCH}" {} + || true
ENDRUN

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
VOLUME [ "/config", "/ipc/medusa", "/media", "/downloads" ]
USER nonroot
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "python3", "-OO", "/opt/medusa/start.py", "--datadir", "/config" ]
