#!/bin/bash
set -euo pipefail

# PAServer default port/password
PORT="${PASERVER_PORT:-64211}"
PASSWORD="${PASERVER_PASSWORD:-displaydeck}"
TAR_GZ="/paserver/PAServer-Linux-64.tar.gz"

if [ ! -f "$TAR_GZ" ]; then
  echo "ERROR: Expected $TAR_GZ. Copy it from your RAD Studio install to the repository paserver/ folder." >&2
  echo "On Windows, place it at c:\\DisplayDeck\\paserver\\PAServer-Linux-64.tar.gz" >&2
  exit 1
fi

if [ ! -f "/opt/paserver/paserver" ]; then
  echo "Unpacking PAServer..."
  tar -xzf "$TAR_GZ" -C /opt/paserver --strip-components=1
fi

# Start PAServer in foreground (no TTY). Configure password and port.
# PAServer supports -port and -password flags.
exec /opt/paserver/paserver -port=$PORT -password=$PASSWORD -timeout=0 -logdir=/opt/paserver/logs
