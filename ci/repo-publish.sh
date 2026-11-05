#!/bin/bash
#
# Publish the repository that repo-import.sh made, in the CI container, once
# its images are in the release. Afterwards, _repo/public/ is the tree to
# deploy, and _repo/keep.txt lists the images the release has to keep: those
# of the new index, and those of the index that is published now, for clients
# that still have that one.
#
# REPO_URL is where the repository is published, and $MREPO_SIGNING_KEY has
# the private key that signs its root index.
#
set -euo pipefail

config=_repo/manifold-repo.toml

if [ -z "${MREPO_SIGNING_KEY:-}" ]; then
    echo "::error::There is no key to sign the repository with: the MREPO_SIGNING_KEY secret is not set"
    exit 1
fi

manifold-mrepo -c "$config" publish
manifold-mrepo -c "$config" check

# every image has to be in the release, as we never put images on Pages
local_images=$(find _repo/public -name '*.raw.zck')
if [ -n "$local_images" ]; then
    echo "::error::Some images were not found in the release, and would end up on Pages"
    echo "$local_images" >&2
    exit 1
fi

# this has to run before the new tree is deployed
{
    manifold-mrepo -c "$config" external-files | cut -f1
    python3 -I "$(dirname "$0")/live-images.py" "$REPO_URL"
} | LC_ALL=C sort -u > _repo/keep.txt
echo "The release has to keep $(wc -l < _repo/keep.txt) images"
