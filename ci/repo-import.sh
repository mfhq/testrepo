#!/bin/bash
#
# Make a new repository in _repo/ from the bundles in _bundles/, in the CI
# container, and link the images the release does not have yet to
# _repo/uploads/. Those have to be uploaded before repo-publish.sh runs.
#
# The repository has no state of its own: it is made again on every run, from
# bundles that are reproducible. manifold-repo.toml configures it.
#
set -euo pipefail
shopt -s nullglob

rm -rf _repo
mkdir -p _repo/uploads

bundles=(_bundles/*.manifold)
if [ ${#bundles[@]} -eq 0 ]; then
    echo "There are no bundles to import" >&2
    exit 1
fi

manifold-mrepo import "${bundles[@]}"
manifold-mrepo pending-uploads --link-to _repo/uploads
