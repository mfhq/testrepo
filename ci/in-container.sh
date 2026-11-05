#!/bin/bash
#
# Run a command in the CI container, in the repository, as the user who owns it.
# The container is privileged: the default seccomp and AppArmor profiles deny
# creating user namespaces and mounting, which builds need. The builds
# themselves run unprivileged.
#
# Usage: in-container.sh [--env NAME]... COMMAND [ARG]...
#
# Each --env passes the variable NAME of our environment into the container.
#
set -euo pipefail

image=${TOOLS_IMAGE:-manifold-tools}
names=()
while [ "${1:-}" = --env ]; do
    names+=("$2")
    shift 2
done

sudo_args=()
podman_args=()
if [ ${#names[@]} -gt 0 ]; then
    sudo_args+=("--preserve-env=$(IFS=,; echo "${names[*]}")")
    for name in "${names[@]}"; do
        podman_args+=(--env "$name")
    done
fi

exec sudo "${sudo_args[@]}" podman run --rm --privileged \
    --volume "$PWD:/src:Z" --workdir /src \
    "${podman_args[@]}" \
    "$image" "$@"
