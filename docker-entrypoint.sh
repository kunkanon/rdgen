#!/bin/sh
# Named volumes are root-owned; app runs as `user`. Fix perms then drop privileges.
set -eu

mkdir -p /opt/rdgen/exe /opt/rdgen/png /opt/rdgen/temp_zips
chown -R user:user /opt/rdgen/exe /opt/rdgen/png /opt/rdgen/temp_zips || true
chmod -R u+rwX /opt/rdgen/exe /opt/rdgen/png /opt/rdgen/temp_zips || true

# db.sqlite3 lives in the image WORKDIR — ensure writable for GithubRun rows
touch /opt/rdgen/db.sqlite3 2>/dev/null || true
chown user:user /opt/rdgen/db.sqlite3 2>/dev/null || true

if command -v su-exec >/dev/null 2>&1; then
  exec su-exec user "$@"
fi
if command -v gosu >/dev/null 2>&1; then
  exec gosu user "$@"
fi
# fallback (still root) — better than crash
exec "$@"
