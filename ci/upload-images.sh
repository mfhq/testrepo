#!/bin/bash
#
# Upload the images in _repo/uploads/ to the release that holds the images of
# the repository, and create that release first if there is none yet. Runs on
# the runner, with gh.
#
# RELEASE_TAG names the release, and REPO_URL is where the repository is.
#
set -euo pipefail
shopt -s nullglob

if ! gh release view "$RELEASE_TAG" > /dev/null 2>&1; then
    echo "Creating the release $RELEASE_TAG"
    gh release create "$RELEASE_TAG" \
        --prerelease \
        --target "$GITHUB_SHA" \
        --title "Repository images" \
        --notes "The images of the Manifold repository at $REPO_URL. The workflow that publishes the repository uploads and removes them, so please leave them alone."
fi

uploads=(_repo/uploads/*)
if [ ${#uploads[@]} -eq 0 ]; then
    echo "The release has all images already"
    exit 0
fi

for upload in "${uploads[@]}"; do
    echo "Uploading $(basename "$upload") ($(du -h --apparent-size "$upload" | cut -f1))"
done
# an asset with the same name and other content is replaced, as the repository checked that
gh release upload "$RELEASE_TAG" "${uploads[@]}" --clobber
