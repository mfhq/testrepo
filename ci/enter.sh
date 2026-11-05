#!/bin/bash
#
# The entry point of the CI container. A command started as root in a directory
# that another user owns, like the repository mounted by in-container.sh, runs
# as that user, with the subordinate IDs that builds map into their user
# namespaces. Anything else runs as it is.
#
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    uid=$(stat -c %u .)
    gid=$(stat -c %g .)

    if [ "$uid" -ne 0 ]; then
        getent group "$gid" > /dev/null || groupadd -g "$gid" ci
        getent passwd "$uid" > /dev/null || useradd -m -u "$uid" -g "$gid" ci
        user=$(getent passwd "$uid" | cut -d: -f1)

        for map in /etc/subuid /etc/subgid; do
            grep -qs "^$user:" "$map" || echo "$user:100000:65536" >> "$map"
        done

        exec runuser -u "$user" -- "$@"
    fi
fi

exec "$@"
