FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PASERVER_PASSWORD=displaydeck \
    PASERVER_PORT=64211

# Basic toolchain and debugging tools required by the Delphi Linux SDK
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       gdb \
       binutils \
       rsync \
       unzip \
       procps \
       ca-certificates \
       tzdata \
       libstdc++6 \
       libgcc-s1 \
       libicu-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/paserver

# Expect user to mount PAServer-Linux-64.tar.gz into /paserver (bind mount)
# We'll provide a tiny entrypoint to unpack and run PAServer
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 64211
VOLUME ["/paserver", "/opt/paserver"]

ENTRYPOINT ["/entrypoint.sh"]
