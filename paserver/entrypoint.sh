#!/bin/bash
set -euo pipefail

# PAServer default port/password
PORT="${PASERVER_PORT:-64211}"
PASSWORD="${PASERVER_PASSWORD:-displaydeck}"

# Try multiple possible tarball names
TAR_GZ=""
for cand in "/paserver/PAServer-Linux-64.tar.gz" "/paserver/PAServer_Linux_64.tar.gz" /paserver/LinuxPAServer*.tar.gz; do
  if ls $cand 1> /dev/null 2>&1; then
    TAR_GZ=$(ls -1 $cand | head -n1)
    break
  fi
done

if [ -z "$TAR_GZ" ] || [ ! -f "$TAR_GZ" ]; then
  echo "ERROR: Expected /paserver/PAServer-Linux-64.tar.gz (or LinuxPAServer*.tar.gz). Copy it from your RAD Studio install to the repository paserver/ folder." >&2
  echo "On Windows, place it at c:\\DisplayDeck\\paserver\\PAServer-Linux-64.tar.gz" >&2
  exit 1
fi

if [ ! -f "/opt/paserver/paserver" ]; then
  echo "Unpacking PAServer..."
  tar -xzf "$TAR_GZ" -C /opt/paserver --strip-components=1
fi

# Start PAServer in foreground (no TTY). Configure password and port.
# PAServer supports -port and -password flags.
exec /opt/paserver/paserver -port=$PORT -password=$PASSWORD
