#!/bin/bash
#
# Publish the repository that repo-import.sh made, in the CI container, once
# its images are uploaded to the release. Afterwards, _repo/public/ is the tree
# to deploy, and _repo/keep.txt lists the images the release has to keep: those
# of the new index, and those of the index that is published now, for clients
# that still have that one. Every directory of the tree gets an index.html that
# lists it, so it can be browsed.
#
# manifold-repo.toml configures the repository, and $MREPO_SIGNING_KEY has the
# private key that signs its root index.
#
set -euo pipefail

if [ -z "${MREPO_SIGNING_KEY:-}" ]; then
    echo "::error::There is no key to sign the repository with: the MREPO_SIGNING_KEY secret is not set"
    exit 1
fi

# verbose, so the log says why an image was not found in the release
manifold-mrepo -v publish
manifold-mrepo check

# We never put images on Pages, but GitHub can answer with 404 for a while after
# an image was uploaded, so the repository may not have found all of them yet.
# The index is the same either way, as clients look for every image in the
# release first, so we rely on the upload and drop those images from the tree.
# Only an image that was found already is not uploaded, and none of those is
# left here.
dropped=0
while IFS= read -r -d '' image; do
    name=$(basename "$image")
    if [ ! -e "_repo/uploads/$name" ]; then
        echo "::error::$name was not uploaded to the release, and would end up on Pages"
        exit 1
    fi
    echo "Leaving out $name, which was uploaded but is not served yet"
    rm "$image"
    dropped=$((dropped + 1))
done < <(find _repo/public -name '*.raw.zck' -print0)
if [ "$dropped" -gt 0 ]; then
    echo "::notice::GitHub did not serve $dropped of the uploaded images yet, we rely on their upload"
fi

# this has to run before the new tree is deployed
{
    manifold-mrepo external-files | cut -f1
    python3 -I "$(dirname "$0")/live-images.py" "$(python3 -I "$(dirname "$0")/repo-config.py" url)"
} | LC_ALL=C sort -u > _repo/keep.txt
echo "The release has to keep $(wc -l < _repo/keep.txt) images"

python3 -I write-dir-listings.py --root _repo/public
