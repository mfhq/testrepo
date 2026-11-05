#!/bin/bash
#
# Sign the bundles in a directory with the private key in $MANIFOLD_SIGNING_KEY,
# using the CI container. Runs on the runner. Signing again replaces the
# signature a bundle has.
#
# Usage: sign-bundles.sh BUNDLES_DIR
#
set -euo pipefail
shopt -s nullglob

if [ -z "${MANIFOLD_SIGNING_KEY:-}" ]; then
    echo "::error::There is no key to sign the bundles with: the MANIFOLD_SIGNING_KEY secret is not set"
    exit 1
fi

bundles=("$1"/*.manifold)
if [ ${#bundles[@]} -eq 0 ]; then
    echo "There are no bundles to sign"
    exit 0
fi

exec "$(dirname "$0")/in-container.sh" --env MANIFOLD_SIGNING_KEY manifold bundle sign "${bundles[@]}"
