#!/bin/bash
#
# Remove the images from the release that no index needs any more, which is
# every image that _repo/keep.txt does not list. Runs on the runner, with gh,
# once the new tree is deployed. Without pruning, the release would run into
# the limit of 1000 assets that GitHub has.
#
# RELEASE_TAG names the release.
#
set -euo pipefail

keep=_repo/keep.txt
assets=_repo/assets.txt

# with nothing to keep, something went wrong, and we would remove all images
if [ ! -s "$keep" ]; then
    echo "::warning::No image is listed as needed, so we do not remove any"
    exit 0
fi

release_id=$(gh api "repos/$GITHUB_REPOSITORY/releases/tags/$RELEASE_TAG" --jq .id)
gh api --paginate "repos/$GITHUB_REPOSITORY/releases/$release_id/assets?per_page=100" \
    --jq '.[].name | select(endswith(".raw.zck"))' | LC_ALL=C sort > "$assets"

removed=0
while read -r name; do
    echo "Removing $name"
    gh release delete-asset "$RELEASE_TAG" "$name" --yes
    removed=$((removed + 1))
done < <(LC_ALL=C comm -23 "$assets" "$keep")
echo "Removed $removed of the $(wc -l < "$assets") images in the release"
