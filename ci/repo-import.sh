#!/bin/bash
#
# Make a new repository in _repo/ from the bundles in _bundles/, in the CI
# container, and link the images the release does not have yet to
# _repo/uploads/. Those have to be uploaded before repo-publish.sh runs.
#
# The repository has no state of its own: it is made again on every run, from
# bundles that are reproducible. It is configured from these variables:
#
#   REPO_ID       the ID of the repository
#   REPO_SUMMARY  a short description of it
#   REPO_URL      where it is published
#   IMAGE_URL     where its images are, with {file} for the name of an image
#
set -euo pipefail
shopt -s nullglob

repo_dir=_repo
config="$repo_dir/manifold-repo.toml"

toml_string()
{
    python3 -I -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$1"
}

rm -rf "$repo_dir"
mkdir -p "$repo_dir/uploads"
cat > "$config" << EOF
# written by $(basename "$0"), the root index is signed with the key in \$MREPO_SIGNING_KEY

[repository]
id = $(toml_string "$REPO_ID")
summary = $(toml_string "$REPO_SUMMARY")
url = $(toml_string "$REPO_URL")

[trust]
keys = "../trusted-keys"

[channels.main]
image-url = $(toml_string "$IMAGE_URL")
omit-local-images = true
EOF

bundles=(_bundles/*.manifold)
if [ ${#bundles[@]} -eq 0 ]; then
    echo "There are no bundles to import" >&2
    exit 1
fi

manifold-mrepo -c "$config" import "${bundles[@]}"
manifold-mrepo -c "$config" pending-uploads --link-to "$repo_dir/uploads"
