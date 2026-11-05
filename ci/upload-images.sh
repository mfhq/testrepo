#!/bin/bash
#
# Upload the images in _repo/uploads/ to the release that holds the images of
# the repository, and create that release first if there is none yet. Runs on
# the runner, with gh.
#
# The image URL prefix in manifold-repo.toml names the release.
#
set -euo pipefail
shopt -s nullglob

release_tag=$(python3 -I "$(dirname "$0")/repo-config.py" release-tag)
repo_url=$(python3 -I "$(dirname "$0")/repo-config.py" url)

if ! gh release view "$release_tag" > /dev/null 2>&1; then
    echo "Creating the release $release_tag"
    gh release create "$release_tag" \
        --prerelease \
        --target "$GITHUB_SHA" \
        --title "Repository images" \
        --notes "The images of the Manifold repository at $repo_url. The workflow that publishes the repository uploads and removes them, so please leave them alone."
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
gh release upload "$release_tag" "${uploads[@]}" --clobber
