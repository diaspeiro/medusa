ARG BASE_IMAGE=cgr.dev/chainguard/wolfi-base:latest

#=============#
# Build Stage #
#=============#
FROM ${BASE_IMAGE} AS build_medusa
LABEL stage=build

WORKDIR /build

RUN --mount=type=cache,target=/var/cache,sharing=locked apk upgrade && apk add bash ca-certificates curl jq patch

SHELL ["/bin/bash", "-c"]

# Fetch the pinned source archive (verified by sha256), extract, and patch.
RUN --mount=type=bind,source=patches,target=/mnt/patches \
    --mount=type=bind,source=.github/dependency-versions.json,target=/build/dv.json \
    --mount=type=bind,source=scripts/fetch-dep.sh,target=/usr/local/bin/fetch-dep <<ENDRUN
set -uex
umask 0022
fetch-dep medusa
cd medusa
patch -p1 < /mnt/patches/unix_socket.diff
ENDRUN

#===============#
# Runtime Stage #
#===============#
FROM ${BASE_IMAGE} AS medusa
ARG SOURCE_DATE_EPOCH=0

RUN --mount=type=cache,target=/var/cache,sharing=locked \
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
