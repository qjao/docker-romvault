#
# ROMVault Dockerfile
#
# https://github.com/laromicas/docker-romvault
#
# NOTES:
#   - We are using Mono.
#   - Only 64-bits x86_64 supported right now, but
#     maybe later if there is demand I will try
#     to add ARM support.
#
ARG DOCKER_IMAGE_VERSION=1.0.0-rc4

# Define software download URLs.
ARG ROMVAULT_URL=https://www.romvault.com
ARG ROMVAULT_VERSION=latest

# Download ROMVault.
FROM alpine:3.16 AS rv
ARG ROMVAULT_URL
ARG ROMVAULT_VERSION
RUN \
    apk --no-cache add curl && \
    if [ "$ROMVAULT_VERSION" = "latest" ]; then FILTER='head -1'; else FILTER="grep $ROMVAULT_VERSION"; fi && \
    # Get latest version of ROMVault & RVCmd
    ROMVAULT_DOWNLOAD=$(curl ${ROMVAULT_URL} | \
        sed -n 's/.*href="\([^"]*\).*/\1/p' | \
        grep -i download | \
        grep -i romvault | \
        sort -r -f -u | \
        $FILTER) \
        && \
    RVCMD_DOWNLOAD=$(curl ${ROMVAULT_URL} | \
        sed -n 's/.*href="\([^"]*\).*/\1/p' | \
        grep -i download | \
        grep -i rvcmd | \
        grep -i linux | \
        sort -r -f -u | \
        head -1) \
        && \
    echo ROMVAULT_DOWNLOAD=${ROMVAULT_DOWNLOAD} && \
    echo RVCMD_DOWNLOAD=${RVCMD_DOWNLOAD} && \
    # Document Versions
    echo "romvault" $(basename ${ROMVAULT_DOWNLOAD} .zip | cut -d "V" -f 3) >> /VERSIONS && \
    echo "rvcmd" $(basename ${RVCMD_DOWNLOAD} .zip | cut -d "V" -f 3 | cut -d "-" -f 1) >> /VERSIONS && \
    # Download RomVault
    mkdir -p /defaults/ && mkdir -p /opt/romvault/ && \
    curl --output /defaults/romvault.zip "${ROMVAULT_URL}/${ROMVAULT_DOWNLOAD}" && \
    curl --output /defaults/rvcmd.zip "${ROMVAULT_URL}/${RVCMD_DOWNLOAD}" && \
    unzip /defaults/romvault.zip -d /opt/romvault/ && \
    unzip /defaults/rvcmd.zip -d /opt/romvault/

# COPY ROMVault3.6.0.zip /defaults/romvault.zip
# RUN \
#     unzip /defaults/romvault.zip -d /opt/romvault/ && \
#     echo "romvault 3.6.0" >> /VERSIONS


# Pull base image.
FROM jlesage/baseimage-gui:ubuntu-20.04-v4.4.0

RUN \
    LC_ALL=en_US.UTF-8 && LANG=en_US.UTF-8 && LANG=C && \
    APP_ICON_URL=https://www.romvault.com/graphics/romvaultTZ.jpg && \
    install_app_icon.sh "$APP_ICON_URL"

RUN set -x && \
    LC_ALL=en_US.UTF-8 && LANG=en_US.UTF-8 && LANG=C && \
    apt-get update && \
    apt install gnupg ca-certificates -y && \
    apt install dirmngr gnupg apt-transport-https ca-certificates software-properties-common -y && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    apt-add-repository 'deb https://download.mono-project.com/repo/ubuntu stable-focal main' && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        mono-runtime \
        libmono-system-servicemodel4.0a-cil \
        libgtk2.0-0 \
        mono-complete \
        xterm \
        && \
    # Clean up
    # apt-get remove -y \
    #     curl \
    #     wget \
    #     ca-certificates \
    #     unzip \
    #     && \
    # apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    echo Finished

# Add files.
COPY rootfs/ /
COPY --from=rv /opt/romvault/ /opt/romvault/
COPY --from=rv /VERSIONS /VERSIONS
RUN chmod +x /startapp.sh
RUN chmod +x /etc/cont-init.d/99-romvault

# Set internal environment variables.
RUN \
    export ROMVAULT_VERSION=$(echo "$(grep romvault /VERSIONS | cut -d' ' -f2)") && \
    set-cont-env APP_NAME "ROMVault" && \
    set-cont-env APP_VERSION "$ROMVAULT_VERSION" && \
    set-cont-env DOCKER_IMAGE_VERSION "$DOCKER_IMAGE_VERSION" && \
    true

# Metadata.
LABEL maintainer="Lak <laromicas@hotmail.com>"
LABEL \
      org.label-schema.name="romvault" \
      org.label-schema.description="Docker container for ROMVault" \
      org.label-schema.version="${DOCKER_IMAGE_VERSION:-unknown}" \
      org.label-schema.vcs-url="https://github.com/laromicas/docker-romvault" \
      org.label-schema.schema-version="1.0"
