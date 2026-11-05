#!/bin/bash
#
# Build the recipes of one stage into bundles, in the CI container. The stages
# are built in this order, each on the bundles of the ones before:
#
#   cores       recipes/cores/*.yaml
#   platforms   recipes/platforms/*.yaml, on the cores
#   apps        recipes/apps/*.yaml, on the cores and platforms
#
# Bundles are not signed here, so no key is around while the recipes build.
# Next to the bundles, we write a listing of what we built, <stage>.txt, which
# also keeps the output from ever being empty.
#
# Usage: build-recipes.sh STAGE EARLIER_BUNDLES_DIR OUTPUT_DIR
#
# With CORE_ARCHIVE=current in the environment, cores are built from the
# current Debian archive instead of the snapshot their recipe names. That is
# for when snapshot.debian.org is unwell, as the cores are not pinned then.
#
set -euo pipefail
shopt -s nullglob

stage=$1
bundles_dir=$2
output_dir=$(realpath -m "$3")
srcdir=$PWD

case "$stage" in
    cores | platforms | apps) ;;
    *)
        echo "Unknown stage: $stage" >&2
        exit 2
        ;;
esac

# Images are stamped with the time of the commit. That makes the kits of apps
# get the same revision when the same commit is built again, and the images the
# same, as long as the packages and sources they are built from did not change.
# Cores take the time of their snapshot anyway.
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}

core_archive=${CORE_ARCHIVE:-snapshot}
case "$core_archive" in
    snapshot) ;;
    current)
        # debuerreotype, with the current archive as the snapshot of any time
        export DEBUERREOTYPE_SCRIPT_DIR=/usr/local/share/manifold-ci/debuerreotype-current/scripts
        if [ "$stage" = cores ]; then
            echo "::warning::The cores are built from the current Debian archive, not from their snapshots"
        fi
        ;;
    *)
        echo "Unknown CORE_ARCHIVE: $core_archive" >&2
        exit 2
        ;;
esac

mkdir -p "$output_dir"
listing="$output_dir/$stage.txt"
versions=/usr/local/share/manifold-ci/versions
{
    echo "# $stage of $(git rev-parse HEAD)"
    if [ -r "$versions" ]; then
        echo "# built with:"
        sed 's/^/#   /' "$versions"
    fi
    if [ "$core_archive" = current ] && [ "$stage" = cores ]; then
        echo "# from the current Debian archive, not from the snapshots of the recipes"
    fi
} > "$listing"

build_args=(--no-sign)
if [ -n "${RUNNER_DEBUG:-}" ]; then
    build_args+=(--verbose)
fi

# the builder takes cores and platforms from a plain directory of the files of their bundles
if [ "$stage" != cores ]; then
    runtimes_dir=$(mktemp -d)
    trap 'rm -rf "$runtimes_dir"' EXIT
    for bundle in "$bundles_dir"/*.manifold; do
        echo "Using $(basename "$bundle")"
        unzip -q -o -j "$bundle" '*.manifold.json' '*.raw' -d "$runtimes_dir"
    done
    build_args+=(--runtimes-dir "$runtimes_dir")
fi

recipes=("recipes/$stage"/*.yaml)
if [ ${#recipes[@]} -eq 0 ]; then
    echo "There are no $stage to build"
    exit 0
fi

for recipe in "${recipes[@]}"; do
    before=("$output_dir"/*.manifold)

    echo "::group::Build $recipe"
    # the builder names the bundle and writes it to the current directory
    (cd "$output_dir" && manifold-builder build "${build_args[@]}" "$srcdir/$recipe")
    echo "::endgroup::"

    for bundle in "$output_dir"/*.manifold; do
        if [[ " ${before[*]} " != *" $bundle "* ]]; then
            echo "$recipe -> $(basename "$bundle") ($(du -h --apparent-size "$bundle" | cut -f1))" >> "$listing"
        fi
    done
done
